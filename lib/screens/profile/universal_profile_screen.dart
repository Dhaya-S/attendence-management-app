import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/widgets/user_avatar.dart';

/// Birth date as saved on the profile: the web saves "yyyy-MM-dd"; older app edits saved "Month d, yyyy".
DateTime? _parseDob(String s) {
  final t = s.trim();
  if (t.isEmpty) return null;
  final iso = FirestoreService.parseAnyDate(t);
  if (iso != null) return iso;
  for (final f in ['MMMM d, yyyy', 'MMM d, yyyy', 'dd/MM/yyyy']) {
    try {
      return DateFormat(f).parseStrict(t);
    } catch (_) {}
  }
  return null;
}

String _ageFromDob(String dobStr) {
  final dob = _parseDob(dobStr);
  if (dob == null) return '';
  final now = DateTime.now();
  var age = now.year - dob.year;
  if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) age--;
  return age < 0 ? '' : '$age years';
}

String _s(dynamic v) => (v ?? '').toString().trim();
String _first(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = _s(m[k]);
    if (v.isNotEmpty) return v;
  }
  return '';
}

class UniversalProfileScreen extends StatefulWidget {
  const UniversalProfileScreen({super.key});

  @override
  State<UniversalProfileScreen> createState() => _UniversalProfileScreenState();
}

class _UniversalProfileScreenState extends State<UniversalProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _userStream;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _userStream = FirestoreService.userStreamByEmail(user?.email ?? '');
  }

  void _showEditProfileSheet(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditProfileSheet(userData: data),
    );
  }

  void _showEditContactSheet(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditContactSheet(userData: data),
    );
  }

  void _showManagerProfileSheet(String managerName, String managerEmail) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ManagerProfileSheet(
        managerName: managerName,
        managerEmail: managerEmail,
      ),
    );
  }

  /// Pick a photo, shrink it, and save it on the profile so everyone in the organization sees it.
  Future<void> _changePhoto(bool hasPhoto) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(ctx, 'gallery'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(ctx, 'camera'),
          ),
          if (hasPhoto)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
              title: const Text('Remove photo', style: TextStyle(color: Color(0xFFDC2626))),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
        ]),
      ),
    );
    if (choice == null) return;

    final email = user?.email ?? '';
    setState(() => _uploadingPhoto = true);
    try {
      if (choice == 'remove') {
        await FirestoreService.employeeDoc(email)
            .set({'profileImageUrl': FieldValue.delete()}, SetOptions(merge: true));
      } else {
        final picked = await ImagePicker().pickImage(
          source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 60,
          maxWidth: 400,
          maxHeight: 400,
        );
        if (picked == null) return;
        final bytes = await picked.readAsBytes();
        await FirestoreService.employeeDoc(email)
            .set({'profileImageUrl': base64Encode(bytes)}, SetOptions(merge: true));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(choice == 'remove' ? 'Photo removed' : 'Profile photo updated'),
          backgroundColor: const Color(0xFF10B981),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not update photo: $e'), backgroundColor: const Color(0xFFEF4444)));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('My Profile', style: TextStyle(color: Color(0xFF111827), fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading profile: ${snapshot.error}'));
          }

          // Same field names the web "Add Employee" form saves
          final data = snapshot.data?.data() ?? {};
          final name = _first(data, ['name']).isNotEmpty ? _first(data, ['name']) : (AppSession().userName ?? 'User');
          final email = _first(data, ['email', 'workEmail']).isNotEmpty ? _first(data, ['email', 'workEmail']) : (user?.email ?? '');
          final phone = _first(data, ['phone']);
          final employeeId = () {
            final id = _first(data, ['employeeId', 'id']);
            return id.contains('@') ? '' : id;
          }();
          final designation = _first(data, ['designation']).isNotEmpty
              ? _first(data, ['designation'])
              : (_first(data, ['roleLabel']).isNotEmpty ? _first(data, ['roleLabel']) : AppSession().displayRole);
          final department = _first(data, ['dept', 'department']);
          final location = _first(data, ['branch', 'location']);
          final employeeType = _first(data, ['empType', 'employmentType', 'employeeType']);
          final status = _first(data, ['status']).isEmpty ? 'Active' : _first(data, ['status']);
          final managerName = _first(data, ['manager', 'managerName', 'reportingManager']);
          final managerEmail = _first(data, ['managerEmail']);
          final photo = _first(data, ['profileImageUrl']);

          final dobStr = _first(data, ['dob']);
          final dobShown = _parseDob(dobStr) == null ? dobStr : DateFormat('dd MMM yyyy').format(_parseDob(dobStr)!);
          final age = _ageFromDob(dobStr);
          final gender = _first(data, ['gender']);
          final maritalStatus = _first(data, ['maritalStatus']);

          String show(String v) => v.isEmpty ? 'Not provided' : v;
          final isActive = FirestoreService.isActiveUserDoc(data);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildCard(
                  title: 'BASIC INFORMATION',
                  child: Column(
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _uploadingPhoto ? null : () => _changePhoto(photo.isNotEmpty),
                            child: Stack(
                              children: [
                                UserAvatar(name: name, imageData: photo, radius: 34, color: const Color(0xFF4F46E5)),
                                if (_uploadingPhoto)
                                  const Positioned.fill(
                                    child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                  ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFF4F46E5),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2)),
                                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                                const SizedBox(height: 2),
                                Text(designation, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                            color: isActive ? const Color(0xFF10B981) : const Color(0xFF9CA3AF),
                                            shape: BoxShape.circle)),
                                    const SizedBox(width: 6),
                                    Text(status,
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isActive ? const Color(0xFF10B981) : const Color(0xFF6B7280))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildInfoRow('Employee ID', show(employeeId), trailingIcon: Icons.badge_outlined),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      _buildInfoRow('Official Email', show(email), trailingIcon: Icons.send_outlined),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      _buildInfoRow('Phone', show(phone), trailingIcon: Icons.phone_outlined),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildCard(
                  title: 'WORK INFORMATION',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoBlock('Department', show(department)),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      _buildInfoBlock('Office Location', show(location)),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      _buildInfoBlock('Designation', show(designation)),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      _buildInfoBlock('Employee Type', show(employeeType)),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      _buildInfoBlock('Employment Status', status),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      FutureBuilder<String>(
                        future: FirestoreService.shiftLabelForUser(Map<String, dynamic>.from(data)),
                        builder: (context, snap) => _buildInfoBlock('Assigned Shift', snap.data ?? '…'),
                      ),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Reporting Manager', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                                const SizedBox(height: 4),
                                Text(show(managerName), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                              ],
                            ),
                          ),
                          if (managerName.isNotEmpty)
                            TextButton.icon(
                              onPressed: () => _showManagerProfileSheet(managerName, managerEmail.isEmpty ? 'Not provided' : managerEmail),
                              icon: const Icon(Icons.person_outline, size: 16, color: Color(0xFF4F46E5)),
                              label: const Text('View Profile', style: TextStyle(color: Color(0xFF4F46E5), fontSize: 13, fontWeight: FontWeight.w600)),
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFFEEF2FF),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildCard(
                  title: 'PERSONAL INFORMATION',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoBlock('Date of Birth', show(dobShown)),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      _buildInfoBlock('Age', show(age)),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      _buildInfoBlock('Gender', show(gender)),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      _buildInfoBlock('Marital Status', show(maritalStatus)),
                      const SizedBox(height: 24),
                      _editButton('Edit Personal Information', () => _showEditProfileSheet(data)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildCard(
                  title: 'CONTACT DETAILS',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoBlock('Personal Email', show(_first(data, ['personalEmail']))),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      _buildInfoBlock(
                          'Current Address',
                          show([_first(data, ['address', 'currentAddress']), _first(data, ['city']), _first(data, ['zipCode'])]
                              .where((e) => e.isNotEmpty)
                              .join(', '))),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      _buildInfoBlock('Permanent Address', show(_first(data, ['permanentAddress']))),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      _buildInfoBlock('Emergency Contact',
                          show([_first(data, ['emergencyContact']), _first(data, ['emergencyPhone'])].where((e) => e.isNotEmpty).join(' · '))),
                      const SizedBox(height: 24),
                      _editButton('Edit Contact', () => _showEditContactSheet(data)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _editButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.edit_outlined, color: Color(0xFF4F46E5), size: 18),
        label: Text(label, style: const TextStyle(color: Color(0xFF4F46E5), fontSize: 14, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFEEF2FF),
          side: const BorderSide(color: Color(0xFFC7D2FE)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {IconData? trailingIcon}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
            ],
          ),
        ),
        if (trailingIcon != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(20)),
            child: Icon(trailingIcon, size: 18, color: const Color(0xFF4F46E5)),
          ),
      ],
    );
  }

  Widget _buildInfoBlock(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
      ],
    );
  }
}

// ── MANAGER PROFILE BOTTOM SHEET ──────────────────────────────────────────

class _ManagerProfileSheet extends StatelessWidget {
  final String managerName;
  final String managerEmail;

  const _ManagerProfileSheet({required this.managerName, required this.managerEmail});

  @override
  Widget build(BuildContext context) {
    final initials = managerName.split(' ').take(2).map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').join();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 36,
              backgroundColor: const Color(0xFF7C3AED),
              child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            Text(managerName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
            const SizedBox(height: 4),
            const Text('Reporting Manager', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 32),
            _buildManagerInfoRow('Email', managerEmail),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF3F4F6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Close', style: TextStyle(color: Color(0xFF374151), fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagerInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
      ],
    );
  }
}



// ── shared bits for the edit sheets ──────────────────────────────────────

InputDecoration _fieldDecoration({String? hintText}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4F46E5))),
  );
}

Widget _label(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
    );

Widget _sheetShell({
  required BuildContext context,
  required String title,
  required List<Widget> children,
  required bool saving,
  required VoidCallback onSave,
}) {
  return Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children))),
          SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: saving ? null : onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C5CFF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                child: saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _choiceRow(List<String> options, String selected, ValueChanged<String> onTap) {
  return Row(
    children: options
        .map((o) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => onTap(o),
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: selected == o ? const Color(0xFFEEF2FF) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(21),
                      border: Border.all(color: selected == o ? const Color(0xFFC7D2FE) : Colors.transparent),
                    ),
                    alignment: Alignment.center,
                    child: Text(o,
                        style: TextStyle(
                            color: selected == o ? const Color(0xFF4F46E5) : const Color(0xFF4B5563),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ))
        .toList(),
  );
}

// ── EDIT PERSONAL INFORMATION ──────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  final Map<String, dynamic> userData;
  const _EditProfileSheet({required this.userData});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  DateTime? _dob;
  String _gender = '';
  String _marital = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _dob = _parseDob(_s(widget.userData['dob']));
    _gender = _s(widget.userData['gender']);
    _marital = _s(widget.userData['maritalStatus']);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1996, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final email = FirebaseAuth.instance.currentUser?.email ?? '';
      await FirestoreService.employeeDoc(email).set({
        // "yyyy-MM-dd" — the same format the web saves
        if (_dob != null) 'dob': DateFormat('yyyy-MM-dd').format(_dob!),
        if (_gender.isNotEmpty) 'gender': _gender,
        if (_marital.isNotEmpty) 'maritalStatus': _marital,
      }, SetOptions(merge: true));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated'), backgroundColor: Color(0xFF10B981)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating profile: $e'), backgroundColor: const Color(0xFFEF4444)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _sheetShell(
      context: context,
      title: 'Edit Personal Information',
      saving: _saving,
      onSave: _save,
      children: [
        _label('Date of Birth'),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_dob == null ? 'Select date' : DateFormat('dd MMM yyyy').format(_dob!),
                    style: TextStyle(fontSize: 14, color: _dob == null ? const Color(0xFF9CA3AF) : const Color(0xFF111827))),
                const Icon(Icons.calendar_today_outlined, color: Color(0xFF6B7280), size: 18),
              ],
            ),
          ),
        ),
        if (_dob != null) ...[
          const SizedBox(height: 8),
          Text('Age: ${_ageFromDob(DateFormat('yyyy-MM-dd').format(_dob!))}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ],
        const SizedBox(height: 22),
        _label('Gender'),
        _choiceRow(const ['Male', 'Female', 'Other'], _gender, (v) => setState(() => _gender = v)),
        const SizedBox(height: 22),
        _label('Marital Status'),
        _choiceRow(const ['Single', 'Married', 'Divorced', 'Widowed'], _marital, (v) => setState(() => _marital = v)),
        const SizedBox(height: 16),
        const Text('Saved straight to your profile — HR sees the same details on the web.',
            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
      ],
    );
  }
}

// ── EDIT CONTACT DETAILS ───────────────────────────────────────────────────

class _EditContactSheet extends StatefulWidget {
  final Map<String, dynamic> userData;
  const _EditContactSheet({required this.userData});

  @override
  State<_EditContactSheet> createState() => _EditContactSheetState();
}

class _EditContactSheetState extends State<_EditContactSheet> {
  late final _phone = TextEditingController(text: _s(widget.userData['phone']));
  late final _personalEmail = TextEditingController(text: _s(widget.userData['personalEmail']));
  late final _address = TextEditingController(text: _first(widget.userData, ['address', 'currentAddress']));
  late final _city = TextEditingController(text: _s(widget.userData['city']));
  late final _zip = TextEditingController(text: _s(widget.userData['zipCode']));
  late final _permanent = TextEditingController(text: _s(widget.userData['permanentAddress']));
  late final _emName = TextEditingController(text: _s(widget.userData['emergencyContact']));
  late final _emPhone = TextEditingController(text: _s(widget.userData['emergencyPhone']));
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_phone, _personalEmail, _address, _city, _zip, _permanent, _emName, _emPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final email = FirebaseAuth.instance.currentUser?.email ?? '';
      // Same field names as the web profile so both platforms show the same values
      await FirestoreService.employeeDoc(email).set({
        'phone': _phone.text.trim(),
        'personalEmail': _personalEmail.text.trim(),
        'address': _address.text.trim(),
        'city': _city.text.trim(),
        'zipCode': _zip.text.trim(),
        'permanentAddress': _permanent.text.trim(),
        'emergencyContact': _emName.text.trim(),
        'emergencyPhone': _emPhone.text.trim(),
      }, SetOptions(merge: true));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact details updated'), backgroundColor: Color(0xFF10B981)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating contact details: $e'), backgroundColor: const Color(0xFFEF4444)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String label, TextEditingController c, {TextInputType? type, int lines = 1, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          TextField(controller: c, keyboardType: type, maxLines: lines, decoration: _fieldDecoration(hintText: hint)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _sheetShell(
      context: context,
      title: 'Edit Contact Information',
      saving: _saving,
      onSave: _save,
      children: [
        _field('Phone', _phone, type: TextInputType.phone),
        _field('Personal Email', _personalEmail, type: TextInputType.emailAddress),
        _field('Current Address', _address, lines: 2, hint: 'Door No, Street'),
        Row(children: [
          Expanded(child: _field('City', _city)),
          const SizedBox(width: 12),
          Expanded(child: _field('Zip Code', _zip, type: TextInputType.number)),
        ]),
        _field('Permanent Address', _permanent, lines: 2),
        GestureDetector(
          onTap: () => setState(() => _permanent.text = _address.text),
          child: const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Row(children: [
              Icon(Icons.content_copy_outlined, color: Color(0xFF4F46E5), size: 16),
              SizedBox(width: 8),
              Text('Same as current address', style: TextStyle(color: Color(0xFF4F46E5), fontSize: 13, fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
        _field('Emergency Contact Name', _emName),
        _field('Emergency Contact Phone', _emPhone, type: TextInputType.phone),
      ],
    );
  }
}
