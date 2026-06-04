import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/notification_service.dart';
import '../services/permission_settings_service.dart';
import '../services/supabase_service.dart';
import '../theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.isGuest,
    required this.onSignInPress,
  });

  final bool isGuest;
  final VoidCallback onSignInPress;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _fullName = TextEditingController();
  final _birthday = TextEditingController();
  final _phone = TextEditingController();
  final _preferredContact = TextEditingController();
  final _ministryInterest = TextEditingController();
  final _householdNotes = TextEditingController();
  final _notifications = NotificationService();

  User? _user;
  String? _avatarUrl;
  XFile? _selectedAvatar;
  bool _loading = true;
  bool _saving = false;
  NotificationPreferences _preferences = const NotificationPreferences();

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _fullName,
      _birthday,
      _phone,
      _preferredContact,
      _ministryInterest,
    ]) {
      controller.addListener(_refresh);
    }
    _loadUser();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _birthday.dispose();
    _phone.dispose();
    _preferredContact.dispose();
    _ministryInterest.dispose();
    _householdNotes.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadUser() async {
    final user = supabase.auth.currentUser;
    final metadata = user?.userMetadata ?? {};
    _user = user;
    _fullName.text = metadata['full_name'] as String? ?? '';
    _birthday.text = metadata['birthday'] as String? ?? '';
    _phone.text = metadata['phone'] as String? ?? '';
    _preferredContact.text = metadata['preferred_contact_method'] as String? ?? '';
    _ministryInterest.text = metadata['ministry_interest'] as String? ?? '';
    _householdNotes.text = metadata['household_notes'] as String? ?? '';
    _avatarUrl = metadata['avatar_url'] as String?;
    _preferences = NotificationPreferences.fromJson(
      metadata['notification_preferences'] is Map<String, dynamic>
          ? metadata['notification_preferences'] as Map<String, dynamic>
          : null,
    );
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _chooseAvatarSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Profile Photo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text(
                'Choose how you would like to update your photo.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_camera, color: AppColors.blue),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.blue),
                title: const Text('Choose from Library'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source != null) await _pickAvatar(source);
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 900,
        imageQuality: 80,
      );
      if (image != null) setState(() => _selectedAvatar = image);
    } on PlatformException {
      _showPermissionMessage(
        source == ImageSource.camera ? 'Camera Access Needed' : 'Photo Access Needed',
        source == ImageSource.camera
            ? 'Open App Settings and allow camera access to take a profile picture.'
            : 'Open App Settings and allow photo access to choose a profile picture.',
        source == ImageSource.camera ? PermissionSettingsTarget.app : PermissionSettingsTarget.photos,
      );
    }
  }

  Future<String?> _uploadAvatar() async {
    final user = _user ?? supabase.auth.currentUser;
    final avatar = _selectedAvatar;
    if (user == null || avatar == null) return _avatarUrl;

    final bytes = await avatar.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('Selected photo could not be read. Please choose another image or take a new photo.');
    }
    final extension = avatar.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final contentType = extension == 'png' ? 'image/png' : 'image/jpeg';
    final path = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await supabase.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: true),
    );
    return supabase.storage.from('avatars').getPublicUrl(path);
  }

  Future<void> _saveProfile() async {
    final user = _user ?? supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      final uploadedAvatarUrl = await _uploadAvatar();
      final cleanFullName = _fullName.text.trim();
      final preferences = _preferences.toJson();
      final response = await supabase.auth.updateUser(
        UserAttributes(
          data: {
            ...?user.userMetadata,
            'full_name': cleanFullName.isEmpty ? null : cleanFullName,
            'birthday': _birthday.text.trim(),
            'phone': _phone.text.trim(),
            'preferred_contact_method': _preferredContact.text.trim(),
            'ministry_interest': _ministryInterest.text.trim(),
            'household_notes': _householdNotes.text.trim(),
            'avatar_url': uploadedAvatarUrl,
            'notification_preferences': preferences,
          },
        ),
      );

      final updatedUser = response.user ?? user;
      await supabase.from('profiles').upsert({
        'id': updatedUser.id,
        'email': updatedUser.email,
        'full_name': cleanFullName.isEmpty ? null : cleanFullName,
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'preferred_contact_method':
            _preferredContact.text.trim().isEmpty ? null : _preferredContact.text.trim(),
        'ministry_interest':
            _ministryInterest.text.trim().isEmpty ? null : _ministryInterest.text.trim(),
        'household_notes': _householdNotes.text.trim().isEmpty ? null : _householdNotes.text.trim(),
        'birthday': _birthday.text.trim().isEmpty ? null : _birthday.text.trim(),
        'avatar_url': updatedUser.userMetadata?['avatar_url'] ?? uploadedAvatarUrl,
        'notification_preferences': preferences,
        'updated_at': DateTime.now().toIso8601String(),
      });

      await _notifications.scheduleChurchReminders(_preferences);

      if (!mounted) return;
      setState(() {
        _user = updatedUser;
        _avatarUrl = updatedUser.userMetadata?['avatar_url'] as String? ?? uploadedAvatarUrl;
        _selectedAvatar = null;
        _saving = false;
      });
      _showSnack('Your profile details have been saved.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      final message = error.toString();
      if (message.toLowerCase().contains('bucket not found')) {
        _showSnack('Avatar storage is not set up yet. Create the avatars bucket and try again.');
      } else {
        _showSnack('Could not save profile. Please try again.');
      }
    }
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
  }

  void _setPreference(String key, bool value) {
    setState(() {
      _preferences = NotificationPreferences(
        sabbathMorning: key == 'sabbathMorning' ? value : _preferences.sabbathMorning,
        worshipReminder: key == 'worshipReminder' ? value : _preferences.worshipReminder,
        midweekReminder: key == 'midweekReminder' ? value : _preferences.midweekReminder,
        sermonPosted: key == 'sermonPosted' ? value : _preferences.sermonPosted,
        eventReminders: key == 'eventReminders' ? value : _preferences.eventReminders,
      );
    });
    if (value) {
      unawaited(_notifications.registerPushTokenSafely());
    }
  }

  bool _preferenceValue(String key) {
    return switch (key) {
      'sabbathMorning' => _preferences.sabbathMorning,
      'worshipReminder' => _preferences.worshipReminder,
      'midweekReminder' => _preferences.midweekReminder,
      'sermonPosted' => _preferences.sermonPosted,
      'eventReminders' => _preferences.eventReminders,
      _ => false,
    };
  }

  void _showPermissionMessage(
    String title,
    String message,
    PermissionSettingsTarget settingsTarget,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
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

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF6F9FE),
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    final user = _user ?? supabase.auth.currentUser;
    if (widget.isGuest || user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F9FE),
        body: SafeArea(
          child: ListView(
            key: const PageStorageKey('profile-guest-scroll'),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 48),
            children: [
              const _ProfileHeader(
                eyebrow: 'Guest Access',
                title: 'You are browsing as a guest',
                subtitle:
                    'Sermons, events, bulletins, and appeals are open. Create an account when you want saved notes, profile details, and member features.',
                icon: Icons.person_add_alt_1_outlined,
              ),
              _ProfilePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Create an account when ready', style: _panelHeadingStyle),
                    const SizedBox(height: 6),
                    const Text(
                      'Registration helps the pastoral team connect responses with your profile, but guests can still request follow-up by entering contact information on the Response tab.',
                      style: _panelIntroStyle,
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: widget.onSignInPress,
                      icon: const Icon(Icons.login),
                      label: const Text('Sign In or Register'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final displayName = _fullName.text.trim().isNotEmpty
        ? _fullName.text.trim()
        : user.userMetadata?['full_name'] as String?;
    final initial = (displayName?.isNotEmpty == true
            ? displayName![0]
            : (user.email?.isNotEmpty == true ? user.email![0] : '?'))
        .toUpperCase();
    final profileTasks = [
      _ProfileTask('Add profile photo', _selectedAvatar != null || (_avatarUrl?.isNotEmpty == true)),
      _ProfileTask('Add birthday', _birthday.text.trim().isNotEmpty),
      _ProfileTask('Add contact preference', _preferredContact.text.trim().isNotEmpty),
      _ProfileTask('Choose notification rhythms', _preferences.toJson().values.any((value) => value == true)),
    ];
    final completedProfileTasks = profileTasks.where((task) => task.complete).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FE),
      body: SafeArea(
        child: ListView(
          key: const PageStorageKey('profile-scroll'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 48),
          children: [
            const _ProfileHeader(
              eyebrow: 'Profile',
              title: 'Your account',
              subtitle: 'Manage your identity and session for the Downsview SDA app.',
              icon: Icons.verified_user_outlined,
            ),
            _ProfilePanel(
              child: Column(
                children: [
                  _IdentityColumn(
                    user: user,
                    displayName: displayName,
                    initial: initial,
                    avatarUrl: _avatarUrl,
                    selectedAvatar: _selectedAvatar,
                    phone: _phone.text,
                    birthday: _birthday.text,
                    onAvatarTap: _chooseAvatarSource,
                  ),
                  _ProfileForm(
                    fullName: _fullName,
                    preferredContact: _preferredContact,
                    ministryInterest: _ministryInterest,
                    householdNotes: _householdNotes,
                    birthday: _birthday,
                    phone: _phone,
                    saving: _saving,
                    onSave: _saveProfile,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SetupPanel(
              completed: completedProfileTasks,
              tasks: profileTasks,
            ),
            const SizedBox(height: 18),
            _NotificationPanel(
              preferences: _preferences,
              valueFor: _preferenceValue,
              onChanged: _setPreference,
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: _signOut,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                foregroundColor: AppColors.danger,
                backgroundColor: const Color(0xFFFFF5F5),
                side: const BorderSide(color: Color(0xFFFECACA)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Sign Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Stack(
        clipBehavior: Clip.none,
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
              const SizedBox(height: 36),
              Text(eyebrow, style: const TextStyle(color: AppColors.blue, fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              SizedBox(
                width: 260,
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF082044),
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 250,
                child: Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF52647A), fontSize: 16, height: 1.5),
                ),
              ),
            ],
          ),
          Positioned(
            right: -38,
            bottom: 18,
            child: Transform.rotate(
              angle: -0.14,
              child: Container(
                width: 156,
                height: 118,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF).withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(60),
                ),
                child: Icon(icon, color: const Color(0xFF93B7EA), size: 92),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityColumn extends StatelessWidget {
  const _IdentityColumn({
    required this.user,
    required this.displayName,
    required this.initial,
    required this.avatarUrl,
    required this.selectedAvatar,
    required this.phone,
    required this.birthday,
    required this.onAvatarTap,
  });

  final User user;
  final String? displayName;
  final String initial;
  final String? avatarUrl;
  final XFile? selectedAvatar;
  final String phone;
  final String birthday;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onAvatarTap,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _AvatarImage(initial: initial, avatarUrl: avatarUrl, selectedAvatar: selectedAvatar),
                  Positioned(
                    right: -2,
                    bottom: 0,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Change Photo', style: TextStyle(color: AppColors.blue, fontSize: 13, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          displayName ?? 'Church Member',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF082044), fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(user.email ?? '', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF52647A), fontSize: 14)),
        const SizedBox(height: 18),
        const Divider(color: Color(0xFFE7EDF6)),
        const SizedBox(height: 14),
        _ContactSummary(icon: Icons.mail_outline, label: 'Email Address', value: user.email ?? 'Not set'),
        _ContactSummary(icon: Icons.call_outlined, label: 'Phone', value: phone.isEmpty ? 'Not set' : phone),
        _ContactSummary(icon: Icons.calendar_month_outlined, label: 'Birthday', value: birthday.isEmpty ? 'Not set' : birthday),
      ],
    );
  }
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.initial, this.avatarUrl, this.selectedAvatar});

  final String initial;
  final String? avatarUrl;
  final XFile? selectedAvatar;

  @override
  Widget build(BuildContext context) {
    final image = selectedAvatar != null
        ? FileImage(File(selectedAvatar!.path)) as ImageProvider
        : avatarUrl != null && avatarUrl!.isNotEmpty
            ? NetworkImage(avatarUrl!)
            : null;
    if (image != null) {
      return CircleAvatar(radius: 54, backgroundImage: image, backgroundColor: AppColors.lightBlue);
    }
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        color: AppColors.lightBlue,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.blue, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(initial, style: const TextStyle(color: AppColors.blue, fontSize: 36, fontWeight: FontWeight.w900)),
    );
  }
}

class _ContactSummary extends StatelessWidget {
  const _ContactSummary({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 66),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFF), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: const Color(0xFFEAF2FF), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.blue, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _detailLabelStyle),
                const SizedBox(height: 3),
                Text(value, style: _detailValueStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileForm extends StatelessWidget {
  const _ProfileForm({
    required this.fullName,
    required this.preferredContact,
    required this.ministryInterest,
    required this.householdNotes,
    required this.birthday,
    required this.phone,
    required this.saving,
    required this.onSave,
  });

  final TextEditingController fullName;
  final TextEditingController preferredContact;
  final TextEditingController ministryInterest;
  final TextEditingController householdNotes;
  final TextEditingController birthday;
  final TextEditingController phone;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 18),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE7EDF6)))),
      child: Column(
        children: [
          _ProfileInput(icon: Icons.person, label: 'Full Name', controller: fullName, hint: 'Full name', textCapitalization: TextCapitalization.words),
          _ProfileInput(icon: Icons.mail, label: 'Preferred Contact', controller: preferredContact, hint: 'Email, call, text...'),
          _ProfileInput(icon: Icons.favorite, label: 'Ministry / Interest', controller: ministryInterest, hint: 'Music, youth, hospitality...'),
          _ProfileInput(icon: Icons.description, label: 'Household Notes', controller: householdNotes, hint: 'Optional notes for your profile', minLines: 3),
          Row(
            children: [
              Expanded(child: _CompactInput(label: 'Birthday', controller: birthday, hint: 'YYYY-MM-DD')),
              const SizedBox(width: 10),
              Expanded(child: _CompactInput(label: 'Phone', controller: phone, hint: 'Phone number', keyboardType: TextInputType.phone)),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.verified_user),
            label: const Text('Save Profile'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F63F5)),
          ),
        ],
      ),
    );
  }
}

class _ProfileInput extends StatelessWidget {
  const _ProfileInput({
    required this.icon,
    required this.label,
    required this.controller,
    required this.hint,
    this.minLines = 1,
    this.textCapitalization = TextCapitalization.none,
  });

  final IconData icon;
  final String label;
  final TextEditingController controller;
  final String hint;
  final int minLines;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.blue, size: 18),
              const SizedBox(width: 6),
              Text(label, style: _detailLabelStyle),
            ],
          ),
          const SizedBox(height: 7),
          TextField(
            controller: controller,
            minLines: minLines,
            maxLines: minLines == 1 ? 1 : 5,
            textCapitalization: textCapitalization,
            decoration: InputDecoration(hintText: hint, fillColor: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _CompactInput extends StatelessWidget {
  const _CompactInput({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _detailLabelStyle),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(hintText: hint, fillColor: Colors.white),
        ),
      ],
    );
  }
}

class _SetupPanel extends StatelessWidget {
  const _SetupPanel({required this.completed, required this.tasks});

  final int completed;
  final List<_ProfileTask> tasks;

  @override
  Widget build(BuildContext context) {
    return _PreferencesPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitleRow(
            icon: Icons.assignment,
            title: 'Profile Setup',
            intro: '$completed of ${tasks.length} steps complete.',
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < tasks.length; i++)
                Expanded(child: _SetupStep(task: tasks[i], showConnector: i != 0)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Your profile is private to you. Pastors and authorized care leaders can see contact details, birthdays, ministry interests, and follow-up requests so they can care for members responsibly.',
            style: _privacyStyle,
          ),
        ],
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({required this.task, required this.showConnector});

  final _ProfileTask task;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        if (showConnector)
          Positioned(
            top: 15,
            left: 0,
            right: 34,
            child: Container(height: 2, color: const Color(0xFF2F8F4E)),
          ),
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: task.complete ? const Color(0xFF2F8F4E) : const Color(0xFFCBD5E1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 18),
            ),
            const SizedBox(height: 5),
            Text(
              task.complete ? 'Done' : 'Open',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: task.complete ? const Color(0xFF166534) : const Color(0xFFB45309),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              task.label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF082044), fontSize: 11, height: 1.35, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ],
    );
  }
}

class _NotificationPanel extends StatelessWidget {
  const _NotificationPanel({
    required this.preferences,
    required this.valueFor,
    required this.onChanged,
  });

  final NotificationPreferences preferences;
  final bool Function(String key) valueFor;
  final void Function(String key, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    const options = {
      'sabbathMorning': ('Sabbath morning companion', Icons.wb_sunny_outlined),
      'worshipReminder': ('Worship reminder', Icons.music_note_outlined),
      'midweekReminder': ('Midweek prayer reminder', Icons.favorite_border),
      'sermonPosted': ('New sermon posted', Icons.play_circle_outline),
      'eventReminders': ('Event reminders', Icons.calendar_month_outlined),
    };
    return _PreferencesPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitleRow(
            icon: Icons.notifications,
            title: 'Notification Preferences',
            intro: 'Choose the rhythms you want the app to help you remember.',
            lightIcon: true,
          ),
          const SizedBox(height: 8),
          for (final entry in options.entries)
            _SwitchRow(
              icon: entry.value.$2,
              label: entry.value.$1,
              value: valueFor(entry.key),
              onChanged: (value) => onChanged(entry.key, value),
            ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Icon(icon, color: AppColors.blue, size: 23),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(color: Color(0xFF082044), fontSize: 15, fontWeight: FontWeight.w800)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.blue,
            activeTrackColor: const Color(0xFFBFDBFE),
            inactiveThumbColor: const Color(0xFFF8FAFC),
            inactiveTrackColor: const Color(0xFFCBD5E1),
          ),
        ],
      ),
    );
  }
}

class _PanelTitleRow extends StatelessWidget {
  const _PanelTitleRow({
    required this.icon,
    required this.title,
    required this.intro,
    this.lightIcon = false,
  });

  final IconData icon;
  final String title;
  final String intro;
  final bool lightIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: lightIcon ? const Color(0xFFEAF2FF) : AppColors.blue,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: lightIcon ? AppColors.blue : Colors.white, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _panelHeadingStyle),
              const SizedBox(height: 6),
              Text(intro, style: _panelIntroStyle),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7EDF6)),
        boxShadow: const [
          BoxShadow(color: Color(0x140B2140), offset: Offset(0, 12), blurRadius: 24),
        ],
      ),
      child: child,
    );
  }
}

class _PreferencesPanel extends StatelessWidget {
  const _PreferencesPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7EDF6)),
        boxShadow: const [
          BoxShadow(color: Color(0x0F0B2140), offset: Offset(0, 10), blurRadius: 18),
        ],
      ),
      child: child,
    );
  }
}

class _ProfileTask {
  const _ProfileTask(this.label, this.complete);

  final String label;
  final bool complete;
}

const _detailLabelStyle = TextStyle(
  color: Color(0xFF52647A),
  fontSize: 12,
  fontWeight: FontWeight.w900,
);

const _detailValueStyle = TextStyle(
  color: Color(0xFF082044),
  fontSize: 15,
  fontWeight: FontWeight.w800,
);

const _panelHeadingStyle = TextStyle(
  color: Color(0xFF082044),
  fontSize: 20,
  fontWeight: FontWeight.w900,
);

const _panelIntroStyle = TextStyle(
  color: Color(0xFF52647A),
  fontSize: 14,
  height: 1.5,
);

const _privacyStyle = TextStyle(
  color: Color(0xFF52647A),
  fontSize: 14,
  height: 1.5,
);
