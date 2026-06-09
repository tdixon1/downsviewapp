import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/church_content.dart';
import '../services/calendar_service.dart';
import '../services/notification_service.dart';
import '../services/permission_settings_service.dart';
import '../services/supabase_service.dart';
import '../services/url_service.dart';
import '../services/wordpress_service.dart';
import '../theme.dart';
import 'hymnal_screen.dart';

class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});

  @override
  State<InfoScreen> createState() => InfoScreenState();
}

class InfoScreenState extends State<InfoScreen> {
  final _wordpress = WordpressService();
  final _calendar = CalendarService();
  final _notifications = NotificationService();

  List<WpPost> _posts = const [];
  List<_SavedPost> _savedPosts = const [];
  ChurchSermon? _sermon;
  ChurchBulletin? _bulletin;
  List<ChurchEvent> _events = const [];
  Set<String> _bookmarkedUrls = {};
  bool _loading = true;
  bool _loadingHighlights = true;
  bool _canNotifyFromPosts = false;
  ChurchEvent? _selectedEvent;

  @override
  void initState() {
    super.initState();
    _load();
    _loadNotificationRole();
    _loadBookmarks();
  }

  Future<void> _load() async {
    setState(() {
      if (_posts.isEmpty) {
        _loading = true;
        _loadingHighlights = true;
      }
    });

    try {
      final results = await Future.wait([
        _wordpress.fetchLatestPosts(),
        _wordpress.fetchLatestSermon(),
        _wordpress.fetchLatestBulletin(),
        _wordpress.fetchUpcomingEvents(limit: 4),
      ]);
      if (!mounted) return;
      setState(() {
        _posts = results[0] as List<WpPost>;
        _sermon = results[1] as ChurchSermon?;
        _bulletin = results[2] as ChurchBulletin?;
        _events = results[3] as List<ChurchEvent>;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingHighlights = false;
        });
      }
    }
  }

  Future<void> _loadNotificationRole() async {
    final user = supabase.auth.currentUser;
    final roles = <String>{
      if (user?.appMetadata['role'] is String) user!.appMetadata['role'] as String,
      if (user?.userMetadata?['role'] is String) user!.userMetadata!['role'] as String,
      if (user?.appMetadata['roles'] is List)
        ...(user!.appMetadata['roles'] as List).whereType<String>(),
    };
    if (!mounted) return;
    setState(() {
      _canNotifyFromPosts = roles.any(pushAuthorizedRoles.contains);
    });
  }

  Future<void> _loadBookmarks() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final data = await supabase
        .from('content_bookmarks')
        .select('title,url,image_url,created_at')
        .eq('user_id', user.id)
        .eq('content_type', 'post')
        .order('created_at', ascending: false)
        .limit(100);
    final saved = (data as List<dynamic>)
        .map((item) => _SavedPost.fromMap(item as Map<String, dynamic>))
        .toList();
    if (!mounted) return;
    setState(() {
      _savedPosts = saved;
      _bookmarkedUrls = saved.map((post) => post.url).toSet();
    });
  }

  void showEventFromNotification(ChurchEvent event) {
    setState(() => _selectedEvent = event);
  }

  Future<void> _toggleBookmark(WpPost post) async {
    final user = supabase.auth.currentUser;
    final postLink = post.link;
    if (user == null || postLink == null) {
      _showSnack('Please sign in to bookmark church content.');
      return;
    }

    if (_bookmarkedUrls.contains(postLink)) {
      await supabase.from('content_bookmarks').delete().eq('user_id', user.id).eq('url', postLink);
      if (!mounted) return;
      setState(() {
        _bookmarkedUrls = {..._bookmarkedUrls}..remove(postLink);
        _savedPosts = _savedPosts.where((bookmark) => bookmark.url != postLink).toList();
      });
      return;
    }

    await supabase.from('content_bookmarks').upsert({
      'user_id': user.id,
      'content_type': 'post',
      'title': post.title,
      'url': postLink,
      'image_url': post.imageUrl,
    }, onConflict: 'user_id,url');
    if (!mounted) return;
    setState(() {
      _bookmarkedUrls = {..._bookmarkedUrls, postLink};
      _savedPosts = [
        _SavedPost(
          title: post.title,
          url: postLink,
          imageUrl: post.imageUrl,
          createdAt: DateTime.now(),
        ),
        ..._savedPosts,
      ];
    });
  }

  Future<void> _queuePostNotification(WpPost post) async {
    final user = supabase.auth.currentUser;
    try {
      await supabase.from('push_notification_messages').insert({
        'title': 'New: ${post.title}',
        'body': post.excerpt.isEmpty ? 'A new update is available from Downsview SDA Church.' : post.excerpt,
        'sent_by_id': user?.id,
        'sent_by_name': user?.userMetadata?['full_name'] ?? user?.email ?? 'Church Team',
        'status': 'queued',
        'target_audience': 'all',
        'data': {
          'action': 'open_post',
          'url': post.link,
          'title': 'New: ${post.title}',
          'body': post.excerpt,
          'imageUrl': post.imageUrl,
        },
      });
      await supabase.functions.invoke('send-push-notifications');
      _showSnack('Notification queued.');
    } catch (error) {
      _showSnack('Could not queue notification. Please run the latest Supabase patch and try again.');
    }
  }

  Future<void> _queueEventNotification(ChurchEvent event) async {
    final user = supabase.auth.currentUser;
    try {
      await supabase.from('push_notification_messages').insert({
        'title': event.title,
        'body': [event.dateLabel, event.timeLabel].whereType<String>().join(' | '),
        'sent_by_id': user?.id,
        'sent_by_name': user?.userMetadata?['full_name'] ?? user?.email ?? 'Church Team',
        'status': 'queued',
        'target_audience': 'all',
        'data': {
          'action': 'open_event',
          'url': event.url,
          'eventTitle': event.title,
          'eventDateLabel': event.dateLabel,
          'eventTimeLabel': event.timeLabel,
          'eventDetails': event.details,
          'eventImageUrl': event.imageUrl,
          'imageUrl': event.imageUrl,
          'eventIsClosed': event.isClosed.toString(),
        },
      });
      await supabase.functions.invoke('send-push-notifications');
      _showSnack('Event notification queued.');
    } catch (error) {
      _showSnack('Could not queue event notification. Please run the latest Supabase patch and try again.');
    }
  }

  Future<void> _addSelectedEventToCalendar() async {
    final event = _selectedEvent;
    if (event == null) return;
    final result = await _calendar.addEventToCalendar(event);
    if (!mounted) return;
    _showMessage(
      result.opened ? 'Calendar Opened' : 'Calendar Not Available',
      result.message,
      settingsTarget: result.opened ? null : PermissionSettingsTarget.calendar,
    );
  }

  Future<void> _remindMeAboutSelectedEvent() async {
    final event = _selectedEvent;
    if (event == null) return;
    final scheduled = await _notifications.scheduleEventReminder(event.title, event.dateLabel, event.timeLabel);
    if (!mounted) return;
    _showMessage(
      scheduled ? 'Reminder Set' : 'Notification Access Needed',
      scheduled ? 'A reminder has been scheduled for this event.' : 'Please allow notifications to receive event reminders.',
      settingsTarget: scheduled ? null : PermissionSettingsTarget.notifications,
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showMessage(
    String title,
    String message, {
    PermissionSettingsTarget? settingsTarget,
  }) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          if (settingsTarget != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                PermissionSettingsService.open(settingsTarget);
              },
              child: const Text('Open Settings'),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sermonIsUpcoming = _sermon?.isUpcoming ?? false;
    final sermonLabel = sermonIsUpcoming ? 'Upcoming Sermon' : 'Latest Sermon';
    final sermonAction = sermonIsUpcoming ? 'View sermon details' : 'Watch sermon';
    final sermonMeta = [
      if (sermonIsUpcoming) _formatDate(_sermon?.date),
      if (_sermon?.speaker != null) 'Speaker: ${_sermon!.speaker}',
    ].whereType<String>().join(' | ');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            key: const PageStorageKey('info-scroll'),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 128),
            children: [
              Image.asset('assets/downsview-logo-black.png', width: 230, alignment: Alignment.centerLeft),
              const SizedBox(height: 16),
              const _InfoHero(),
              const SizedBox(height: 16),
              _HymnalEntryPanel(
                onOpen: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HymnalScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _FeaturePanel(
                sermon: _sermon,
                sermonLabel: sermonLabel,
                sermonAction: sermonAction,
                sermonMeta: sermonMeta,
                loading: _loadingHighlights,
                onOpen: () => openUrl(context, _sermon?.url),
                onViewAll: () => openUrl(context, 'https://downsviewsda.org/sermons/'),
              ),
              const SizedBox(height: 12),
              _BulletinPanel(
                bulletin: _bulletin,
                onOpen: () => openUrl(context, _bulletin?.pdfUrl ?? _bulletin?.url),
              ),
              const SizedBox(height: 12),
              _EventsPanel(
                events: _events,
                canNotify: _canNotifyFromPosts,
                onViewAll: () => openUrl(context, 'https://downsviewsda.org/events/'),
                onSelect: (event) => setState(() => _selectedEvent = event),
                onNotify: _queueEventNotification,
              ),
              if (_savedPosts.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SavedPostsPanel(
                  posts: _savedPosts.take(4).toList(),
                  onOpen: (post) => openUrl(context, post.url),
                ),
              ],
              const SizedBox(height: 12),
              _PostsHeader(onViewAll: () => openUrl(context, 'https://downsviewsda.org/news/')),
              const SizedBox(height: 8),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_posts.isEmpty)
                const _EmptyPosts()
              else
                for (final post in _posts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PostCard(
                      post: post,
                      isBookmarked: post.link != null && _bookmarkedUrls.contains(post.link),
                      canNotify: _canNotifyFromPosts,
                      onOpen: () => openUrl(context, post.link),
                      onSave: () => _toggleBookmark(post),
                      onNotify: () => _queuePostNotification(post),
                    ),
                  ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
      bottomSheet: _selectedEvent == null
          ? null
          : _EventSheet(
              event: _selectedEvent!,
              onClose: () => setState(() => _selectedEvent = null),
              onOpen: () => openUrl(context, _selectedEvent?.url),
              onCalendar: _addSelectedEventToCalendar,
              onReminder: _remindMeAboutSelectedEvent,
            ),
    );
  }
}

class _InfoHero extends StatelessWidget {
  const _InfoHero();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.hero),
      child: Stack(
        children: [
          Image.asset(
            'assets/Downsview Church Photo.jpg',
            height: 244,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Container(
            height: 244,
            padding: const EdgeInsets.all(24),
            color: const Color(0xC2F6F8FC),
            alignment: Alignment.centerLeft,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Church News', style: TextStyle(color: AppColors.blue, fontSize: 14, fontWeight: FontWeight.w900)),
                SizedBox(height: 12),
                Text('This week at Downsview', style: TextStyle(color: AppColors.text, fontSize: 36, fontWeight: FontWeight.w900, height: 1.15)),
                SizedBox(height: 12),
                Text(
                  'Sermons, bulletins, events, and announcements from the church family.',
                  style: TextStyle(color: AppColors.slate, fontSize: 15, fontWeight: FontWeight.w700, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(16), this.onTap});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.icon, required this.title, this.action, this.onAction});

  final IconData icon;
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(color: AppColors.lightBlue, borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, color: AppColors.blue, size: 17),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w900))),
        if (action != null)
          TextButton.icon(
            onPressed: onAction,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.chevron_right, size: 15),
            label: Text(action!),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.blue,
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ),
      ],
    );
  }
}

class _HymnalEntryPanel extends StatelessWidget {
  const _HymnalEntryPanel({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      onTap: onOpen,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(Icons.music_note, color: AppColors.gold, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Seventh-day Adventist Hymnal', style: TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('Search hymns by number, title, first line, category, or tune.', style: TextStyle(color: AppColors.slate, fontSize: 13, fontWeight: FontWeight.w700, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _FeaturePanel extends StatelessWidget {
  const _FeaturePanel({
    required this.sermon,
    required this.sermonLabel,
    required this.sermonAction,
    required this.sermonMeta,
    required this.loading,
    required this.onOpen,
    required this.onViewAll,
  });

  final ChurchSermon? sermon;
  final String sermonLabel;
  final String sermonAction;
  final String sermonMeta;
  final bool loading;
  final VoidCallback onOpen;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(icon: Icons.radio, title: 'Live Website Highlights', action: 'View all', onAction: onViewAll),
          const SizedBox(height: 14),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            InkWell(
              onTap: onOpen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: sermon?.imageUrl == null
                        ? Container(
                            height: 142,
                            width: double.infinity,
                            color: AppColors.navy,
                            child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 44),
                          )
                        : Image.network(sermon!.imageUrl!, height: 142, width: double.infinity, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 12),
                  Text(sermonLabel, style: const TextStyle(color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(sermon?.title ?? 'Latest sermon', style: const TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w900, height: 1.35)),
                  const SizedBox(height: 4),
                  Text(
                    sermonMeta.isEmpty ? 'Open the newest message from Downsview SDA.' : sermonMeta,
                    style: const TextStyle(color: AppColors.slate, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  Text(sermonAction, style: const TextStyle(color: AppColors.blue, fontSize: 13, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BulletinPanel extends StatelessWidget {
  const _BulletinPanel({required this.bulletin, required this.onOpen});

  final ChurchBulletin? bulletin;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeader(icon: Icons.description, title: 'Latest Bulletin'),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 190),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: AppColors.paleBlue, borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.description, color: AppColors.blue, size: 34),
                ),
                const SizedBox(height: 14),
                Text(bulletin?.title ?? 'Latest Bulletin', style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('Check weekly for key announcements and updates.', style: TextStyle(color: AppColors.slate, fontSize: 14, height: 1.5)),
                const SizedBox(height: 12),
                const Text('Open bulletin PDF', style: TextStyle(color: AppColors.blue, fontSize: 13, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventsPanel extends StatelessWidget {
  const _EventsPanel({
    required this.events,
    required this.canNotify,
    required this.onViewAll,
    required this.onSelect,
    required this.onNotify,
  });

  final List<ChurchEvent> events;
  final bool canNotify;
  final VoidCallback onViewAll;
  final ValueChanged<ChurchEvent> onSelect;
  final ValueChanged<ChurchEvent> onNotify;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(icon: Icons.calendar_month, title: 'Upcoming Events', action: 'View all', onAction: onViewAll),
          const SizedBox(height: 4),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Upcoming events will appear here when available.', style: TextStyle(color: AppColors.slate, fontSize: 14)),
            )
          else
            for (final event in events)
              _EventRow(
                event: event,
                canNotify: canNotify,
                onTap: () => onSelect(event),
                onNotify: () => onNotify(event),
              ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.canNotify,
    required this.onTap,
    required this.onNotify,
  });

  final ChurchEvent event;
  final bool canNotify;
  final VoidCallback onTap;
  final VoidCallback onNotify;

  @override
  Widget build(BuildContext context) {
    final parts = _splitEventDate(event.dateLabel);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFEEF2F7)))),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(color: AppColors.lightBlue, borderRadius: BorderRadius.circular(13)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(parts.$1, style: const TextStyle(color: AppColors.blue, fontSize: 11, fontWeight: FontWeight.w900)),
                  Text(parts.$2, style: const TextStyle(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: event.imageUrl == null
                  ? Container(
                      width: 110,
                      height: 54,
                      color: AppColors.navy,
                      alignment: Alignment.center,
                      child: const Text('Event', style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w900)),
                    )
                  : Image.network(event.imageUrl!, width: 110, height: 54, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w900)),
                  if (event.timeLabel != null && event.timeLabel!.isNotEmpty)
                    Text(event.timeLabel!, style: const TextStyle(color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w700)),
                  if (canNotify) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton(
                        onPressed: onNotify,
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          foregroundColor: AppColors.text,
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                        ),
                        child: const Text('Notify'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.text, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SavedPostsPanel extends StatelessWidget {
  const _SavedPostsPanel({required this.posts, required this.onOpen});

  final List<_SavedPost> posts;
  final ValueChanged<_SavedPost> onOpen;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeader(icon: Icons.bookmark, title: 'Saved Posts'),
          const SizedBox(height: 4),
          for (final post in posts)
            InkWell(
              onTap: () => onOpen(post),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFEEF2F7)))),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: post.imageUrl == null
                          ? Container(
                              width: 58,
                              height: 58,
                              color: AppColors.lightBlue,
                              child: const Icon(Icons.newspaper, color: AppColors.blue, size: 20),
                            )
                          : Image.network(post.imageUrl!, width: 58, height: 58, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(post.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w900, height: 1.35)),
                          const SizedBox(height: 3),
                          const Text('Saved for later', style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.muted, size: 19),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PostsHeader extends StatelessWidget {
  const _PostsHeader({required this.onViewAll});

  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: _PanelHeader(icon: Icons.newspaper, title: 'Latest Posts', action: 'View all', onAction: onViewAll),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.isBookmarked,
    required this.canNotify,
    required this.onOpen,
    required this.onSave,
    required this.onNotify,
  });

  final WpPost post;
  final bool isBookmarked;
  final bool canNotify;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onNotify;

  @override
  Widget build(BuildContext context) {
    final date = _formatDate(post.date) ?? '';
    return _Panel(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onOpen,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  post.imageUrl == null
                      ? Container(width: 132, height: 116, color: AppColors.border)
                      : Image.network(post.imageUrl!, width: 132, height: 116, fit: BoxFit.cover),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xD1102A43), borderRadius: BorderRadius.circular(AppRadii.pill)),
                      child: Text(date, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: onOpen,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(post.title, style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w900, height: 1.35)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(color: AppColors.lightBlue, borderRadius: BorderRadius.circular(AppRadii.pill)),
                            child: const Text('News', style: TextStyle(color: AppColors.blue, fontSize: 11, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(post.excerpt, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.slate, fontSize: 13, height: 1.45)),
                      const SizedBox(height: 8),
                      const Text('Read post', style: TextStyle(color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (canNotify) ...[
                      OutlinedButton(
                        onPressed: onNotify,
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                          foregroundColor: AppColors.text,
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                        ),
                        child: const Text('Notify'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    FilledButton(
                      onPressed: onSave,
                      style: FilledButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
                        backgroundColor: isBookmarked ? AppColors.blue : AppColors.navy,
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                      ),
                      child: Text(isBookmarked ? 'Saved' : 'Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPosts extends StatelessWidget {
  const _EmptyPosts();

  @override
  Widget build(BuildContext context) {
    return const _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No updates found', style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w900)),
          SizedBox(height: 6),
          Text('Check back soon for church news and announcements.', style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}

class _EventSheet extends StatelessWidget {
  const _EventSheet({
    required this.event,
    required this.onClose,
    required this.onOpen,
    required this.onCalendar,
    required this.onReminder,
  });

  final ChurchEvent event;
  final VoidCallback onClose;
  final VoidCallback onOpen;
  final VoidCallback onCalendar;
  final VoidCallback onReminder;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0x85102A43),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (event.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(event.imageUrl!, height: 170, fit: BoxFit.cover),
                  ),
                if (event.imageUrl != null) const SizedBox(height: 16),
                const Text('Event Details', style: TextStyle(color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(event.title, style: const TextStyle(color: AppColors.text, fontSize: 24, fontWeight: FontWeight.w900, height: 1.3)),
                const SizedBox(height: 10),
                Text([event.dateLabel, event.timeLabel].whereType<String>().join(' | '), style: const TextStyle(color: AppColors.slate, fontSize: 15, fontWeight: FontWeight.w800)),
                if (event.isClosed) ...[
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: _ClosedBadge(),
                  ),
                ],
                if (event.details != null) ...[
                  const SizedBox(height: 12),
                  Text(event.details!, style: const TextStyle(color: AppColors.muted, fontSize: 14, height: 1.55)),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: _UtilityButton(label: 'Add to Calendar', onTap: onCalendar)),
                    const SizedBox(width: 10),
                    Expanded(child: _UtilityButton(label: 'Remind Me', onTap: onReminder)),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: onOpen, child: const Text('Open Event Page')),
                TextButton(onPressed: onClose, child: const Text('Close', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w900))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClosedBadge extends StatelessWidget {
  const _ClosedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: const Text('Closed', style: TextStyle(color: Color(0xFFB45309), fontSize: 12, fontWeight: FontWeight.w900)),
    );
  }
}

class _UtilityButton extends StatelessWidget {
  const _UtilityButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: AppColors.lightBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 13),
      ),
      child: Text(label, style: const TextStyle(color: AppColors.blue, fontSize: 13, fontWeight: FontWeight.w900)),
    );
  }
}

class _SavedPost {
  const _SavedPost({
    required this.title,
    required this.url,
    required this.createdAt,
    this.imageUrl,
  });

  final String title;
  final String url;
  final DateTime createdAt;
  final String? imageUrl;

  factory _SavedPost.fromMap(Map<String, dynamic> map) {
    return _SavedPost(
      title: map['title'] as String? ?? 'Saved post',
      url: map['url'] as String? ?? '',
      imageUrl: map['image_url'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

(String, String) _splitEventDate(String dateLabel) {
  final parts = dateLabel.split(RegExp(r'\s+'));
  return ((parts.isEmpty ? 'UP' : parts.first).substring(0, parts.isEmpty ? 2 : parts.first.length.clamp(0, 3)).toUpperCase(), parts.length > 1 ? parts[1] : '');
}

String? _formatDate(DateTime? date) {
  if (date == null) return null;
  return DateFormat(date.year == DateTime.now().year ? 'MMM d' : 'MMM d, yyyy').format(date);
}
