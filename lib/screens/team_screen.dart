import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/member_models.dart';
import '../services/supabase_service.dart';
import '../theme.dart';

const _roleOptions = [
  _RoleOption('Member', 'member'),
  _RoleOption('Pastor', 'pastor'),
  _RoleOption('Interest', 'interest_coordinator'),
  _RoleOption('Property', 'property_manager'),
  _RoleOption('Social', 'social_media'),
  _RoleOption('Security', 'security'),
  _RoleOption('Prayer', 'prayer_team'),
  _RoleOption('Clerk', 'clerk'),
  _RoleOption('Staff', 'staff'),
  _RoleOption('Admin', 'admin'),
];

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  List<FollowUpResponse> _followUps = const [];
  List<AttendanceLog> _attendance = const [];
  List<MemberProfile> _members = const [];
  List<_PushMessage> _messages = const [];
  List<_DirectoryUser> _directoryUsers = const [];
  List<_FollowUpActivity> _activities = const [];
  List<_AuditLog> _auditLogs = const [];

  FollowUpResponse? _selectedFollowUp;
  MemberProfile? _selectedMember;
  RealtimeChannel? _channel;

  final _memberSearch = TextEditingController();
  final _roleSearch = TextEditingController();
  final _pushTitle = TextEditingController();
  final _pushBody = TextEditingController();
  final _pushSchedule = TextEditingController();
  final _followUpNotes = TextEditingController();
  final _activityNote = TextEditingController();
  final _nextActionDate = TextEditingController();

  bool _loading = true;
  bool _showAllFollowUps = false;
  bool _showAllDeliveryLog = false;
  bool _showActivityLog = false;
  bool _showAuditLog = false;
  bool _sendingPush = false;
  String? _updatingRoleId;
  String? _setupMessage;
  DateTime? _lastWebsiteSync;

  @override
  void initState() {
    super.initState();
    _memberSearch.addListener(_refresh);
    _roleSearch.addListener(_refresh);
    _load();
    _subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _memberSearch.dispose();
    _roleSearch.dispose();
    _pushTitle.dispose();
    _pushBody.dispose();
    _pushSchedule.dispose();
    _followUpNotes.dispose();
    _activityNote.dispose();
    _nextActionDate.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _subscribe() {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    _channel = supabase.channel('team-screen-${user.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'appeal_responses',
        callback: (_) => _load(quiet: true),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'attendance_logs',
        callback: (_) => _load(quiet: true),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'profiles',
        callback: (_) => _load(quiet: true),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'push_notification_messages',
        callback: (_) => _load(quiet: true),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'follow_up_activity',
        callback: (_) => _load(quiet: true),
      )
      ..subscribe();
  }

  Future<void> _load({bool quiet = false}) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (!quiet) setState(() => _loading = true);
    setState(() => _setupMessage = null);

    final canPastoral = _canPastoral(user);
    final canAttendance = _canAttendance(user);
    final canPush = _canPush(user);
    final canAdmin = _canAdmin(user);

    try {
      final results = await Future.wait<dynamic>([
        canPastoral
            ? supabase
                .from('appeal_responses')
                .select('id,user_id,requester_name,requester_email,response_data,follow_up_status,follow_up_notes,assigned_to_name,interest_type,contacted_by_name,contacted_at,follow_up_next_action_at,created_at')
                .neq('follow_up_status', 'closed')
                .order('created_at', ascending: false)
                .limit(30)
            : Future.value([]),
        canAttendance
            ? supabase
                .from('attendance_logs')
                .select('id,user_id,user_name,user_email,device_id,timestamp')
                .order('timestamp', ascending: false)
                .limit(200)
            : Future.value([]),
        canPastoral
            ? supabase
                .from('profiles')
                .select('id,email,full_name,phone,preferred_contact_method,ministry_interest,household_notes,birthday,avatar_url')
                .order('full_name', ascending: true)
                .limit(100)
            : Future.value([]),
        canPush
            ? supabase
                .from('push_notification_messages')
                .select('id,title,body,status,sent_by_name,delivered_count,failed_count,error_message,created_at,scheduled_at,sent_at')
                .order('created_at', ascending: false)
                .limit(20)
            : Future.value([]),
        canPastoral
            ? supabase
                .from('follow_up_activity')
                .select('id,response_id,actor_name,activity_type,note,created_at')
                .order('created_at', ascending: false)
                .limit(120)
            : Future.value([]),
        canAdmin
            ? supabase
                .from('app_audit_log')
                .select('id,actor_name,action,target_type,created_at')
                .order('created_at', ascending: false)
                .limit(20)
            : Future.value([]),
      ]);

      List<_DirectoryUser> directory = const [];
      if (canAdmin) {
        final data = await supabase.rpc('get_app_user_directory');
        directory = (data as List)
            .map((item) => _DirectoryUser.fromMap(item as Map<String, dynamic>))
            .toList();
      }

      if (!mounted) return;
      setState(() {
        _followUps = (results[0] as List)
            .map((item) => FollowUpResponse.fromMap(item as Map<String, dynamic>))
            .toList();
        _attendance = (results[1] as List)
            .map((item) => AttendanceLog.fromMap(item as Map<String, dynamic>))
            .toList();
        _members = (results[2] as List)
            .map((item) => MemberProfile.fromMap(item as Map<String, dynamic>))
            .toList();
        _messages = (results[3] as List)
            .map((item) => _PushMessage.fromMap(item as Map<String, dynamic>))
            .toList();
        _activities = (results[4] as List)
            .map((item) => _FollowUpActivity.fromMap(item as Map<String, dynamic>))
            .toList();
        _auditLogs = (results[5] as List)
            .map((item) => _AuditLog.fromMap(item as Map<String, dynamic>))
            .toList();
        _directoryUsers = directory;
        _lastWebsiteSync = DateTime.now();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _setupMessage = '$error. Run the latest Supabase schema/patch, then reload.';
        _loading = false;
      });
    }
  }

  Future<void> _updateFollowUp(String responseId, Map<String, dynamic> updates) async {
    try {
      await supabase
          .from('appeal_responses')
          .update({...updates, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', responseId);
      await _recordActivity(responseId, 'updated', updates.keys.join(', '));
      await _load(quiet: true);
      _syncSelectedFollowUp(responseId);
    } catch (error) {
      _showSnack('Could not update: $error');
    }
  }

  Future<void> _recordActivity(String responseId, String activityType, String? note) async {
    final user = supabase.auth.currentUser;
    await supabase.from('follow_up_activity').insert({
      'response_id': responseId,
      'actor_id': user?.id,
      'actor_name': _userName(user, fallback: 'Team Member'),
      'activity_type': activityType,
      'note': note,
    });
  }

  Future<void> _assignToMe(FollowUpResponse response) async {
    final user = supabase.auth.currentUser;
    await _updateFollowUp(response.id, {
      'assigned_to_id': user?.id,
      'assigned_to_name': _userName(user, fallback: 'Team Member'),
      'follow_up_status': 'assigned',
    });
    await _recordActivity(response.id, 'assigned', 'Assigned to ${_userName(user, fallback: 'Team Member')}');
  }

  Future<void> _markContacted(FollowUpResponse response) async {
    final user = supabase.auth.currentUser;
    await _updateFollowUp(response.id, {
      'follow_up_status': 'contacted',
      'contacted_by_id': user?.id,
      'contacted_by_name': _userName(user, fallback: 'Team Member'),
      'contacted_at': DateTime.now().toIso8601String(),
    });
    await _recordActivity(response.id, 'contacted', 'Marked as contacted');
  }

  Future<void> _saveFollowUpDetail() async {
    final response = _selectedFollowUp;
    if (response == null) return;
    await _updateFollowUp(response.id, {
      'follow_up_notes': _followUpNotes.text.trim().isEmpty ? null : _followUpNotes.text.trim(),
      'follow_up_next_action_at': _nextActionDate.text.trim().isEmpty
          ? null
          : '${_nextActionDate.text.trim()}T12:00:00.000Z',
    });
    if (_activityNote.text.trim().isNotEmpty) {
      await _recordActivity(response.id, 'note', _activityNote.text.trim());
    }
    if (!mounted) return;
    setState(() => _selectedFollowUp = null);
  }

  Future<void> _queuePush() async {
    if (_pushTitle.text.trim().isEmpty || _pushBody.text.trim().isEmpty) {
      _showSnack('Add both a title and message.');
      return;
    }
    final user = supabase.auth.currentUser;
    setState(() => _sendingPush = true);
    try {
      await supabase.from('push_notification_messages').insert({
        'title': _pushTitle.text.trim(),
        'body': _pushBody.text.trim(),
        'sent_by_id': user?.id,
        'sent_by_name': _userName(user, fallback: 'Church Team'),
        'status': 'queued',
        'scheduled_at': _pushSchedule.text.trim().isEmpty
            ? null
            : '${_pushSchedule.text.trim()}T12:00:00.000Z',
      });
      final invokeNow = _pushSchedule.text.trim().isEmpty;
      if (invokeNow) {
        await supabase.functions.invoke('send-push-notifications');
      }
      _pushTitle.clear();
      _pushBody.clear();
      _pushSchedule.clear();
      await _load(quiet: true);
      _showSnack(invokeNow ? 'The sender processed the message.' : 'Notification scheduled.');
    } catch (error) {
      _showSnack('Could not send: $error');
    } finally {
      if (mounted) setState(() => _sendingPush = false);
    }
  }

  Future<void> _setUserRole(_DirectoryUser targetUser, String role) async {
    setState(() => _updatingRoleId = targetUser.id);
    final currentRoles = targetUser.activeRoles;
    final nextRoles = role == 'member'
        ? <String>[]
        : currentRoles.contains(role)
            ? currentRoles.where((currentRole) => currentRole != role).toList()
            : [...currentRoles, role];
    try {
      await supabase.rpc(
        'set_user_roles',
        params: {'target_user_id': targetUser.id, 'new_roles': nextRoles},
      );
      setState(() {
        _directoryUsers = _directoryUsers
            .map((item) => item.id == targetUser.id
                ? item.copyWith(role: nextRoles.isEmpty ? null : nextRoles.first, roles: nextRoles)
                : item)
            .toList();
      });
    } catch (error) {
      _showSnack('Could not update role: $error');
    } finally {
      if (mounted) setState(() => _updatingRoleId = null);
    }
  }

  Future<void> _exportAttendance() async {
    final csv = [
      'Name,Email,Device,Timestamp',
      ..._attendance.map((log) => [
            log.userName ?? '',
            log.userEmail ?? '',
            log.deviceId ?? '',
            log.timestamp.toIso8601String(),
          ].map((value) => '"${value.replaceAll('"', '""')}"').join(',')),
    ].join('\n');
    await SharePlus.instance.share(ShareParams(text: csv, subject: 'Attendance Export'));
  }

  void _openFollowUp(FollowUpResponse response) {
    setState(() {
      _selectedFollowUp = response;
      _showActivityLog = false;
      _followUpNotes.text = response.followUpNotes ?? '';
      _nextActionDate.text = response.followUpNextActionAt == null
          ? ''
          : _dateInput(response.followUpNextActionAt!);
      _activityNote.clear();
    });
  }

  void _syncSelectedFollowUp(String responseId) {
    final match = _followUps.where((item) => item.id == responseId).firstOrNull;
    if (match != null && mounted) setState(() => _selectedFollowUp = match);
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final canPastoral = _canPastoral(user);
    final canAttendance = _canAttendance(user);
    final canPush = _canPush(user);
    final canAdmin = _canAdmin(user);
    final stats = _attendanceStats();
    final visibleFollowUps = _showAllFollowUps ? _followUps : _followUps.take(6).toList();
    final visibleMessages = _showAllDeliveryLog ? _messages : _messages.take(5).toList();
    final filteredMembers = _filteredMembers();
    final filteredDirectoryUsers = _filteredDirectoryUsers();
    final selectedActivities =
        _activities.where((activity) => activity.responseId == _selectedFollowUp?.id).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                key: const PageStorageKey('team-scroll'),
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 48),
                children: [
                  const _TeamHeader(),
                  if (_setupMessage != null) ...[
                    const SizedBox(height: 12),
                    _SetupBox(message: _setupMessage!),
                  ],
                  if (_loading) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                  const SizedBox(height: 18),
                  _SyncCard(lastSync: _lastWebsiteSync, onRefresh: () => _load()),
                  if (canAttendance) ...[
                    const SizedBox(height: 12),
                    _AttendanceAnalytics(stats: stats, onExport: _exportAttendance),
                  ],
                  if (canPastoral) ...[
                    const SizedBox(height: 14),
                    _FollowUpPanel(
                      followUps: _followUps,
                      visibleFollowUps: visibleFollowUps,
                      members: _members,
                      showAll: _showAllFollowUps,
                      onToggle: () => setState(() => _showAllFollowUps = !_showAllFollowUps),
                      onOpen: _openFollowUp,
                    ),
                  ],
                  if (canPastoral) ...[
                    const SizedBox(height: 14),
                    _MemberDirectoryPanel(
                      controller: _memberSearch,
                      members: filteredMembers.take(4).toList(),
                      onOpen: (member) => setState(() => _selectedMember = member),
                    ),
                  ],
                  if (canPush) ...[
                    const SizedBox(height: 14),
                    _NotificationsPanel(
                      title: _pushTitle,
                      body: _pushBody,
                      schedule: _pushSchedule,
                      sending: _sendingPush,
                      onSend: _queuePush,
                    ),
                    const SizedBox(height: 14),
                    _DeliveryLogPanel(
                      messages: _messages,
                      visibleMessages: visibleMessages,
                      showAll: _showAllDeliveryLog,
                      onToggle: () => setState(() => _showAllDeliveryLog = !_showAllDeliveryLog),
                    ),
                  ],
                  if (canAdmin) ...[
                    const SizedBox(height: 14),
                    _AdminRolesPanel(
                      controller: _roleSearch,
                      users: filteredDirectoryUsers,
                      totalUsers: _directoryUsers.length,
                      updatingRoleId: _updatingRoleId,
                      onSetRole: _setUserRole,
                    ),
                    const SizedBox(height: 14),
                    _AuditLogPanel(
                      logs: _auditLogs,
                      show: _showAuditLog,
                      onToggle: () => setState(() => _showAuditLog = !_showAuditLog),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_selectedFollowUp != null)
            _FollowUpModal(
              response: _selectedFollowUp!,
              activities: selectedActivities,
              showActivityLog: _showActivityLog,
              followUpNotes: _followUpNotes,
              activityNote: _activityNote,
              nextActionDate: _nextActionDate,
              onClose: () => setState(() => _selectedFollowUp = null),
              onToggleActivity: () => setState(() => _showActivityLog = !_showActivityLog),
              onSave: _saveFollowUpDetail,
              onAssign: () => _assignToMe(_selectedFollowUp!),
              onContacted: () => _markContacted(_selectedFollowUp!),
              onInterest: (interest) => _updateFollowUp(_selectedFollowUp!.id, {'interest_type': interest}),
            ),
          if (_selectedMember != null)
            _MemberModal(
              member: _selectedMember!,
              onClose: () => setState(() => _selectedMember = null),
            ),
        ],
      ),
    );
  }

  Map<String, int> _attendanceStats() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = now.subtract(const Duration(days: 7));
    return {
      'today': _attendance.where((log) {
        final local = log.timestamp.toLocal();
        return DateTime(local.year, local.month, local.day) == today;
      }).length,
      'week': _attendance.where((log) => log.timestamp.isAfter(weekAgo)).length,
      'unique': _attendance
          .map((log) => log.userEmail ?? log.userId ?? log.deviceId ?? log.id)
          .toSet()
          .length,
    };
  }

  List<MemberProfile> _filteredMembers() {
    final query = _memberSearch.text.toLowerCase();
    return _members.where((member) {
      final haystack = [
        member.fullName,
        member.email,
        member.phone,
        member.ministryInterest,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  List<_DirectoryUser> _filteredDirectoryUsers() {
    final query = _roleSearch.text.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return _directoryUsers.where((directoryUser) {
      final roleLabels = directoryUser.activeRoles.map(_roleLabelForValue).join(' ');
      final haystack = [
        directoryUser.fullName,
        directoryUser.email,
        roleLabels,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TeamHeader extends StatelessWidget {
  const _TeamHeader();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final subtitleWidth = constraints.maxWidth < 520
            ? constraints.maxWidth - 145
            : 330.0;
        return SizedBox(
          height: 310,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/downsview-logo-black.png',
                    width: 230,
                    height: 70,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                  ),
                  const SizedBox(height: 26),
                  const Text(
                    'Team',
                    style: TextStyle(color: AppColors.blue, fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Church operations',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 36,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: subtitleWidth.clamp(210.0, 330.0),
                    child: const Text(
                      'Follow up, attendance, member care, member sync, notifications, and roles.',
                      style: TextStyle(color: AppColors.muted, fontSize: 17, height: 1.58),
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 0,
                bottom: 8,
                child: Opacity(
                  opacity: 0.52,
                  child: SizedBox(
                    width: 150,
                    height: 140,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 138,
                          height: 138,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                        ),
                        const Icon(Icons.groups, color: Color(0xFF3B82F6), size: 66),
                        const Positioned(
                          right: 20,
                          bottom: 26,
                          child: Icon(Icons.settings, color: Color(0xFF93C5FD), size: 40),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({required this.lastSync, required this.onRefresh});

  final DateTime? lastSync;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 170),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF082A52),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle),
            child: const Icon(Icons.sync, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Website Sync', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                    TextButton(
                      onPressed: onRefresh,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        foregroundColor: AppColors.paleBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                      child: const Text('Refresh', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const Text(
                  'News, sermons, and events are synced across the website and app.',
                  style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 14, height: 1.55, fontWeight: FontWeight.w700),
                ),
                Container(height: 1, color: Colors.white.withValues(alpha: 0.22), margin: const EdgeInsets.symmetric(vertical: 16)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Last sync: ${lastSync == null ? 'Just now' : _timeLabel(lastSync!)}',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    const Icon(Icons.check_circle, color: AppColors.success, size: 20),
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

class _AttendanceAnalytics extends StatelessWidget {
  const _AttendanceAnalytics({required this.stats, required this.onExport});

  final Map<String, int> stats;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      radius: 20,
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: Text('Attendance Analytics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
              _PillButton(label: 'Export', onPressed: onExport),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatCard(icon: Icons.groups, value: stats['today'] ?? 0, label: 'Today')),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(icon: Icons.calendar_month, value: stats['week'] ?? 0, label: '7 days')),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(icon: Icons.groups, value: stats['unique'] ?? 0, label: 'People')),
            ],
          ),
        ],
      ),
    );
  }
}

class _FollowUpPanel extends StatelessWidget {
  const _FollowUpPanel({
    required this.followUps,
    required this.visibleFollowUps,
    required this.members,
    required this.showAll,
    required this.onToggle,
    required this.onOpen,
  });

  final List<FollowUpResponse> followUps;
  final List<FollowUpResponse> visibleFollowUps;
  final List<MemberProfile> members;
  final bool showAll;
  final VoidCallback onToggle;
  final ValueChanged<FollowUpResponse> onOpen;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: [
          _PanelHeader(
            icon: Icons.groups,
            title: 'Pastoral Follow-Up',
            intro: showAll
                ? 'Showing ${followUps.length} open items'
                : 'Showing ${visibleFollowUps.length} of ${followUps.length} open items',
            trailing: followUps.length > 6
                ? _PillButton(label: showAll ? 'Show Less' : 'View All', onPressed: onToggle)
                : null,
          ),
          if (followUps.isEmpty)
            const _EmptyText('No open follow-up items.')
          else
            Column(
              children: [
                for (final response in visibleFollowUps)
                  _FollowUpRow(
                    response: response,
                    profile: _profileForFollowUp(response, members),
                    onTap: () => onOpen(response),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MemberDirectoryPanel extends StatelessWidget {
  const _MemberDirectoryPanel({
    required this.controller,
    required this.members,
    required this.onOpen,
  });

  final TextEditingController controller;
  final List<MemberProfile> members;
  final ValueChanged<MemberProfile> onOpen;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: [
          const _PanelHeader(icon: Icons.groups, title: 'Member Directory'),
          _SearchField(controller: controller, hint: 'Search members'),
          if (members.isEmpty)
            const _EmptyText('No members match that search.')
          else
            for (final member in members)
              _MemberRow(member: member, onTap: () => onOpen(member)),
        ],
      ),
    );
  }
}

class _NotificationsPanel extends StatelessWidget {
  const _NotificationsPanel({
    required this.title,
    required this.body,
    required this.schedule,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController title;
  final TextEditingController body;
  final TextEditingController schedule;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: [
          const _PanelHeader(icon: Icons.notifications, title: 'Notifications'),
          TextField(controller: title, decoration: const InputDecoration(hintText: 'Title')),
          const SizedBox(height: 12),
          TextField(
            controller: body,
            minLines: 4,
            maxLines: 6,
            decoration: const InputDecoration(hintText: 'Message'),
          ),
          const SizedBox(height: 12),
          TextField(controller: schedule, decoration: const InputDecoration(hintText: 'Optional send date: YYYY-MM-DD')),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: sending ? null : onSend,
            child: sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(schedule.text.trim().isEmpty ? 'Send Push' : 'Schedule Push'),
          ),
        ],
      ),
    );
  }
}

class _DeliveryLogPanel extends StatelessWidget {
  const _DeliveryLogPanel({
    required this.messages,
    required this.visibleMessages,
    required this.showAll,
    required this.onToggle,
  });

  final List<_PushMessage> messages;
  final List<_PushMessage> visibleMessages;
  final bool showAll;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: [
          _PanelHeader(
            icon: Icons.mail,
            title: 'Delivery Log',
            intro: showAll
                ? 'Showing ${messages.length} delivery items'
                : 'Showing ${visibleMessages.length} of ${messages.length} delivery items',
            trailing: messages.length > 5
                ? _PillButton(label: showAll ? 'Show Less' : 'View All', onPressed: onToggle)
                : null,
          ),
          if (messages.isEmpty)
            const _EmptyText('Queued and sent messages will appear here.')
          else
            for (final message in visibleMessages) _DeliveryRow(message: message),
        ],
      ),
    );
  }
}

class _AdminRolesPanel extends StatelessWidget {
  const _AdminRolesPanel({
    required this.controller,
    required this.users,
    required this.totalUsers,
    required this.updatingRoleId,
    required this.onSetRole,
  });

  final TextEditingController controller;
  final List<_DirectoryUser> users;
  final int totalUsers;
  final String? updatingRoleId;
  final void Function(_DirectoryUser user, String role) onSetRole;

  @override
  Widget build(BuildContext context) {
    final hasSearch = controller.text.trim().isNotEmpty;
    return _Panel(
      child: Column(
        children: [
          _PanelHeader(
            icon: Icons.verified_user,
            title: 'Admin Roles',
            intro: hasSearch ? '${users.length} of $totalUsers users shown' : 'Search $totalUsers users to edit roles',
          ),
          _SearchField(controller: controller, hint: 'Search by name, email, or role'),
          if (!hasSearch)
            const _EmptyText('Start typing a name, email, or role to show matching users.')
          else if (users.isEmpty)
            const _EmptyText('No users match that search.')
          else
            for (final user in users)
              _AdminRoleRow(
                user: user,
                disabled: updatingRoleId == user.id,
                onSetRole: (role) => onSetRole(user, role),
              ),
        ],
      ),
    );
  }
}

class _AuditLogPanel extends StatelessWidget {
  const _AuditLogPanel({required this.logs, required this.show, required this.onToggle});

  final List<_AuditLog> logs;
  final bool show;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onToggle,
            child: _PanelHeader(
              icon: Icons.description,
              title: 'Audit Log',
              intro: show ? 'Showing recent sensitive app actions' : '${logs.length} recent actions hidden',
              trailing: Icon(show ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.muted),
            ),
          ),
          if (show)
            if (logs.isEmpty)
              const _EmptyText('Sensitive app actions will appear here.')
            else
              for (final log in logs)
                _DividerRow(
                  title: log.action,
                  meta: '${log.actorName ?? 'System'} | ${log.targetType ?? 'app'} | ${_dateTimeLabel(log.createdAt)}',
                ),
        ],
      ),
    );
  }
}

class _FollowUpModal extends StatelessWidget {
  const _FollowUpModal({
    required this.response,
    required this.activities,
    required this.showActivityLog,
    required this.followUpNotes,
    required this.activityNote,
    required this.nextActionDate,
    required this.onClose,
    required this.onToggleActivity,
    required this.onSave,
    required this.onAssign,
    required this.onContacted,
    required this.onInterest,
  });

  final FollowUpResponse response;
  final List<_FollowUpActivity> activities;
  final bool showActivityLog;
  final TextEditingController followUpNotes;
  final TextEditingController activityNote;
  final TextEditingController nextActionDate;
  final VoidCallback onClose;
  final VoidCallback onToggleActivity;
  final VoidCallback onSave;
  final VoidCallback onAssign;
  final VoidCallback onContacted;
  final ValueChanged<String> onInterest;

  @override
  Widget build(BuildContext context) {
    return _ModalShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(response.requesterName ?? 'Follow-Up', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          if (response.requesterEmail != null) ...[
            const SizedBox(height: 4),
            Text(response.requesterEmail!, style: _metaStyle),
          ],
          const SizedBox(height: 8),
          Text(response.responseData, style: _bodyStyle),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final interest in const ['prayer', 'visit', 'bible_study', 'baptism'])
                _RoleChip(label: interest.replaceAll('_', ' '), active: response.interestType == interest, onTap: () => onInterest(interest)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(controller: followUpNotes, minLines: 4, maxLines: 6, decoration: const InputDecoration(hintText: 'Follow-up notes')),
          const SizedBox(height: 12),
          TextField(controller: activityNote, minLines: 4, maxLines: 6, decoration: const InputDecoration(hintText: 'Add timeline note')),
          const SizedBox(height: 12),
          TextField(controller: nextActionDate, decoration: const InputDecoration(hintText: 'Next action date: YYYY-MM-DD')),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onToggleActivity,
            child: _PanelHeader(
              icon: Icons.schedule,
              title: 'Activity Log',
              intro: showActivityLog ? 'Showing follow-up timeline' : '${activities.length} timeline items hidden',
              trailing: Icon(showActivityLog ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.muted),
            ),
          ),
          if (showActivityLog)
            if (activities.isEmpty)
              const _EmptyText('No timeline activity yet.')
            else
              for (final activity in activities)
                _TimelineItem(activity: activity),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _SecondaryButton(label: 'Assign Me', onPressed: onAssign)),
              const SizedBox(width: 10),
              Expanded(child: _SecondaryButton(label: 'Contacted', onPressed: onContacted)),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton(onPressed: onSave, child: const Text('Save Detail')),
          TextButton(
            onPressed: onClose,
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: AppColors.muted),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _MemberModal extends StatelessWidget {
  const _MemberModal({required this.member, required this.onClose});

  final MemberProfile member;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return _ModalShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(name: member.fullName, email: member.email, imageUrl: member.avatarUrl, size: 68),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.fullName ?? member.email ?? 'Member',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    if (member.email != null) Text(member.email!, style: _metaStyle),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DetailLine(icon: Icons.mail_outline, text: member.email ?? 'No email saved'),
          _DetailLine(icon: Icons.call_outlined, text: member.phone ?? 'No phone saved'),
          _DetailLine(icon: Icons.favorite_border, text: member.ministryInterest ?? 'No ministry interest saved'),
          _DetailLine(icon: Icons.chat_bubble_outline, text: member.preferredContactMethod ?? 'No contact preference saved'),
          _DetailLine(icon: Icons.description_outlined, text: member.householdNotes ?? 'No household notes saved', tall: true),
          _DetailLine(icon: Icons.calendar_month_outlined, text: member.birthday ?? 'No birthday saved'),
          TextButton(
            onPressed: onClose,
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: AppColors.muted),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _ModalShell extends StatelessWidget {
  const _ModalShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.text.withValues(alpha: 0.52),
      padding: const EdgeInsets.all(18),
      child: Center(
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.radius = 22});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.panel,
      ),
      child: child,
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.icon, required this.title, this.intro, this.trailing});

  final IconData icon;
  final String title;
  final String? intro;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          _LightIcon(icon: icon),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                if (intro != null)
                  Text(intro!, style: const TextStyle(color: AppColors.muted, fontSize: 14, height: 1.4)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _LightIcon extends StatelessWidget {
  const _LightIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      margin: const EdgeInsets.only(right: 10),
      decoration: const BoxDecoration(color: AppColors.lightBlue, shape: BoxShape.circle),
      child: Icon(icon, color: AppColors.blue, size: 23),
    );
  }
}

class _FollowUpRow extends StatelessWidget {
  const _FollowUpRow({required this.response, required this.profile, required this.onTap});

  final FollowUpResponse response;
  final MemberProfile? profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 74),
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: response.followUpStatus == 'contacted' ? const Color(0xFFD1FAE5) : AppColors.lightBlue,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                response.followUpStatus,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: response.followUpStatus == 'contacted' ? AppColors.success : AppColors.blue,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _Avatar(
              name: response.requesterName,
              email: response.requesterEmail,
              imageUrl: profile?.avatarUrl,
              size: 44,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    response.requesterName ?? response.requesterEmail ?? 'Unknown requester',
                    style: _titleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _responsePreview(response.responseData).isEmpty
                        ? response.requesterEmail ?? 'No message preview'
                        : _responsePreview(response.responseData),
                    style: _bodyStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text('Assigned: ${response.assignedToName ?? 'Unassigned'}', style: _smallMetaStyle),
                  Text('Interest: ${response.interestType?.replaceAll('_', ' ') ?? 'Not set'}', style: _smallMetaStyle),
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

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.onTap});

  final MemberProfile member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            _Avatar(name: member.fullName, email: member.email, imageUrl: member.avatarUrl, size: 54),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.fullName ?? member.email ?? 'Member', style: _titleStyle),
                  if (member.email != null) Text(member.email!, style: _metaStyle),
                  if (member.phone != null) Text(member.phone!, style: _metaStyle),
                  if (member.ministryInterest != null) Text(member.ministryInterest!, style: _metaStyle),
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

class _DeliveryRow extends StatelessWidget {
  const _DeliveryRow({required this.message});

  final _PushMessage message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFEEF2F7)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 6, right: 14), decoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.title, style: _titleStyle),
                Text(message.body, style: _bodyStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          SizedBox(
            width: 104,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${message.status} | Delivered', style: _smallMetaStyle),
                Text(_compactDateTime(message.sentAt ?? message.createdAt), style: _smallMetaStyle),
                if (message.errorMessage != null)
                  Text(message.errorMessage!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminRoleRow extends StatelessWidget {
  const _AdminRoleRow({required this.user, required this.disabled, required this.onSetRole});

  final _DirectoryUser user;
  final bool disabled;
  final ValueChanged<String> onSetRole;

  @override
  Widget build(BuildContext context) {
    final activeRoles = user.activeRoles;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFEEF2F7)))),
      child: Column(
        children: [
          Row(
            children: [
              _Avatar(name: user.fullName, email: user.email, size: 54),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName ?? user.email ?? 'User', style: _titleStyle),
                    if (user.email != null) Text(user.email!, style: _metaStyle),
                  ],
                ),
              ),
              Container(
                constraints: const BoxConstraints(maxWidth: 120),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(color: AppColors.lightBlue, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  _roleLabelForUser(user),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 66),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RoleChip(label: 'Member', active: activeRoles.isEmpty, disabled: disabled, onTap: () => onSetRole('member')),
                for (final role in _roleOptions.where((role) => role.value != 'member'))
                  _RoleChip(
                    label: role.label,
                    active: activeRoles.contains(role.value),
                    disabled: disabled,
                    onTap: () => onSetRole(role.value),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.activity});

  final _FollowUpActivity activity;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(activity.activityType, style: _titleStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (activity.note != null) Text(activity.note!, style: _bodyStyle),
          Text('${activity.actorName ?? 'Team'} | ${_dateTimeLabel(activity.createdAt)}', style: _metaStyle),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.name, this.email, this.imageUrl, required this.size});

  final String? name;
  final String? email;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _AvatarFallback(name: name, email: email, size: size),
        ),
      );
    }
    return _AvatarFallback(name: name, email: email, size: size);
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({this.name, this.email, required this.size});

  final String? name;
  final String? email;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: AppColors.paleBlue, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(_initials(name, email), style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w900)),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      margin: const EdgeInsets.symmetric(vertical: 14),
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.muted, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
              style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.value, required this.label});

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.blue, size: 23),
          Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.text, this.tall = false});

  final IconData icon;
  final String text;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: tall ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.blue, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.45, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}

class _DividerRow extends StatelessWidget {
  const _DividerRow({required this.title, required this.meta});

  final String title;
  final String meta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFEEF2F7)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _titleStyle),
          Text(meta, style: _metaStyle),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label, required this.active, required this.onTap, this.disabled = false});

  final String label;
  final bool active;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.text : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? AppColors.text : AppColors.inputBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppColors.slate,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: AppColors.lightBlue,
        foregroundColor: AppColors.blue,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: AppColors.lightBlue,
        foregroundColor: AppColors.blue,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
    );
  }
}

class _SetupBox extends StatelessWidget {
  const _SetupBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(16)),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF9A3412), fontWeight: FontWeight.w800, height: 1.45),
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 14, height: 1.5)),
    );
  }
}

class _RoleOption {
  const _RoleOption(this.label, this.value);

  final String label;
  final String value;
}

class _PushMessage {
  const _PushMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.status,
    required this.createdAt,
    this.sentByName,
    this.deliveredCount,
    this.failedCount,
    this.errorMessage,
    this.scheduledAt,
    this.sentAt,
  });

  final String id;
  final String title;
  final String body;
  final String status;
  final String? sentByName;
  final int? deliveredCount;
  final int? failedCount;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? scheduledAt;
  final DateTime? sentAt;

  factory _PushMessage.fromMap(Map<String, dynamic> map) => _PushMessage(
        id: (map['id'] ?? '').toString(),
        title: (map['title'] ?? 'Message').toString(),
        body: (map['body'] ?? '').toString(),
        status: (map['status'] ?? 'queued').toString(),
        sentByName: map['sent_by_name'] as String?,
        deliveredCount: map['delivered_count'] as int?,
        failedCount: map['failed_count'] as int?,
        errorMessage: map['error_message'] as String?,
        createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ?? DateTime.now(),
        scheduledAt: DateTime.tryParse((map['scheduled_at'] ?? '').toString()),
        sentAt: DateTime.tryParse((map['sent_at'] ?? '').toString()),
      );
}

class _DirectoryUser {
  const _DirectoryUser({
    required this.id,
    this.email,
    this.fullName,
    this.role,
    this.roles,
  });

  final String id;
  final String? email;
  final String? fullName;
  final String? role;
  final List<String>? roles;

  List<String> get activeRoles => roles?.isNotEmpty == true ? roles! : role == null ? const [] : [role!];

  _DirectoryUser copyWith({String? role, List<String>? roles}) {
    return _DirectoryUser(id: id, email: email, fullName: fullName, role: role, roles: roles);
  }

  factory _DirectoryUser.fromMap(Map<String, dynamic> map) => _DirectoryUser(
        id: (map['id'] ?? '').toString(),
        email: map['email'] as String?,
        fullName: map['full_name'] as String?,
        role: map['role'] as String?,
        roles: map['roles'] is List ? (map['roles'] as List).whereType<String>().toList() : null,
      );
}

class _FollowUpActivity {
  const _FollowUpActivity({
    required this.id,
    required this.responseId,
    required this.activityType,
    required this.createdAt,
    this.actorName,
    this.note,
  });

  final String id;
  final String responseId;
  final String? actorName;
  final String activityType;
  final String? note;
  final DateTime createdAt;

  factory _FollowUpActivity.fromMap(Map<String, dynamic> map) => _FollowUpActivity(
        id: (map['id'] ?? '').toString(),
        responseId: (map['response_id'] ?? '').toString(),
        actorName: map['actor_name'] as String?,
        activityType: (map['activity_type'] ?? '').toString(),
        note: map['note'] as String?,
        createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ?? DateTime.now(),
      );
}

class _AuditLog {
  const _AuditLog({
    required this.id,
    required this.action,
    required this.createdAt,
    this.actorName,
    this.targetType,
  });

  final String id;
  final String? actorName;
  final String action;
  final String? targetType;
  final DateTime createdAt;

  factory _AuditLog.fromMap(Map<String, dynamic> map) => _AuditLog(
        id: (map['id'] ?? '').toString(),
        actorName: map['actor_name'] as String?,
        action: (map['action'] ?? '').toString(),
        targetType: map['target_type'] as String?,
        createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ?? DateTime.now(),
      );
}

const _titleStyle = TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w900);
const _metaStyle = TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w800);
const _smallMetaStyle = TextStyle(color: AppColors.muted, fontSize: 11, height: 1.35, fontWeight: FontWeight.w800);
const _bodyStyle = TextStyle(color: AppColors.slate, fontSize: 13, height: 1.4, fontWeight: FontWeight.w700);

bool _canPastoral(User? user) => hasAnyRole(user, const ['admin', 'pastor', 'staff', 'interest_coordinator', 'coordinator', 'prayer_team']);
bool _canAttendance(User? user) => hasAnyRole(user, const ['admin', 'pastor', 'staff', 'property_manager', 'property', 'clerk']);
bool _canPush(User? user) => canSendPush(user);
bool _canAdmin(User? user) => hasAnyRole(user, const ['admin']);

String _userName(User? user, {required String fallback}) {
  return user?.userMetadata?['full_name'] as String? ?? user?.email ?? fallback;
}

String _initials(String? name, String? email) {
  final source = (name?.isNotEmpty == true ? name : email) ?? 'Member';
  final parts = source.replaceFirst(RegExp(r'@.+$'), '').split(RegExp(r'\s+|[._-]')).where((part) => part.isNotEmpty);
  final initials = parts.take(2).map((part) => part[0].toUpperCase()).join();
  return initials.isEmpty ? 'M' : initials;
}

String _responsePreview(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

MemberProfile? _profileForFollowUp(FollowUpResponse response, List<MemberProfile> members) {
  for (final member in members) {
    if (response.userId != null && member.id == response.userId) return member;
    if (response.requesterEmail != null &&
        member.email?.toLowerCase() == response.requesterEmail!.toLowerCase()) {
      return member;
    }
  }
  return null;
}

String _roleLabelForValue(String value) {
  return _roleOptions.where((role) => role.value == value).firstOrNull?.label ?? value.replaceAll('_', ' ');
}

String _roleLabelForUser(_DirectoryUser user) {
  final activeRoles = user.activeRoles;
  if (activeRoles.isEmpty) return 'Member';
  return _roleLabelForValue(activeRoles.first);
}

String _timeLabel(DateTime date) {
  final local = date.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

String _dateInput(DateTime date) {
  final local = date.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

String _dateTimeLabel(DateTime date) {
  final local = date.toLocal();
  return '${_month(local.month)} ${local.day}, ${local.year} ${_timeLabel(local)}';
}

String _compactDateTime(DateTime date) {
  final local = date.toLocal();
  return '${_month(local.month)} ${local.day}, ${_timeLabel(local)}';
}

String _month(int month) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];
