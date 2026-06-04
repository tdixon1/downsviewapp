import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/church_content.dart';
import '../services/calendar_service.dart';
import '../services/notification_service.dart';
import '../services/permission_settings_service.dart';
import '../services/sabbath_school_service.dart';
import '../services/supabase_service.dart';
import '../services/url_service.dart';
import '../services/wordpress_service.dart';
import '../theme.dart';
import '../widgets/parity_widgets.dart';

const _liveStreamUrl = 'https://www.youtube.com/@downsviewchurch/live';
const _adventistGivingUrl = 'https://adventistgiving.org/donate/AN6MDO';
const _etransferEmail = 'downsviewtreasuerer@adventistontario.org';
const _churchLatitude = 43.7315;
const _churchLongitude = -79.5014;
const _wednesdayPrayerZoomUrl = String.fromEnvironment(
  'WEDNESDAY_PRAYER_ZOOM_URL',
  defaultValue: 'https://us02web.zoom.us/j/84131148781?pwd=blRwcFd4SjQ0VHJYQ1p1WlNTaVF0dz09',
);
const _kabsZoomUrl = String.fromEnvironment(
  'KABS_ZOOM_URL',
  defaultValue: 'https://us06web.zoom.us/j/98142322772?pwd=Q2t5dUFUNm5mV3hyMUdaVWRIZTNzZz09',
);

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.isGuest,
    required this.onSignInPress,
  });

  final bool isGuest;
  final VoidCallback onSignInPress;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _wordpress = WordpressService();
  final _lessons = SabbathSchoolService();
  final _calendar = CalendarService();
  final _notifications = NotificationService();

  ChurchSermon? _sermon;
  ChurchBulletin? _bulletin;
  List<ChurchEvent> _events = const [];
  List<SabbathLesson> _sabbathLessons = const [];
  bool _loadingChurchContent = true;
  ChurchEvent? _selectedEvent;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _wordpress.fetchLatestSermon(),
      _wordpress.fetchLatestBulletin(),
      _wordpress.fetchUpcomingEvents(limit: 3),
      _lessons.fetchCurrentLessons(),
    ]);
    if (!mounted) return;
    setState(() {
      _sermon = results[0] as ChurchSermon?;
      _bulletin = results[1] as ChurchBulletin?;
      _events = results[2] as List<ChurchEvent>;
      _sabbathLessons = results[3] as List<SabbathLesson>;
      _loadingChurchContent = false;
    });
  }

  Future<void> _openGive() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Give'),
        content: const Text('Choose how you would like to give.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'adventist'), child: const Text('Adventist Giving')),
          TextButton(onPressed: () => Navigator.pop(context, 'etransfer'), child: const Text('eTransfer Info')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    );

    if (!mounted) return;
    if (choice == 'adventist') {
      await openUrl(context, _adventistGivingUrl);
    } else if (choice == 'etransfer') {
      const text = 'Recipient: $_etransferEmail\nComments: Enter giving details such as tithe, offering, ministry, or special project.';
      await Clipboard.setData(const ClipboardData(text: text));
      _showMessage(
        'eTransfer Details Copied',
        'Send eTransfer to:\n$_etransferEmail\n\nIn the comments section, enter giving details such as tithe, offering, ministry, or special project.',
      );
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

  String get _firstName {
    final user = supabase.auth.currentUser;
    final fullName = user?.userMetadata?['full_name'] as String?;
    return (fullName ?? user?.email?.split('@').first ?? 'Church Family')
        .trim()
        .split(RegExp(r'\s+'))
        .first;
  }

  @override
  Widget build(BuildContext context) {
    final sermonIsUpcoming = _sermon?.isUpcoming ?? false;
    final sermonKicker = sermonIsUpcoming ? 'Upcoming Sermon' : 'Latest Sermon';
    final sermonActionLabel = sermonIsUpcoming ? 'View sermon details' : 'Watch sermon';
    final sermonMetaText = [
      if (sermonIsUpcoming) _formatSermonDate(_sermon?.date),
      if (_sermon?.speaker != null) 'Speaker: ${_sermon!.speaker}',
    ].whereType<String>().join(' | ');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            key: const PageStorageKey('home-scroll'),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 128),
            children: [
              _TopBar(firstName: _firstName, dayContext: _homeDayContext(), onCalendar: () => openUrl(context, 'https://downsviewsda.org/events/')),
              const SizedBox(height: 18),
              _HeroPanel(
                sermon: _sermon,
                showLiveStream: _isLiveStreamWindow(),
                isWednesday: DateTime.now().weekday == DateTime.wednesday,
                isSabbath: _isSabbathTime(),
              ),
              const SizedBox(height: 18),
              SectionHeader(
                title: 'Quick Actions',
                action: _loadingChurchContent ? null : 'View All',
                trailing: _loadingChurchContent ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                onAction: () => openUrl(context, 'https://downsviewsda.org/events/'),
              ),
              const SizedBox(height: 12),
              _QuickActions(
                showLiveStream: _isLiveStreamWindow(),
                onLive: () => openUrl(context, _liveStreamUrl),
                onSermons: () => openUrl(context, 'https://downsviewsda.org/sermons/'),
                onEvents: () => openUrl(context, 'https://downsviewsda.org/events/'),
                onGive: _openGive,
              ),
              const SizedBox(height: 18),
              const SectionHeader(title: 'Online Meetings'),
              const SizedBox(height: 12),
              _ZoomGrid(
                onPrayer: () => openUrl(context, _wednesdayPrayerZoomUrl),
                onKabs: () => openUrl(context, _kabsZoomUrl),
              ),
              const SizedBox(height: 18),
              ParityPanel(
                radius: AppRadii.card,
                padding: const EdgeInsets.all(16),
                onTap: () => openUrl(context, _sermon?.url),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sermonKicker, style: const TextStyle(color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: _sermon?.imageUrl == null
                          ? Container(
                              height: 164,
                              width: double.infinity,
                              color: AppColors.navy,
                              child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 48),
                            )
                          : Image.network(_sermon!.imageUrl!, height: 164, width: double.infinity, fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 14),
                    Text(_sermon?.title ?? 'Latest sermon', style: const TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w900, height: 1.35)),
                    const SizedBox(height: 7),
                    Text(sermonMetaText.isEmpty ? _formatSermonDate(_sermon?.date) ?? 'Latest message' : sermonMetaText, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.45)),
                    const SizedBox(height: 13),
                    Text(sermonActionLabel, style: const TextStyle(color: AppColors.blue, fontSize: 13, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ParityPanel(
                radius: AppRadii.card,
                padding: const EdgeInsets.all(16),
                onTap: () => openUrl(context, _bulletin?.pdfUrl ?? _bulletin?.url),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Text('Bulletin', style: TextStyle(color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.w900))),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(color: AppColors.lightBlue, borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.description, color: AppColors.blue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('Open this week\'s order of service', style: TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 7),
                    Text(_bulletin?.title ?? 'Latest Bulletin', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                    const SizedBox(height: 13),
                    const Text('Open bulletin PDF', style: TextStyle(color: AppColors.blue, fontSize: 13, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ParityPanel(
                radius: AppRadii.card,
                padding: const EdgeInsets.all(17),
                shadow: false,
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Expanded(child: Text('Sabbath School', style: TextStyle(color: AppColors.text, fontSize: 21, fontWeight: FontWeight.w900))),
                        Text('Current lessons', style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    for (final lesson in _sabbathLessons)
                      _LessonRow(lesson: lesson, onTap: () => openUrl(context, lesson.url)),
                  ],
                ),
              ),
              if (_events.isNotEmpty) ...[
                const SizedBox(height: 18),
                _NextBanner(event: _events.first, onTap: () => setState(() => _selectedEvent = _events.first)),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      bottomSheet: _selectedEvent == null ? null : _EventSheet(
        event: _selectedEvent!,
        onClose: () => setState(() => _selectedEvent = null),
        onOpen: () => openUrl(context, _selectedEvent?.url),
        onCalendar: _addSelectedEventToCalendar,
        onReminder: _remindMeAboutSelectedEvent,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.firstName, required this.dayContext, required this.onCalendar});

  final String firstName;
  final String? dayContext;
  final VoidCallback onCalendar;

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;
    return Row(
      children: [
        avatarUrl == null
            ? CircleAvatar(
                radius: 25,
                backgroundColor: AppColors.paleBlue,
                child: Text(firstName.characters.first.toUpperCase(), style: const TextStyle(color: Color(0xFF1D4ED8), fontSize: 22, fontWeight: FontWeight.w900)),
              )
            : CircleAvatar(radius: 25, backgroundImage: NetworkImage(avatarUrl)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting(), style: const TextStyle(color: AppColors.slate, fontSize: 14, fontWeight: FontWeight.w700)),
              Text(firstName, style: const TextStyle(color: AppColors.text, fontSize: 24, fontWeight: FontWeight.w900)),
              if (dayContext != null)
                Text(dayContext!, style: const TextStyle(color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(color: Color(0xFFEAF0F8), shape: BoxShape.circle),
          child: IconButton(onPressed: onCalendar, icon: const Icon(Icons.calendar_month_outlined, color: AppColors.text)),
        ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.sermon, required this.showLiveStream, required this.isWednesday, required this.isSabbath});

  final ChurchSermon? sermon;
  final bool showLiveStream;
  final bool isWednesday;
  final bool isSabbath;

  @override
  Widget build(BuildContext context) {
    const heroHeight = 540.0;
    final sermonIsUpcoming = sermon?.isUpcoming ?? false;
    final content = isWednesday
        ? _HeroContent(
            metaLabel: 'Wednesday',
            metaDate: 'Prayer Meeting 7 PM',
            pill: 'Midweek Prayer',
            title: 'Prayer Meeting',
            subtitle: 'Join the church family tonight for prayer, testimony, and encouragement on Zoom.',
            primaryLabel: 'Join Prayer Meeting',
            primaryIcon: Icons.videocam,
            primaryAction: () => openUrl(context, _wednesdayPrayerZoomUrl),
            secondaryLabel: 'Online Meetings',
            secondaryAction: () => openUrl(context, _wednesdayPrayerZoomUrl),
          )
        : isSabbath
            ? _HeroContent(
                metaLabel: 'Sabbath',
                metaDate: _sabbathLabel(),
                pill: 'Downsview SDA',
                title: 'Sabbath Worship',
                subtitle: sermon == null
                    ? 'Worship, Sabbath School, and the bulletin are ready for today.'
                    : sermonIsUpcoming
                        ? 'Prepare for "${sermon!.title}"${sermon!.speaker == null ? '' : ' with ${sermon!.speaker}'} and stay ready for worship today.'
                        : 'Reflect on "${sermon!.title}"${sermon!.speaker == null ? '' : ' with ${sermon!.speaker}'} and stay ready for worship today.',
                primaryLabel: showLiveStream ? 'Watch Live' : sermonIsUpcoming ? 'View Details' : 'Watch Sermon',
                primaryIcon: showLiveStream ? Icons.radio : Icons.play_arrow,
                primaryAction: () => openUrl(context, showLiveStream ? _liveStreamUrl : sermon?.url),
                secondaryLabel: 'View Details',
                secondaryAction: () => openUrl(context, 'https://downsviewsda.org/sermons/'),
              )
            : _HeroContent(
                metaLabel: 'Today',
                metaDate: _sabbathLabel(),
                pill: 'Downsview SDA',
                title: sermonIsUpcoming ? 'Upcoming Sabbath' : 'Today',
                subtitle: sermon == null
                    ? 'A simple dashboard for study, worship, and your next church moment.'
                    : sermonIsUpcoming
                        ? 'Prepare for "${sermon!.title}"${sermon!.speaker == null ? '' : ' with ${sermon!.speaker}'} this Sabbath.'
                        : 'Reflect on "${sermon!.title}"${sermon!.speaker == null ? '' : ' with ${sermon!.speaker}'} and stay ready for your next church moment.',
                primaryLabel: sermonIsUpcoming ? 'View Details' : 'Watch Sermon',
                primaryIcon: Icons.play_arrow,
                primaryAction: () => openUrl(context, sermon?.url),
                secondaryLabel: 'View Details',
                secondaryAction: () => openUrl(context, 'https://downsviewsda.org/sermons/'),
              );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.hero),
      child: Stack(
        children: [
          Image.asset('assets/Downsview Church Photo.jpg', height: heroHeight, width: double.infinity, fit: BoxFit.cover),
          Container(
            height: heroHeight,
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(color: Color(0xC2051434)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Image.asset('assets/downsview-logo-white.png', width: 246, height: 84, fit: BoxFit.contain),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(isWednesday ? Icons.videocam : Icons.calendar_month, color: AppColors.gold, size: 16),
                    const SizedBox(width: 8),
                    Text(content.metaLabel, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    const Text('|', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    Flexible(child: Text(content.metaDate, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800))),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
                  decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(AppRadii.pill)),
                  child: Text(content.pill.toUpperCase(), style: const TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 14),
                Text(content.title, style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w900, height: 1)),
                const SizedBox(height: 10),
                Text(content.subtitle, style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 17, height: 1.47)),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: content.primaryAction,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      ),
                      icon: Icon(content.primaryIcon, color: const Color(0xFFF59E0B), size: 17),
                      label: Text(content.primaryLabel),
                    ),
                    OutlinedButton.icon(
                      onPressed: content.secondaryAction,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0x7AFFFFFF)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      label: Text(content.secondaryLabel),
                      icon: const Icon(Icons.chevron_right, size: 17),
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

class _HeroContent {
  const _HeroContent({
    required this.metaLabel,
    required this.metaDate,
    required this.pill,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.primaryAction,
    required this.secondaryLabel,
    required this.secondaryAction,
  });

  final String metaLabel;
  final String metaDate;
  final String pill;
  final String title;
  final String subtitle;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback primaryAction;
  final String secondaryLabel;
  final VoidCallback secondaryAction;
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.showLiveStream, required this.onLive, required this.onSermons, required this.onEvents, required this.onGive});

  final bool showLiveStream;
  final VoidCallback onLive;
  final VoidCallback onSermons;
  final VoidCallback onEvents;
  final VoidCallback onGive;

  @override
  Widget build(BuildContext context) {
    final actions = [
      if (showLiveStream) _QuickAction('Watch Live', 'Join us in real time', Icons.radio, AppColors.danger, onLive),
      _QuickAction('Sermons', 'Latest messages', Icons.mic, const Color(0xFFD97706), onSermons),
      _QuickAction('Events', "See what's coming up", Icons.calendar_month, AppColors.blue, onEvents),
      _QuickAction('Give', 'Support the mission', Icons.favorite, AppColors.success, onGive),
    ];
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final action = actions[index];
          return GestureDetector(
            onTap: action.onTap,
            child: Container(
              width: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 82,
                    color: action.tone,
                    alignment: Alignment.center,
                    child: Icon(action.icon, color: Colors.white, size: 28),
                  ),
                  Expanded(
                    child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                action.subtitle,
                                style: const TextStyle(color: AppColors.muted, fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.muted, size: 16),
                          ],
                        ),
                      ],
                    ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction(this.title, this.subtitle, this.icon, this.tone, this.onTap);
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tone;
  final VoidCallback onTap;
}

class _ZoomGrid extends StatelessWidget {
  const _ZoomGrid({required this.onPrayer, required this.onKabs});

  final VoidCallback onPrayer;
  final VoidCallback onKabs;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ZoomCard(title: 'Prayer Meeting', subtitle: 'Wednesdays at 7 PM', icon: Icons.videocam, onTap: onPrayer),
        const SizedBox(height: 10),
        _ZoomCard(title: 'KABs', subtitle: 'Open the KABs Zoom room', icon: Icons.people, onTap: onKabs),
      ],
    );
  }
}

class _ZoomCard extends StatelessWidget {
  const _ZoomCard({required this.title, required this.subtitle, required this.icon, required this.onTap});

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ParityPanel(
      radius: 16,
      shadow: false,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: AppColors.lightBlue, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: AppColors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              ],
            ),
          ),
          const Icon(Icons.open_in_new, color: AppColors.muted, size: 20),
        ],
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.lesson, required this.onTap});

  final SabbathLesson lesson;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFEEF2F7)))),
        child: Row(
          children: [
            Container(
              width: 78,
              constraints: const BoxConstraints(minHeight: 64),
              decoration: BoxDecoration(color: _colorFromHex(lesson.color), borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: -18,
                    right: -18,
                    child: Container(width: 48, height: 48, decoration: BoxDecoration(color: _colorFromHex(lesson.accentColor), shape: BoxShape.circle)),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(lesson.ageGroup.characters.first, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                      Text(lesson.ageGroup, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lesson.title, style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text([lesson.dateLabel, lesson.summary].whereType<String>().join(' | '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.45)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _NextBanner extends StatelessWidget {
  const _NextBanner({required this.event, required this.onTap});

  final ChurchEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Stack(
          children: [
            if (event.imageUrl != null)
              Image.network(event.imageUrl!, height: 136, width: double.infinity, fit: BoxFit.cover)
            else
              Container(height: 136, color: AppColors.navy),
            Container(height: 136, color: const Color(0xAD102A43)),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Next Up', style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(event.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1.35)),
                  const SizedBox(height: 8),
                  Text([event.dateLabel, event.timeLabel].whereType<String>().join(' | '), style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventSheet extends StatelessWidget {
  const _EventSheet({required this.event, required this.onClose, required this.onOpen, required this.onCalendar, required this.onReminder});

  final ChurchEvent event;
  final VoidCallback onClose;
  final VoidCallback onOpen;
  final VoidCallback onCalendar;
  final VoidCallback onReminder;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0x85102A43),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.panel)),
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
                  const Align(child: StatusPill(text: 'Closed', background: Color(0xFFFEF3C7), color: Color(0xFFB45309))),
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

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good Morning,';
  if (hour < 18) return 'Good Afternoon,';
  return 'Good Evening,';
}

String _sabbathLabel() {
  final now = DateTime.now();
  final saturday = now.add(Duration(days: (DateTime.saturday - now.weekday + 7) % 7));
  return DateFormat('MMM d, yyyy').format(saturday);
}

String? _formatSermonDate(DateTime? date) {
  if (date == null) return null;
  final sameYear = date.year == DateTime.now().year;
  return DateFormat(sameYear ? 'MMM d' : 'MMM d, yyyy').format(date);
}

String? _homeDayContext() {
  final now = DateTime.now();
  final sunset = _sunsetTime(now);
  final sunsetLabel = DateFormat('h:mm a').format(sunset);

  if (now.weekday == DateTime.thursday) {
    return 'Preparation Day begins | Sabbath sunset tomorrow';
  }
  if (now.weekday == DateTime.friday) {
    return now.isBefore(sunset) ? 'Preparation Day | Sunset $sunsetLabel' : 'Sabbath has begun | Sunset was $sunsetLabel';
  }
  if (now.weekday == DateTime.saturday) {
    return 'Sabbath | Sunset $sunsetLabel';
  }
  return null;
}

bool _isSabbathTime() {
  final now = DateTime.now();
  if (now.weekday == DateTime.friday) return now.isAfter(_sunsetTime(now));
  if (now.weekday == DateTime.saturday) return now.isBefore(_sunsetTime(now));
  return false;
}

bool _isLiveStreamWindow() {
  final now = DateTime.now();
  final minutes = now.hour * 60 + now.minute;
  return (now.weekday == DateTime.saturday && minutes >= 11 * 60 && minutes < 14 * 60) ||
      (now.weekday == DateTime.wednesday && minutes >= 19 * 60 && minutes < 20 * 60);
}

DateTime _sunsetTime(DateTime date) {
  final dayOfYear = int.parse(DateFormat('D').format(date));
  final gamma = (2 * pi / 365) * (dayOfYear - 1);
  final equationOfTime = 229.18 *
      (0.000075 +
          0.001868 * cos(gamma) -
          0.032077 * sin(gamma) -
          0.014615 * cos(2 * gamma) -
          0.040849 * sin(2 * gamma));
  final declination = 0.006918 -
      0.399912 * cos(gamma) +
      0.070257 * sin(gamma) -
      0.006758 * cos(2 * gamma) +
      0.000907 * sin(2 * gamma) -
      0.002697 * cos(3 * gamma) +
      0.00148 * sin(3 * gamma);
  final latitude = _radians(_churchLatitude);
  final sunsetHourAngle = acos(cos(_radians(90.833)) / (cos(latitude) * cos(declination)) - tan(latitude) * tan(declination));
  final sunsetUtcMinutes = 720 - 4 * _churchLongitude - equationOfTime + (sunsetHourAngle * 180 / pi) * 4;
  final utcMidnight = DateTime.utc(date.year, date.month, date.day);
  return utcMidnight.add(Duration(minutes: sunsetUtcMinutes.round())).toLocal();
}

double _radians(double degrees) => degrees * pi / 180;

Color _colorFromHex(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  return Color(int.parse('FF$cleaned', radix: 16));
}
