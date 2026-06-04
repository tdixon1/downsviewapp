import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/church_content.dart';

class WordpressService {
  WordpressService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const siteBaseUrl = 'https://downsviewsda.org';
  static const wpBaseUrl = '$siteBaseUrl/wp-json/wp/v2';

  Future<List<WpPost>> fetchLatestPosts({int limit = 5}) async {
    try {
      final response = await _get(
        '$wpBaseUrl/posts?per_page=$limit&orderby=date&order=desc&_embed=1',
      );
      if (response == null) return const [];

      final items = jsonDecode(response) as List<dynamic>;
      return Future.wait(items.map((item) async {
        final map = item as Map<String, dynamic>;
        final title = _stripHtml(_rendered(map['title']));
        final content = _rendered(map['content']);
        final excerpt = _rendered(map['excerpt']);
        final link = map['link'] as String?;
        var imageUrl = _embeddedImage(map) ?? _findContentImage(content, title);
        if (imageUrl == null && link != null) {
          final postHtml = await _get(link);
          if (postHtml != null) {
            imageUrl = _findOpenGraphImage(postHtml) ?? _findContentImage(postHtml, title);
          }
        }
        return WpPost(
          id: map['id'] as int,
          date: DateTime.tryParse((map['date'] ?? '') as String) ?? DateTime.now(),
          title: title,
          excerpt: _stripHtml(excerpt),
          content: content,
          link: link,
          imageUrl: imageUrl,
        );
      }));
    } catch (_) {
      return const [];
    }
  }

  Future<ChurchSermon?> fetchLatestSermon() async {
    try {
      final homeHtml = await _get('$siteBaseUrl/');
      final homepageSermon =
          homeHtml == null ? null : _parseLatestSermonFromHtml(homeHtml);
      if (homepageSermon != null) return _fetchSermonDetails(homepageSermon);

      for (final type in const ['sermon', 'imi_sermon']) {
        final response = await _get(
          '$wpBaseUrl/$type?per_page=1&orderby=date&order=desc&_embed=1',
        );
        if (response == null) continue;
        final items = jsonDecode(response) as List<dynamic>;
        if (items.isEmpty) continue;
        final sermon = _mapSermonItem(items.first as Map<String, dynamic>);
        if (sermon.title.isNotEmpty) return _fetchSermonDetails(sermon);
      }

      final sermonsHtml = await _get('$siteBaseUrl/sermons/');
      final sermon = sermonsHtml == null ? null : _parseLatestSermonFromHtml(sermonsHtml);
      return sermon == null ? null : _fetchSermonDetails(sermon);
    } catch (_) {
      return null;
    }
  }

  Future<ChurchBulletin?> fetchLatestBulletin() async {
    try {
      final response = await _get('$wpBaseUrl/pages?slug=bulletin');
      if (response != null) {
        final items = jsonDecode(response) as List<dynamic>;
        if (items.isNotEmpty) {
          final item = items.first as Map<String, dynamic>;
          final bulletin = _parseBulletinFromHtml(_rendered(item['content']));
          if (bulletin != null) return bulletin;
        }
      }

      final bulletinHtml = await _get('$siteBaseUrl/bulletin/');
      return bulletinHtml == null ? null : _parseBulletinFromHtml(bulletinHtml);
    } catch (_) {
      return null;
    }
  }

  Future<List<ChurchEvent>> fetchUpcomingEvents({int limit = 3}) async {
    try {
      for (final type in const ['event', 'events']) {
        final response = await _get(
          '$wpBaseUrl/$type?per_page=$limit&orderby=date&order=asc&_embed=1',
        );
        if (response == null) continue;
        final items = jsonDecode(response) as List<dynamic>;
        if (items.isEmpty) continue;
        final events = items.take(limit).map((item) {
          final map = item as Map<String, dynamic>;
          final date = DateTime.tryParse((map['date'] ?? '') as String);
          return ChurchEvent(
            title: _stripHtml(_rendered(map['title'])),
            dateLabel: date == null ? 'Upcoming' : DateFormat('MMM d').format(date),
            url: map['link'] as String?,
            imageUrl: _embeddedImage(map),
          );
        }).toList();
        return Future.wait(events.map(_fetchEventDetails));
      }

      final eventsHtml = await _get('$siteBaseUrl/events/');
      if (eventsHtml == null) return const [];
      final events = _parseEventsFromHtml(eventsHtml, limit);
      return Future.wait(events.map(_fetchEventDetails));
    } catch (_) {
      return const [];
    }
  }

  Future<String?> _get(String url) async {
    final separator = url.contains('?') ? '&' : '?';
    final uri = Uri.parse('$url${separator}_ts=${DateTime.now().millisecondsSinceEpoch}');
    final response = await _client.get(
      uri,
      headers: const {
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    return response.body;
  }

  ChurchSermon _mapSermonItem(Map<String, dynamic> item) {
    final content = _rendered(item['content']);
    final excerpt = _rendered(item['excerpt']);
    final text = _stripHtml('$content $excerpt');
    final speaker = item['sermon_speaker'] as String? ??
        RegExp(r'Sermon By:\s*([^*|]+?)(?:\s{2,}|Categories:|$)')
            .firstMatch(text)
            ?.group(1)
            ?.trim();

    return ChurchSermon(
      title: _cleanSermonTitle(_rendered(item['title'])),
      speaker: speaker,
      date: DateTime.tryParse((item['date'] ?? '') as String),
      excerpt: _stripHtml(excerpt.isNotEmpty ? excerpt : content),
      url: item['link'] as String?,
      imageUrl: _embeddedImage(item),
    );
  }

  ChurchSermon? _parseLatestSermonFromHtml(String html) {
    final text = _stripHtml(html);
    final title = RegExp(r'Home Sermons Sermons\s+(.+?)\s*Sermon By:', caseSensitive: false)
            .firstMatch(text)
            ?.group(1) ??
        RegExp(r'LATEST SERMONS\s+(?:Image\s+)?(.+?)\s*Sermon By:', caseSensitive: false)
            .firstMatch(text)
            ?.group(1) ??
        RegExp(r'Sermons\s+(?:Image:\s*)?(.+?)\s*Sermon By:', caseSensitive: false)
            .firstMatch(text)
            ?.group(1);
    if (title == null || title.trim().isEmpty) return null;

    final sermonSection = text.substring(text.indexOf(title));
    final speaker = RegExp(r'''Sermon By:\s*([A-Za-z .'-]+?)(?:\s+Categories:|\s+[A-Z][a-z]+ \d{1,2}, \d{4}|$)''')
        .firstMatch(sermonSection)
        ?.group(1)
        ?.trim();
    final dateText = RegExp(r'([A-Z][a-z]+ \d{1,2}, \d{4})')
        .firstMatch(sermonSection)
        ?.group(1);
    final link = _findSermonLink(html, title);

    return ChurchSermon(
      title: _cleanSermonTitle(title),
      speaker: speaker,
      date: dateText == null ? null : _tryParseDate(DateFormat('MMMM d, yyyy'), dateText),
      url: link,
      imageUrl: _findContentImage(html, title),
    );
  }

  ChurchBulletin? _parseBulletinFromHtml(String html) {
    final text = _stripHtml(html);
    final title = RegExp(r'Bulletin\s+(.+?Bulletin)', caseSensitive: false)
            .firstMatch(text)
            ?.group(1) ??
        RegExp(r'([A-Z]{3}-\d{1,2}-\d{2,4}\s+Bulletin)')
            .firstMatch(text)
            ?.group(1);
    final viewerUrl = _decodeEntities(RegExp(r'''https?:[^"' <>\s]+\.pdf[^"' <>\s]*''')
            .firstMatch(html)
            ?.group(0) ??
        '');
    final encodedPdfUrl =
        RegExp(r'[?&]file=([^&#]+)').firstMatch(viewerUrl)?.group(1);
    final directPdfUrl = encodedPdfUrl == null
        ? _normalizeUrl(RegExp(r'''https?://[^"' <>\s]+\.pdf''').firstMatch(viewerUrl)?.group(0))
        : Uri.decodeComponent(encodedPdfUrl);

    return ChurchBulletin(
      title: title == null ? 'Latest Bulletin' : _stripHtml(title),
      url: '$siteBaseUrl/bulletin/',
      pdfUrl: _normalizeUrl(directPdfUrl),
    );
  }

  List<ChurchEvent> _parseEventsFromHtml(String html, int limit) {
    final events = <ChurchEvent>[];
    final pattern = RegExp(
      r'''<div class=["']event-inner["']>([\s\S]*?)</div><!-- \.event-inner -->''',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(html)) {
      if (events.length >= limit) break;
      final cardHtml = match.group(1) ?? '';
      final dateMatch = RegExp(
        r'''<div class=["']event-date["']>\s*([^<]+)\s*<span class=["']event-time["']>([^<]*)</span>''',
        caseSensitive: false,
      ).firstMatch(cardHtml);
      final linkMatch = RegExp(
        r'''<a href=["']([^"']+/event/[^"']+)["'][^>]*class=["']post-title["'][^>]*>([\s\S]*?)</a>''',
        caseSensitive: false,
      ).firstMatch(cardHtml);
      final title = _stripHtml(linkMatch?.group(2) ?? '');
      final dateLabel = _stripHtml(dateMatch?.group(1) ?? '');
      final timeLabel = _stripHtml(dateMatch?.group(2) ?? '');
      if (title.isEmpty || dateLabel.isEmpty) continue;
      final imageUrl = _findContentImage(cardHtml, title);
      final schedule = [dateLabel, timeLabel].where((value) => value.isNotEmpty).join(' at ');
      events.add(
        ChurchEvent(
          title: title,
          dateLabel: dateLabel,
          timeLabel: timeLabel,
          url: linkMatch?.group(1) ?? '$siteBaseUrl/events/',
          details: cardHtml.contains('event-status')
              ? '$title is marked as closed. It was scheduled for $schedule.'
              : '$title is scheduled for $schedule.',
          imageUrl: imageUrl,
          isClosed: cardHtml.contains('event-status'),
        ),
      );
    }
    return events;
  }

  Future<ChurchSermon> _fetchSermonDetails(ChurchSermon sermon) async {
    if (sermon.url == null || sermon.url!.isEmpty) return sermon;
    final html = await _get(sermon.url!);
    if (html == null) return sermon;

    final youtubeUrl = _findYoutubeUrl(html);
    final imageUrl = _findOpenGraphImage(html) ?? _findContentImage(html, sermon.title) ?? sermon.imageUrl;
    final details = sermon.excerpt?.isNotEmpty == true
        ? sermon.excerpt
        : RegExp(r'Sermon Details\s+(.+?)(?:Share|Related|Leave a Reply|$)', caseSensitive: false)
            .firstMatch(_stripHtml(html))
            ?.group(1);

    return ChurchSermon(
      title: sermon.title,
      speaker: sermon.speaker,
      date: sermon.date,
      excerpt: details,
      url: youtubeUrl ?? sermon.url,
      imageUrl: imageUrl,
    );
  }

  Future<ChurchEvent> _fetchEventDetails(ChurchEvent event) async {
    if (event.url == null || event.url!.isEmpty) return event;
    final html = await _get(event.url!);
    if (html == null) return event;

    return ChurchEvent(
      title: event.title,
      dateLabel: event.dateLabel,
      timeLabel: event.timeLabel,
      url: event.url,
      details: event.details ??
          RegExp(r'Event Details\s+(.+?)(?:Details|Organizer|Venue|Share|$)', caseSensitive: false)
              .firstMatch(_stripHtml(html))
              ?.group(1),
      imageUrl: _findOpenGraphImage(html) ?? _findContentImage(html, event.title) ?? event.imageUrl,
      isClosed: event.isClosed,
    );
  }

  String _rendered(dynamic field) {
    if (field is String) return field;
    if (field is Map<String, dynamic>) return (field['rendered'] ?? '') as String;
    return '';
  }

  String _stripHtml(String value) {
    final withoutScripts = value
        .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ');
    final document = html_parser.parse(withoutScripts);
    return html_parser
        .parse(document.documentElement?.text ?? '')
        .documentElement
        ?.text
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim() ??
        '';
  }

  String _cleanSermonTitle(String title) {
    final cleanTitle = _stripHtml(title)
        .replaceFirst(RegExp(r'^Sermon Title:\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*\|\s*Speakers?:.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'''^["'“”]+|["'“”]+$'''), '')
        .trim();
    return cleanTitle.isEmpty ? _stripHtml(title) : cleanTitle;
  }

  String? _embeddedImage(Map<String, dynamic> item) {
    final embedded = item['_embedded'];
    if (embedded is! Map<String, dynamic>) return null;
    final mediaList = embedded['wp:featuredmedia'];
    if (mediaList is! List || mediaList.isEmpty) return null;
    final media = mediaList.first as Map<String, dynamic>;
    final details = media['media_details'];
    final sizes = details is Map<String, dynamic> ? details['sizes'] : null;
    if (sizes is Map<String, dynamic>) {
      for (final key in const ['medium_large', 'large']) {
        final size = sizes[key];
        if (size is Map<String, dynamic> && size['source_url'] is String) {
          return size['source_url'] as String;
        }
      }
    }
    return media['source_url'] as String?;
  }

  String? _findContentImage(String html, String? title) {
    final document = html_parser.parse(html);
    final titleLower = _stripHtml(title ?? '').toLowerCase();
    for (final img in document.querySelectorAll('img')) {
      final src = _normalizeUrl(img.attributes['src']);
      final alt = _stripHtml(img.attributes['alt'] ?? '').toLowerCase();
      if (src == null) continue;
      if (titleLower.isNotEmpty && alt.isNotEmpty &&
          (titleLower.contains(alt) || alt.contains(titleLower))) {
        return src;
      }
      final srcLower = src.toLowerCase();
      if (srcLower.contains('/wp-content/uploads/') &&
          !srcLower.contains('logo') &&
          !srcLower.contains('facebook.com') &&
          !alt.contains('downsview seventh-day adventist church')) {
        return src;
      }
    }
    return null;
  }

  String? _findSermonLink(String html, String title) {
    final links = RegExp(r'''href=["']([^"']+/sermon/[^"']+)["']''', caseSensitive: false)
        .allMatches(html)
        .map((match) => _normalizeUrl(match.group(1)))
        .whereType<String>()
        .toSet()
        .toList();
    if (links.isEmpty) return null;

    final titleWords = _cleanSermonTitle(title)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 2)
        .toList();
    for (final link in links) {
      final slug = link.toLowerCase();
      if (titleWords.isNotEmpty && titleWords.every(slug.contains)) {
        return link;
      }
    }
    return links.first;
  }

  String? _findOpenGraphImage(String html) {
    return _normalizeUrl(
      RegExp(
        r'''property=["']og:image["'][^>]+content=["']([^"']+)''',
        caseSensitive: false,
      ).firstMatch(html)?.group(1),
    );
  }

  String? _findYoutubeUrl(String html) {
    final decoded = _decodeEntities(html);
    final watchMatch = RegExp(
      r'''https?://(?:www\.)?youtube\.com/watch\?v=([A-Za-z0-9_-]{6,})[^"' <>\s]*''',
      caseSensitive: false,
    ).firstMatch(decoded);
    if (watchMatch != null) {
      return 'https://www.youtube.com/watch?v=${watchMatch.group(1)}';
    }

    final embedMatch = RegExp(
      r'''https?://(?:www\.)?youtube\.com/embed/([A-Za-z0-9_-]{6,})''',
      caseSensitive: false,
    ).firstMatch(decoded);
    if (embedMatch != null) {
      return 'https://www.youtube.com/watch?v=${embedMatch.group(1)}';
    }

    final shortMatch = RegExp(
      r'''https?://youtu\.be/([A-Za-z0-9_-]{6,})''',
      caseSensitive: false,
    ).firstMatch(decoded);
    if (shortMatch != null) {
      return 'https://www.youtube.com/watch?v=${shortMatch.group(1)}';
    }

    return null;
  }

  String? _normalizeUrl(String? url) {
    final decoded = _decodeEntities(url ?? '').trim();
    if (decoded.isEmpty) return null;
    final cleaned = decoded.replaceAll(r'\/', '/');
    if (cleaned.startsWith('//')) return 'https:$cleaned';
    if (cleaned.startsWith('/')) return '$siteBaseUrl$cleaned';
    return cleaned;
  }

  String _decodeEntities(String value) {
    return value
        .replaceAllMapped(RegExp(r'&#(\d+);'), (match) => String.fromCharCode(int.parse(match.group(1)!)))
        .replaceAllMapped(RegExp(r'&#x([a-f\d]+);', caseSensitive: false), (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)))
        .replaceAll('&amp;', '&')
        .replaceAll('&#038;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&rsquo;', "'")
        .replaceAll('&lsquo;', "'")
        .replaceAll('&rdquo;', '"')
        .replaceAll('&ldquo;', '"')
        .replaceAll('&nbsp;', ' ');
  }

  DateTime? _tryParseDate(DateFormat format, String input) {
    try {
      return format.parse(input);
    } catch (_) {
      return null;
    }
  }
}
