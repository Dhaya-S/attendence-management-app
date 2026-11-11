import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';

class CreateAnnouncementWizard extends StatefulWidget {
  final VoidCallback onClose;

  const CreateAnnouncementWizard({super.key, required this.onClose});

  @override
  State<CreateAnnouncementWizard> createState() =>
      _CreateAnnouncementWizardState();
}

enum WizardStep { form, preview, success }

class _CreateAnnouncementWizardState extends State<CreateAnnouncementWizard> {
  WizardStep _currentStep = WizardStep.form;

  // Form State
  String _selectedCategory = 'Manager Update';
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  DateTime? _expiryDate;
  final List<PlatformFile> _files = []; // attachments picked for this announcement
  bool _notifyAll = false;
  final _othersController = TextEditingController();
  Set<String> _selectedEmails = {};
  Set<String> _selectedTeams = {};
  late final Stream<QuerySnapshot> _employeesStream;

  @override
  void initState() {
    super.initState();
    _employeesStream = FirestoreService.employeesCol.snapshots();
  }

  final List<String> _categories = [
    'Manager Update',
    'Policy',
    'Events',
    'Reminders',
    'HR',
    'Birthdays',
    'New Hires'
  ];

  final List<String> _teams = [
    'Design Team',
    'Engineering Team',
    'Product Team'
  ];
  String _selectedTeam = 'Design Team';

  bool _isPublishing = false;
  final int _reachCount = 12; // Mock value for the design

  String _fileSize(int bytes) => bytes >= 1024 * 1024
      ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).round().clamp(1, 1 << 30)} KB';

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
    if (result == null) return;
    final tooBig = <String>[];
    setState(() {
      for (final f in result.files) {
        if (f.bytes == null) continue;
        if (f.size > 15 * 1024 * 1024) {
          tooBig.add(f.name);
          continue;
        }
        _files.add(f);
      }
    });
    if (tooBig.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Too large (max 15 MB): ${tooBig.join(', ')}')),
      );
    }
  }

  String _mimeFor(String? ext) {
    switch ((ext ?? '').toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  /// Uploads the picked files to Firebase Storage (same path the web app uses) and returns
  /// the attachment metadata saved on the announcement.
  Future<List<Map<String, dynamic>>> _uploadAttachments(String annId) async {
    final out = <Map<String, dynamic>>[];
    final cid = FirestoreService.companyId;
    for (final f in _files) {
      final safe = f.name.replaceAll(RegExp(r'[^\w.\- ]+'), '_');
      final path = 'organizations/$cid/announcements/$annId/$safe';
      final ref = FirebaseStorage.instance.ref(path);
      try {
        await ref.putData(f.bytes!, SettableMetadata(contentType: _mimeFor(f.extension)));
      } on FirebaseException catch (e) {
        throw (e.code == 'unauthorized' || e.code == 'unauthenticated')
            ? 'You do not have permission to upload attachments.'
            : 'File storage is not available yet. Ask your administrator to enable Firebase Storage. (${e.code})';
      }
      out.add({
        'name': f.name,
        'size': _fileSize(f.size),
        'type': (f.extension ?? '').toLowerCase().contains(RegExp(r'png|jpe?g|gif|webp')) ? 'image' : 'file',
        'url': await ref.getDownloadURL(),
        'storagePath': path,
      });
    }
    return out;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _othersController.dispose();
    super.dispose();
  }

  void _publishAnnouncement() async {
    setState(() => _isPublishing = true);

    try {
      final session = AppSession();
      final user = session.userName ?? 'Admin';
      final List<String> targetTeams = _selectedTeams.toList();
      
      final otherEmails = _othersController.text
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toList();
      final targetEmails = <String>{
        ..._selectedEmails.map((e) => e.trim().toLowerCase()),
        ...otherEmails,
      }.where((e) => e.contains('@')).toList();

      final now = DateTime.now();
      final myEmail = (session.email ?? '').toLowerCase();
      final bodyText = _messageController.text.trim();

      // Same audience model as the web app:
      //   all                → organizations/{cid}/announcements        (audienceType "all")
      //   departments        → organizations/{cid}/announcements        (audienceType "departments")
      //   particular members → organizations/{cid}/team_announcements   (audienceType "particular")
      String audienceType = 'all';
      List<String> targetDepts = [];
      if (!_notifyAll) {
        if (targetEmails.isNotEmpty) {
          audienceType = 'particular';
        } else if (targetTeams.isNotEmpty) {
          audienceType = 'departments';
          targetDepts = targetTeams
              .map((t) => t.replaceAll(RegExp(r'\s+Team$'), '').trim())
              .toList();
        }
      }

      final annId = audienceType == 'particular'
          ? 'T_ANN_${now.millisecondsSinceEpoch}'
          : 'ANN_${now.millisecondsSinceEpoch}';
      final attachments = await _uploadAttachments(annId);

      final base = <String, dynamic>{
        'attachments': attachments,
        'companyId': FirestoreService.companyId,
        'title': _titleController.text.trim(),
        'body': bodyText, // web field
        'message': bodyText,
        'content': bodyText,
        'priority': 'Normal',
        'category': _selectedCategory,
        'author': user,
        'authorName': user,
        'authorId': session.uid,
        'authorEmail': myEmail,
        'authorRole': session.role ?? 'employee',
        'status': 'Published', // web: Published / Draft
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'expiry': _expiryDate != null ? Timestamp.fromDate(_expiryDate!) : null,
        'likes': 0,
        'likedBy': <String>[],
        'commentsCount': 0,
      };

      if (audienceType == 'particular') {
        await FirestoreService.teamAnnouncementsCol.add({
          ...base,
          'id': annId,
          'audienceType': 'particular',
          'audience': 'particular',
          'targetMemberIds': targetEmails,
          'publishMode': 'Immediately',
          'dept':
              '${targetEmails.length} Team Member${targetEmails.length == 1 ? '' : 's'}',
          'pinned': false,
          'isDraft': false,
          'time': 'Today',
        });
      } else {
        await FirestoreService.announcementsCol.add({
          ...base,
          'id': annId,
          'audienceType': audienceType,
          'targetDepartments': targetDepts,
          'targetEmployeeIds': <String>[],
          'audience': audienceType == 'all'
              ? 'All Employees'
              : (targetDepts.isEmpty ? 'All Departments' : targetDepts.join(', ')),
          'date': DateFormat('MMM d').format(now),
          'views': 0,
        });
      }

      if (mounted) {
        setState(() {
          _isPublishing = false;
          _currentStep = WizardStep.success;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPublishing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    if (_currentStep == WizardStep.success) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            GestureDetector(
              onTap: widget.onClose,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.only(right: 12, top: 4, bottom: 4),
                child: Icon(Icons.arrow_back_ios_new,
                    size: 18, color: Color(0xFF1F2937)),
              ),
            ),
          ],
        ),
      );
    }

    final title = _currentStep == WizardStep.form
        ? 'Create Announcement'
        : 'Announcement Preview';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_currentStep == WizardStep.preview) {
                setState(() => _currentStep = WizardStep.form);
              } else {
                widget.onClose();
              }
            },
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.only(right: 12, top: 4, bottom: 4),
              child: Icon(Icons.arrow_back_ios_new,
                  size: 18, color: Color(0xFF1F2937)),
            ),
          ),
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937))),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentStep) {
      case WizardStep.form:
        return _buildFormStep();
      case WizardStep.preview:
        return _buildPreviewStep();
      case WizardStep.success:
        return _buildSuccessStep();
    }
  }

  // ==========================================
  // STEP 1: FORM
  // ==========================================
  Widget _buildFormStep() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Category',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937))),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categories.map((c) {
                          final isSel = _selectedCategory == c;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedCategory = c),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? const Color(0xFF5C5CFF)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(c,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSel
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSel
                                        ? Colors.white
                                        : const Color(0xFF64748B),
                                  )),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      const Text('Title',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937))),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          hintText: 'Announcement title...',
                          hintStyle: const TextStyle(
                              fontSize: 14, color: Color(0xFF94A3B8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF5C5CFF)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Message',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937))),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _messageController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Write your announcement...',
                          hintStyle: const TextStyle(
                              fontSize: 14, color: Color(0xFF94A3B8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF5C5CFF)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _pickAttachments,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.attach_file,
                                  size: 16, color: Color(0xFF5C5CFF)),
                              SizedBox(width: 8),
                              Text('Add attachment (max 15 MB each)',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF5C5CFF))),
                            ],
                          ),
                        ),
                      ),
                      for (var i = 0; i < _files.length; i++)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.insert_drive_file_outlined,
                                size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_files[i].name}  ·  ${_fileSize(_files[i].size)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                              ),
                            ),
                            GestureDetector(
                              onTap: _isPublishing ? null : () => setState(() => _files.removeAt(i)),
                              child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                            ),
                          ]),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Publish Settings Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Publish Settings',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1F2937))),
                      const SizedBox(height: 16),
                      const Text('Expiry',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF94A3B8))),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (date != null) {
                            setState(() => _expiryDate = date);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _expiryDate != null
                                    ? DateFormat('dd-MM-yyyy hh:mm a')
                                        .format(_expiryDate!)
                                    : 'DD-MM-YYYY hh:mm AM/PM',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: _expiryDate != null
                                        ? const Color(0xFF1F2937)
                                        : const Color(0xFF64748B)),
                              ),
                              const Icon(Icons.calendar_today_outlined,
                                  size: 18, color: Color(0xFF94A3B8)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () =>
                                setState(() => _notifyAll = !_notifyAll),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: _notifyAll
                                        ? const Color(0xFF5C5CFF)
                                        : const Color(0xFFE2E8F0)),
                                color: _notifyAll
                                    ? const Color(0xFF5C5CFF)
                                    : Colors.white,
                              ),
                              alignment: Alignment.center,
                              child: _notifyAll
                                  ? const Icon(Icons.check,
                                      size: 14, color: Colors.white)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text('Notify All Employees',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF475569))),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text('Notify Any Others',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF94A3B8))),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _othersController,
                        onChanged: (val) {
                          final typed = val.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet();
                          setState(() {
                            _selectedEmails = typed;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Enter emails or select employees below',
                          hintStyle: const TextStyle(
                              fontSize: 13, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Select Specific Employees:',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B))),
                      const SizedBox(height: 8),
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _employeesStream,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                            }
                            final docs = snapshot.data?.docs ?? [];
                            if (docs.isEmpty) {
                              return const Center(
                                child: Text('No employees found', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                              );
                            }
                            return ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.all(8),
                              itemCount: docs.length,
                              separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              itemBuilder: (context, index) {
                                final ed = docs[index].data() as Map<String, dynamic>;
                                final email = (ed['email'] ?? ed['userEmail'] ?? ed['uid'] ?? '').toString().toLowerCase();
                                final name = ed['name'] ?? ed['userName'] ?? email.split('@')[0];
                                final dept = ed['department'] ?? ed['role'] ?? 'Employee';
                                final isSelected = _selectedEmails.contains(email);

                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedEmails.remove(email);
                                      } else {
                                        _selectedEmails.add(email);
                                      }
                                      _othersController.text = _selectedEmails.join(', ');
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFFEEF2FF) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: isSelected ? const Color(0xFF5C5CFF) : const Color(0xFFCBD5E1),
                                          child: Text(
                                            name.isNotEmpty ? name[0].toUpperCase() : 'E',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? const Color(0xFF1E1B4B) : const Color(0xFF1E293B))),
                                              Text('$email · $dept', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                            ],
                                          ),
                                        ),
                                        Checkbox(
                                          value: isSelected,
                                          activeColor: const Color(0xFF5C5CFF),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                          onChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedEmails.add(email);
                                              } else {
                                                _selectedEmails.remove(email);
                                              }
                                              _othersController.text = _selectedEmails.join(', ');
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Teams / Departments Selection Card (Real-Time)
                if (!_notifyAll)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Teams / Departments',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1F2937))),
                            if (_selectedTeams.isNotEmpty)
                              GestureDetector(
                                onTap: () => setState(() => _selectedTeams.clear()),
                                child: const Text('Clear',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFEF4444))),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        StreamBuilder<QuerySnapshot>(
                          stream: _employeesStream,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData &&
                                snapshot.connectionState == ConnectionState.waiting) {
                              return const SizedBox(
                                height: 40,
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              );
                            }
                            final docs = snapshot.data?.docs ?? [];
                            final Set<String> depts = {};
                            for (final d in docs) {
                              final data = d.data() as Map<String, dynamic>;
                              final dept = data['department'] as String?;
                              if (dept != null && dept.trim().isNotEmpty) {
                                depts.add(dept.trim());
                              }
                            }

                            if (depts.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text('No departments found in Firestore',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                              );
                            }

                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: depts.map((t) {
                                final isSel = _selectedTeams.contains(t);
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (isSel) {
                                        _selectedTeams.remove(t);
                                      } else {
                                        _selectedTeams.add(t);
                                      }
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSel
                                          ? const Color(0xFFEEF2FF)
                                          : Colors.white,
                                      border: Border.all(
                                          color: isSel
                                              ? const Color(0xFF5C5CFF)
                                              : const Color(0xFFE2E8F0)),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(t,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isSel
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: isSel
                                                  ? const Color(0xFF5C5CFF)
                                                  : const Color(0xFF64748B),
                                            )),
                                        if (isSel) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.check,
                                              size: 12, color: Color(0xFF5C5CFF)),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 80), // Padding for button
              ],
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          color: const Color(0xFFF8FAFC),
          child: ElevatedButton(
            onPressed: () {
              if (_titleController.text.trim().isEmpty ||
                  _messageController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all required fields'),
                    backgroundColor: Color(0xFFEF4444),
                  ),
                );
                return;
              }
              setState(() => _currentStep = WizardStep.preview);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5C5CFF),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text('Preview',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STEP 2: PREVIEW
  // ==========================================
  Widget _buildPreviewStep() {
    final audience = _notifyAll
        ? 'All Employees'
        : (_selectedTeams.isNotEmpty
            ? _selectedTeams.join(', ')
            : (_selectedEmails.isNotEmpty
                ? '${_selectedEmails.length} Selected Employees'
                : 'Selected Employees'));

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Top Blue Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'IMPORTANT',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _titleController.text.trim(),
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${AppSession().userName ?? 'User'} (${AppSession().displayRole}) · Now',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.8)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Details Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _messageController.text.trim(),
                        style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 24),
                      _buildPreviewRow('Employees', audience),
                      const Divider(height: 24, color: Color(0xFFF1F5F9)),
                      _buildPreviewRow('Announcement Categories', _selectedCategory),
                      const Divider(height: 24, color: Color(0xFFF1F5F9)),
                      _buildPreviewRow('Priority', 'Important'),
                      const Divider(height: 24, color: Color(0xFFF1F5F9)),
                      _buildPreviewRow(
                          'Expiry',
                          _expiryDate != null
                              ? DateFormat('dd-MM-yyyy hh:mm a')
                                  .format(_expiryDate!)
                              : 'No Expiry'),
                      const Divider(height: 24, color: Color(0xFFF1F5F9)),
                      _buildPreviewRow('Attachment', 'None'),
                      const Divider(height: 24, color: Color(0xFFF1F5F9)),
                      const Text('Notify any others',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569))),
                      const SizedBox(height: 4),
                      Text(
                          _othersController.text.trim().isEmpty
                              ? 'None'
                              : _othersController.text.trim(),
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Reach Banner
                StreamBuilder<QuerySnapshot>(
                  stream: _employeesStream,
                  builder: (context, snapshot) {
                    final docs = snapshot.data?.docs ?? [];
                    int realReach = docs.length;
                    if (!_notifyAll) {
                      if (_selectedTeams.isNotEmpty) {
                        realReach = docs.where((d) {
                          final dept = ((d.data() as Map)['department'] ?? '').toString().trim();
                          return _selectedTeams.contains(dept);
                        }).length;
                      } else if (_selectedEmails.isNotEmpty) {
                        realReach = _selectedEmails.length;
                      }
                    }

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE0E7FF)),
                      ),
                      child: Text(
                        'Will reach $realReach employees in $audience',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4F46E5)),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          color: const Color(0xFFF8FAFC),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: ElevatedButton(
                  onPressed: () =>
                      setState(() => _currentStep = WizardStep.form),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Edit',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B))),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isPublishing ? null : _publishAnnouncement,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5C5CFF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isPublishing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Publish Now',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8))),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937))),
      ],
    );
  }

  // ==========================================
  // STEP 3: SUCCESS
  // ==========================================
  Widget _buildSuccessStep() {
    final audience = _notifyAll ? 'All Employees' : _selectedTeam;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD1FAE5), width: 8),
            ),
            child: const Icon(Icons.check, size: 50, color: Color(0xFF10B981)),
          ),
          const SizedBox(height: 32),
          const Text(
            'Announcement Published!',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 12),
          Text(
            'Your announcement has been sent to $_reachCount employees in $audience.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 15, height: 1.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 40),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildPreviewRow('Title', _titleController.text.trim()),
                const Divider(height: 32, color: Color(0xFFF1F5F9)),
                _buildPreviewRow('Audience', audience),
                const Divider(height: 32, color: Color(0xFFF1F5F9)),
                _buildPreviewRow('Reach', '$_reachCount employees'),
                const Divider(height: 32, color: Color(0xFFF1F5F9)),
                _buildPreviewRow('Acknowledged', '0 of $_reachCount (0%)'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
