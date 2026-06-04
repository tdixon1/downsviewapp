import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/church_content.dart';

const _adventechWebBase = 'https://sabbath-school.adventech.io';

class SabbathSchoolService {
  SabbathSchoolService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _apiBase = 'https://sabbath-school.adventech.io/api/v2';

  Future<List<SabbathLesson>> fetchCurrentLessons() async {
    final adult = await _fetchCurrentLessonForGroup(
      groupName: 'Standard Adult',
      ageGroup: 'Adults',
      fallbackTitle: 'Adult Bible Study Guide',
    );
    final youngAdult = await _fetchCurrentLessonForGroup(
      groupName: 'InVerse',
      ageGroup: 'Young Adults',
      fallbackTitle: 'inVerse Bible Study Guide',
    );
    final youth = await _fetchCurrentLessonForGroup(
      groupName: 'Cornerstone Connections',
      ageGroup: 'Youth',
      fallbackTitle: 'Cornerstone Connections',
    );

    return [
      adult ?? _fallbacks[0],
      youngAdult ?? _fallbacks[1],
      youth ?? _fallbacks[2],
      ..._fallbacks.skip(3),
    ];
  }

  Future<SabbathLesson?> _fetchCurrentLessonForGroup({
    required String groupName,
    required String ageGroup,
    required String fallbackTitle,
  }) async {
    final quarterlies = await _fetchJson<List<dynamic>>('/en/quarterlies/index.json');
    final groupQuarterlies = (quarterlies ?? [])
        .whereType<Map<String, dynamic>>()
        .where((quarterly) {
          final group = quarterly['quarterly_group'];
          final name = group is Map<String, dynamic> ? group['name'] as String? : null;
          return (name ?? '').toLowerCase().contains(groupName.toLowerCase());
        })
        .toList();
    final currentQuarterly = groupQuarterlies.firstWhere(
      (quarterly) => _isCurrent(quarterly['start_date'] as String?, quarterly['end_date'] as String?),
      orElse: () => groupQuarterlies.isEmpty ? <String, dynamic>{} : groupQuarterlies.first,
    );
    final quarterlyId = currentQuarterly['id'] as String?;
    if (quarterlyId == null) return null;

    final detail = await _fetchJson<Map<String, dynamic>>('/en/quarterlies/$quarterlyId/index.json');
    final lessons = detail?['lessons'];
    if (lessons is! List || lessons.isEmpty) return null;
    final currentLesson = lessons.whereType<Map<String, dynamic>>().firstWhere(
      (lesson) => _isCurrent(lesson['start_date'] as String?, lesson['end_date'] as String?),
      orElse: () => lessons.first as Map<String, dynamic>,
    );
    final lessonId = currentLesson['id'] as String?;
    if (lessonId == null) return null;

    final lessonDetail = await _fetchJson<Map<String, dynamic>>(
      '/en/quarterlies/$quarterlyId/lessons/$lessonId/index.json',
    );
    final days = lessonDetail?['days'];
    String dayId = _adventechDaySegment();
    if (days is List) {
      final today = days.whereType<Map<String, dynamic>>().where(
        (day) => _isToday(day['date'] as String?),
      );
      if (today.isNotEmpty && today.first['id'] is String) {
        dayId = today.first['id'] as String;
      }
    }

    final quarterlyInfo = detail?['quarterly'] is Map<String, dynamic>
        ? detail!['quarterly'] as Map<String, dynamic>
        : currentQuarterly;
    final visuals = _visuals[ageGroup]!;

    return SabbathLesson(
      ageGroup: ageGroup,
      title: currentLesson['title'] as String? ??
          quarterlyInfo['title'] as String? ??
          fallbackTitle,
      dateLabel: _formatRange(
        currentLesson['start_date'] as String?,
        currentLesson['end_date'] as String?,
      ),
      summary: quarterlyInfo['title'] as String? ?? fallbackTitle,
      url: '$_adventechWebBase/en/$quarterlyId/$lessonId/$dayId',
      color: visuals.color,
      accentColor: visuals.accent,
    );
  }

  Future<T?> _fetchJson<T>(String path) async {
    try {
      final response = await _client.get(
        Uri.parse('$_apiBase$path'),
        headers: const {'Accept': 'application/json, text/plain, */*'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      if (response.body.trimLeft().startsWith('<')) return null;
      return jsonDecode(response.body) as T;
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseAdventechDate(String? value) {
    if (value == null) return null;
    final parts = value.split('/').map(int.tryParse).toList();
    if (parts.length != 3 || parts.any((part) => part == null)) return null;
    return DateTime(parts[2]!, parts[1]!, parts[0]!);
  }

  bool _isToday(String? value) {
    final parsed = _parseAdventechDate(value);
    if (parsed == null) return false;
    final now = DateTime.now();
    return parsed.year == now.year && parsed.month == now.month && parsed.day == now.day;
  }

  bool _isCurrent(String? start, String? end) {
    final startDate = _parseAdventechDate(start);
    final endDate = _parseAdventechDate(end);
    if (startDate == null || endDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    return !today.isBefore(startDate) && !today.isAfter(endOfDay);
  }

  String? _formatRange(String? start, String? end) {
    final startDate = _parseAdventechDate(start);
    final endDate = _parseAdventechDate(end);
    if (startDate == null || endDate == null) return null;
    final format = DateFormat('MMM d');
    return '${format.format(startDate)}-${format.format(endDate)}';
  }

  String _adventechDaySegment() {
    final day = DateTime.now().weekday % 7;
    final sabbathFirstDay = day == 6 ? 1 : day + 2;
    return sabbathFirstDay.toString().padLeft(2, '0');
  }
}

class _LessonVisual {
  const _LessonVisual(this.color, this.accent);
  final String color;
  final String accent;
}

const _visuals = {
  'Adults': _LessonVisual('#1E3A8A', '#FBBF24'),
  'Young Adults': _LessonVisual('#7C2D12', '#FDBA74'),
  'Youth': _LessonVisual('#4338CA', '#FBBF24'),
  'Beginner': _LessonVisual('#065F46', '#A7F3D0'),
  'Kindergarten': _LessonVisual('#6D28D9', '#DDD6FE'),
  'Primary': _LessonVisual('#BE123C', '#FBCFE8'),
  'Junior / Teen': _LessonVisual('#0F766E', '#99F6E4'),
};

const _fallbacks = [
  SabbathLesson(
    ageGroup: 'Adults',
    title: 'Adult Bible Study Guide',
    summary: 'Open the official Adventech Sabbath School lesson for this week.',
    url: '$_adventechWebBase/en/',
    color: '#1E3A8A',
    accentColor: '#FBBF24',
  ),
  SabbathLesson(
    ageGroup: 'Young Adults',
    title: 'inVerse Bible Study Guide',
    summary: 'Current young adult Bible study content from Adventech.',
    url: '$_adventechWebBase/en/quarterlies',
    color: '#7C2D12',
    accentColor: '#FDBA74',
  ),
  SabbathLesson(
    ageGroup: 'Youth',
    title: 'Cornerstone Connections',
    summary: 'Current youth Sabbath School quarterly.',
    url: '$_adventechWebBase/en/quarterlies',
    color: '#4338CA',
    accentColor: '#FBBF24',
  ),
  SabbathLesson(
    ageGroup: 'Beginner',
    title: 'Alive in Jesus - Beginner',
    summary: 'Current lesson resources for toddlers and early learners.',
    url: 'https://beginner.aliveinjesus.info/students',
    color: '#065F46',
    accentColor: '#A7F3D0',
  ),
  SabbathLesson(
    ageGroup: 'Kindergarten',
    title: 'Alive in Jesus - Kindergarten',
    summary: 'Current Sabbath School resources for kindergarten children.',
    url: 'https://kindergarten.aliveinjesus.info/students',
    color: '#6D28D9',
    accentColor: '#DDD6FE',
  ),
  SabbathLesson(
    ageGroup: 'Primary',
    title: 'Alive in Jesus - Primary',
    summary: 'Current lesson resources for primary-age children.',
    url: 'https://primary.aliveinjesus.info/students',
    color: '#BE123C',
    accentColor: '#FBCFE8',
  ),
  SabbathLesson(
    ageGroup: 'Junior / Teen',
    title: 'Junior PowerPoints',
    summary: 'Current lesson resources for junior and teen Sabbath School.',
    url: 'https://www.juniorpowerpoints.org/',
    color: '#0F766E',
    accentColor: '#99F6E4',
  ),
];
