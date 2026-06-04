import 'package:flutter/material.dart';

import '../models/church_content.dart';
import '../services/supabase_service.dart';
import '../services/wordpress_service.dart';
import '../theme.dart';

const _appealOptions = [
  _AppealOption('Respond to Sermon Challenge', Icons.chat_bubble),
  _AppealOption('Request Prayer', Icons.favorite),
  _AppealOption('Share an Answered Prayer', Icons.groups),
  _AppealOption('Send Message to Pastors', Icons.mail),
  _AppealOption('Request Baptism', Icons.water_drop),
  _AppealOption('Request Bible Study', Icons.menu_book),
  _AppealOption('Request a Visit', Icons.person),
  _AppealOption("I'm New Here", Icons.add_circle),
];

class AppealsScreen extends StatefulWidget {
  const AppealsScreen({super.key});

  @override
  State<AppealsScreen> createState() => _AppealsScreenState();
}

class _AppealsScreenState extends State<AppealsScreen> {
  final _wordpress = WordpressService();
  final _message = TextEditingController();
  final _guestName = TextEditingController();
  final _guestEmail = TextEditingController();
  final _guestPhone = TextEditingController();
  final _sermonNote = TextEditingController();

  String _selectedOption = _appealOptions.first.label;
  ChurchSermon? _sermon;
  Map<String, dynamic>? _currentAppeal;
  List<_SermonNote> _previousNotes = const [];
  String? _selectedNoteId;
  String? _selectedNoteUrl;
  String _selectedNoteTitle = '';
  bool _loading = false;
  bool _savingNote = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _message.dispose();
    _guestName.dispose();
    _guestEmail.dispose();
    _guestPhone.dispose();
    _sermonNote.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    Map<String, dynamic>? appeal;
    ChurchSermon? sermon;

    try {
      appeal = await supabase
          .from('appeals')
          .select()
          .eq('active_status', true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
    } catch (_) {
      appeal = null;
    }

    sermon = await _wordpress.fetchLatestSermon();
    await _loadPreviousNotes();

    if (!mounted) return;
    setState(() {
      _sermon = sermon;
      _currentAppeal = appeal;
      _selectedNoteId = null;
      _selectedNoteUrl = sermon?.url;
      _selectedNoteTitle = sermon?.title ?? '';
    });
    await _loadSermonNote(sermon);
  }

  Future<void> _loadPreviousNotes() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await supabase
          .from('sermon_notes')
          .select('id,sermon_title,sermon_url,note,updated_at')
          .eq('user_id', user.id)
          .order('updated_at', ascending: false)
          .limit(10);

      final notes = (data as List)
          .map((item) => _SermonNote.fromMap(item as Map<String, dynamic>))
          .toList();
      if (mounted) setState(() => _previousNotes = notes);
    } catch (_) {
      if (mounted) setState(() => _previousNotes = const []);
    }
  }

  Future<void> _loadSermonNote(ChurchSermon? sermon) async {
    final user = supabase.auth.currentUser;
    if (user == null || sermon?.url == null) return;

    try {
      final data = await supabase
          .from('sermon_notes')
          .select('note')
          .eq('user_id', user.id)
          .eq('sermon_url', sermon!.url!)
          .maybeSingle();
      _sermonNote.text = (data?['note'] ?? '') as String;
    } catch (_) {
      _sermonNote.text = '';
    }
  }

  Future<void> _saveSermonNote() async {
    final sermonUrl = _selectedNoteUrl ?? _sermon?.url;
    final sermonTitle = _selectedNoteTitle.isNotEmpty
        ? _selectedNoteTitle
        : (_sermon?.title ?? 'Sermon Note');

    if (sermonUrl == null || _sermonNote.text.trim().isEmpty) {
      _showSnack('Add a note before saving.');
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) {
      _showSnack('Please sign in to save sermon notes.');
      return;
    }

    setState(() => _savingNote = true);
    try {
      await supabase.from('sermon_notes').upsert({
        'user_id': user.id,
        'sermon_title': sermonTitle,
        'sermon_url': sermonUrl,
        'note': _sermonNote.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,sermon_url');

      await _loadPreviousNotes();
      if (!mounted) return;
      setState(() => _selectedNoteId = null);
      _showSnack('Your sermon note has been saved.');
    } catch (error) {
      final message = error.toString();
      _showSnack(
        _isMissingSchemaError(message)
            ? 'Sermon notes need the Supabase pastor features patch.'
            : 'Could not save note. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
  }

  Future<void> _deleteSelectedNote() async {
    final noteId = _selectedNoteId;
    if (noteId == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Sermon Note?'),
        content: const Text('This will permanently remove this saved note.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    try {
      await supabase.from('sermon_notes').delete().eq('id', noteId);
      await _loadPreviousNotes();
      await _editLatestNote();
      _showSnack('The sermon note has been deleted.');
    } catch (_) {
      _showSnack('Could not delete note. Please try again.');
    }
  }

  void _editPreviousNote(_SermonNote note) {
    setState(() {
      _selectedNoteId = note.id;
      _selectedNoteUrl = note.sermonUrl;
      _selectedNoteTitle = note.sermonTitle;
      _sermonNote.text = note.note;
    });
  }

  Future<void> _editLatestNote() async {
    setState(() {
      _selectedNoteId = null;
      _selectedNoteUrl = _sermon?.url;
      _selectedNoteTitle = _sermon?.title ?? '';
    });
    await _loadSermonNote(_sermon);
  }

  Future<void> _submitResponse() async {
    final user = supabase.auth.currentUser;
    final isGuest = user == null;
    final messageText = _message.text.trim();

    if (_selectedOption == _appealOptions.first.label && messageText.isEmpty) {
      _showSnack('Please enter your response.');
      return;
    }
    if (isGuest &&
        (_guestName.text.trim().isEmpty ||
            (_guestEmail.text.trim().isEmpty && _guestPhone.text.trim().isEmpty))) {
      _showSnack('Please add your name and either an email or phone number.');
      return;
    }

    setState(() => _loading = true);
    try {
      final interestType = _interestTypeFor(_selectedOption);
      final contactSummary = isGuest
          ? [
              'Guest contact: ${_guestName.text.trim()}',
              if (_guestEmail.text.trim().isNotEmpty) 'Email: ${_guestEmail.text.trim()}',
              if (_guestPhone.text.trim().isNotEmpty) 'Phone: ${_guestPhone.text.trim()}',
            ].join(' | ')
          : null;
      final requesterName = user?.userMetadata?['full_name'] as String? ??
          user?.email ??
          (_guestName.text.trim().isEmpty ? 'Guest' : _guestName.text.trim());

      final payload = {
        'appeal_id': _currentAppeal?['id'],
        'user_id': user?.id,
        'requester_name': requesterName,
        'requester_email': user?.email ??
            (_guestEmail.text.trim().isEmpty ? null : _guestEmail.text.trim()),
        'response_data':
            ['[$_selectedOption] $messageText', contactSummary].whereType<String>().join('\n\n'),
        'interest_type': interestType,
      };

      Map<String, dynamic>? response;
      if (user == null) {
        await supabase.from('appeal_responses').insert(payload);
      } else {
        response = await supabase
            .from('appeal_responses')
            .insert(payload)
            .select('id')
            .single();
      }

      if (user != null && response?['id'] != null) {
        await supabase.from('follow_up_activity').insert({
          'response_id': response!['id'],
          'actor_id': user.id,
          'actor_name': requesterName,
          'activity_type': 'submitted',
          'note': _selectedOption,
        });
      }

      if (user != null && interestType != null) {
        await supabase.from('push_notification_messages').insert({
          'title': 'New $_selectedOption',
          'body': '$requesterName submitted a ${_selectedOption.toLowerCase()}.',
          'target_audience': 'pastoral_team',
          'status': 'queued',
          'sent_by_id': user.id,
          'sent_by_name': 'App',
        });
        await supabase.functions.invoke('send-push-notifications');
      }

      if (!mounted) return;
      setState(() {
        _message.clear();
        _guestName.clear();
        _guestEmail.clear();
        _guestPhone.clear();
      });
      _showSnack('Your response has been sent to the pastoral team.');
    } catch (error) {
      _showSnack(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final isGuest = user == null;
    final latestSermonIsUpcoming = _sermon?.isUpcoming ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: ListView(
          key: const PageStorageKey('appeals-scroll'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
          children: [
            const _Header(),
            const SizedBox(height: 18),
            _ChallengeCard(
              label: _currentAppeal != null
                  ? "Today's Challenge"
                  : latestSermonIsUpcoming
                      ? 'Upcoming Sermon'
                      : _sermon != null
                          ? 'Latest Sermon Response'
                          : 'Open Invitation',
              title: _currentAppeal?['title'] as String? ?? _sermon?.title ?? 'Connect with us',
              text: _currentAppeal?['description'] as String? ??
                  (latestSermonIsUpcoming
                      ? "Prepare for this Sabbath's message${_sermon?.speaker == null ? '' : ' from ${_sermon!.speaker}'}, or share how the pastoral team can pray with you."
                      : _sermon?.speaker == null
                          ? 'Share what is on your heart and the pastoral team will receive it.'
                          : 'Respond to the latest message from ${_sermon!.speaker}, or share how the pastoral team can pray with you.'),
            ),
            if (_sermon != null && user != null) ...[
              const SizedBox(height: 24),
              _SermonNotesCard(
                sermon: _sermon!,
                selectedNoteTitle: _selectedNoteTitle,
                selectedNoteUrl: _selectedNoteUrl,
                controller: _sermonNote,
                saving: _savingNote,
                selectedNoteId: _selectedNoteId,
                onSave: _saveSermonNote,
                onDelete: _deleteSelectedNote,
                onLatest: _editLatestNote,
              ),
            ],
            const SizedBox(height: 24),
            if (user != null)
              _NotesArchiveCard(notes: _previousNotes, onOpen: _editPreviousNote)
            else
              const _GuestInfoCard(),
            const SizedBox(height: 24),
            const Text(
              'I would like to',
              style: TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            _OptionGrid(
              selected: _selectedOption,
              onSelected: (option) => setState(() => _selectedOption = option),
            ),
            const SizedBox(height: 6),
            _ResponseCard(
              isGuest: isGuest,
              selectedOption: _selectedOption,
              latestSermonIsUpcoming: latestSermonIsUpcoming,
              message: _message,
              guestName: _guestName,
              guestEmail: _guestEmail,
              guestPhone: _guestPhone,
              loading: _loading,
              onSubmit: _submitResponse,
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          Image.asset(
            'assets/appeals-cross.jpg',
            height: 260,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Container(
            height: 260,
            padding: const EdgeInsets.all(22),
            color: const Color(0xD1F6F8FC),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/downsview-logo-black.png',
                  width: 230,
                  height: 68,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                ),
                const Spacer(),
                const Text(
                  'Connect',
                  style: TextStyle(
                    color: AppColors.blue,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'How can we help?',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 38,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Send a private response, prayer request, or pastoral care note.',
                  style: TextStyle(color: AppColors.text, fontSize: 17, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.label,
    required this.title,
    required this.text,
  });

  final String label;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          Image.asset(
            'assets/appeals-challenge.jpg',
            height: 220,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 220),
            padding: const EdgeInsets.all(20),
            color: const Color(0xCC051F40),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Color(0x2EFBBF24),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.flag, color: AppColors.gold, size: 30),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          height: 1.25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        text,
                        style: const TextStyle(color: Color(0xFFD8E2EF), fontSize: 15, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SermonNotesCard extends StatelessWidget {
  const _SermonNotesCard({
    required this.sermon,
    required this.selectedNoteTitle,
    required this.selectedNoteUrl,
    required this.controller,
    required this.saving,
    required this.selectedNoteId,
    required this.onSave,
    required this.onDelete,
    required this.onLatest,
  });

  final ChurchSermon sermon;
  final String selectedNoteTitle;
  final String? selectedNoteUrl;
  final TextEditingController controller;
  final bool saving;
  final String? selectedNoteId;
  final VoidCallback onSave;
  final VoidCallback onDelete;
  final VoidCallback onLatest;

  @override
  Widget build(BuildContext context) {
    final showingPrevious = selectedNoteUrl != null && selectedNoteUrl != sermon.url;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _RoundIcon(icon: Icons.edit_note, color: AppColors.navy),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sermon Notes',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${sermon.isUpcoming ? 'Upcoming Sermon' : 'Sermon Title'}: "${selectedNoteTitle.isEmpty ? sermon.title : selectedNoteTitle}"${sermon.speaker == null ? '' : ' | Speaker: ${sermon.speaker}'}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showingPrevious) ...[
            const SizedBox(height: 12),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.lightBlue,
                foregroundColor: AppColors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              onPressed: onLatest,
              child: const Text('Return to latest sermon'),
            ),
          ],
          const SizedBox(height: 14),
          _IconTextField(
            icon: Icons.edit,
            controller: controller,
            minLines: 4,
            hintText: sermon.isUpcoming
                ? 'Capture a question, prayer, or thought as you prepare...'
                : 'Capture a thought, decision, prayer, or follow-up question...',
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.bookmark_outline),
            label: const Text('Save Sermon Note'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
          ),
          if (selectedNoteId != null) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onDelete,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                foregroundColor: AppColors.danger,
                backgroundColor: const Color(0xFFFEF2F2),
                side: const BorderSide(color: Color(0xFFFECACA)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Delete Note', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotesArchiveCard extends StatelessWidget {
  const _NotesArchiveCard({required this.notes, required this.onOpen});

  final List<_SermonNote> notes;
  final ValueChanged<_SermonNote> onOpen;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _RoundIcon(icon: Icons.description, color: AppColors.lightBlue, iconColor: AppColors.blue),
              SizedBox(width: 14),
              Text('My Sermon Notes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 8),
          if (notes.isEmpty)
            const Text(
              'Saved sermon notes will appear here.',
              style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.5),
            )
          else
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onOpen(notes.first),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notes.first.sermonTitle,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            notes.first.note,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.muted, fontSize: 14),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'Updated ${notes.first.shortUpdatedAt}',
                            style: const TextStyle(
                              color: AppColors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.text),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GuestInfoCard extends StatelessWidget {
  const _GuestInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightBlue,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.account_circle_outlined, color: AppColors.blue, size: 30),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Browsing as a guest', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text(
                  'You can submit an appeal without an account. We will ask for contact information below so someone can follow up.',
                  style: TextStyle(color: AppColors.slate, fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionGrid extends StatelessWidget {
  const _OptionGrid({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final option in _appealOptions)
              SizedBox(
                width: width,
                child: _OptionTile(
                  option: option,
                  selected: selected == option.label,
                  onTap: () => onSelected(option.label),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.option, required this.selected, required this.onTap});

  final _AppealOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minHeight: 66),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.blue : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? AppColors.blue : AppColors.border),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected ? Colors.white.withValues(alpha: 0.2) : AppColors.lightBlue,
                shape: BoxShape.circle,
              ),
              child: Icon(option.icon, color: selected ? Colors.white : const Color(0xFF1D4ED8), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                option.label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF27415F),
                  fontSize: 14,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponseCard extends StatelessWidget {
  const _ResponseCard({
    required this.isGuest,
    required this.selectedOption,
    required this.latestSermonIsUpcoming,
    required this.message,
    required this.guestName,
    required this.guestEmail,
    required this.guestPhone,
    required this.loading,
    required this.onSubmit,
  });

  final bool isGuest;
  final String selectedOption;
  final bool latestSermonIsUpcoming;
  final TextEditingController message;
  final TextEditingController guestName;
  final TextEditingController guestEmail;
  final TextEditingController guestPhone;
  final bool loading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      radius: 22,
      child: Column(
        children: [
          if (isGuest) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Contact Information',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Required for guest responses so a pastor or interest coordinator can get back to you.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.45),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: guestName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: 'Full name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: guestEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(hintText: 'Email address'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: guestPhone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(hintText: 'Phone number'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          _IconTextField(
            icon: Icons.chat_bubble_outline,
            controller: message,
            minLines: 4,
            hintText: selectedOption == _appealOptions.first.label
                ? latestSermonIsUpcoming
                    ? "Share a thought or prayer for this Sabbath's message..."
                    : "Share your thoughts on today's message..."
                : 'Add any details here...',
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: loading ? null : onSubmit,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send),
            label: const Text('Submit Response'),
          ),
        ],
      ),
    );
  }
}

class _IconTextField extends StatelessWidget {
  const _IconTextField({
    required this.icon,
    required this.controller,
    required this.hintText,
    required this.minLines,
  });

  final IconData icon;
  final TextEditingController controller;
  final String hintText;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Icon(icon, color: const Color(0xFF94A3B8), size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: minLines,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: hintText,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.radius = 18});

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

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.color,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, color: iconColor, size: 27),
    );
  }
}

class _AppealOption {
  const _AppealOption(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _SermonNote {
  const _SermonNote({
    required this.id,
    required this.sermonTitle,
    required this.sermonUrl,
    required this.note,
    required this.updatedAt,
  });

  final String id;
  final String sermonTitle;
  final String sermonUrl;
  final String note;
  final DateTime? updatedAt;

  String get shortUpdatedAt {
    final date = updatedAt;
    if (date == null) return 'recently';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  factory _SermonNote.fromMap(Map<String, dynamic> map) {
    return _SermonNote(
      id: (map['id'] ?? '').toString(),
      sermonTitle: (map['sermon_title'] ?? 'Previous note').toString(),
      sermonUrl: (map['sermon_url'] ?? '').toString(),
      note: (map['note'] ?? '').toString(),
      updatedAt: DateTime.tryParse((map['updated_at'] ?? '').toString()),
    );
  }
}

String? _interestTypeFor(String option) {
  return switch (option) {
    'Request Prayer' => 'prayer',
    'Share an Answered Prayer' => 'answered_prayer',
    'Request Baptism' => 'baptism',
    'Request Bible Study' => 'bible_study',
    'Request a Visit' => 'visit',
    "I'm New Here" => 'visitor',
    _ => null,
  };
}

bool _isMissingSchemaError(String message) {
  final lower = message.toLowerCase();
  return lower.contains('schema cache') ||
      lower.contains('could not find the table') ||
      lower.contains('could not find the column');
}
