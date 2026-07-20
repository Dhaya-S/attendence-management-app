import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';

class UniversalProfileScreen extends StatefulWidget {
  const UniversalProfileScreen({super.key});

  @override
  State<UniversalProfileScreen> createState() => _UniversalProfileScreenState();
}

class _UniversalProfileScreenState extends State<UniversalProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _userStream;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6), // Match design background
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

          final data = snapshot.data?.data() ?? {};
          
          // Extracted values
          final name = data['name'] ?? AppSession().userName ?? 'User';
          final email = data['email'] ?? user?.email ?? '';
          final phone = data['phone'] ?? '+91 00000 00000'; // Default placeholder if missing
          final employeeId = data['employeeId'] ?? AppSession().uid?.substring(0, 8).toUpperCase() ?? 'EMP-XXXX';
          final designation = data['designation'] ?? AppSession().role?.toUpperCase() ?? 'Employee';
          final department = data['department'] ?? 'General';
          final location = data['location'] ?? 'Sunrise Tech Park, Bangalore';
          final employeeType = data['employeeType'] ?? 'Full-Time Permanent';
          final status = (data['status'] ?? 'Active').toString();
          final shift = data['shift'] ?? 'General Shift Â· 09:00-18:00';
          final managerName = data['reportingManager'] ?? data['managerName'] ?? 'Sarah Mitchell';
          final managerEmail = data['managerEmail'] ?? 'manager@company.com';
          
          final dobStr = data['dob'] ?? 'March 14, 1996'; // Mock
          final age = data['age'] ?? '30 years'; // Mock
          final gender = data['gender'] ?? 'Male';
          final maritalStatus = data['maritalStatus'] ?? 'Single';

          final initials = name.split(' ').take(2).map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').join();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Basic Information Card
                _buildCard(
                  title: 'BASIC INFORMATION',
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundColor: const Color(0xFF4F46E5),
                                child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Color(0xFF4F46E5), shape: BoxShape.circle),
                                  child: const Icon(Icons.edit, color: Colors.white, size: 12),
                                ),
                              ),
                            ],
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
                                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                                    const SizedBox(width: 6),
                                    const Text('Active', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildInfoRow('Employee ID', employeeId, trailingIcon: Icons.badge_outlined),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      _buildInfoRow('Official Email', email, trailingIcon: Icons.send_outlined),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      _buildInfoRow('Official Phone', phone, trailingIcon: Icons.phone_outlined),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Work Information Card
                _buildCard(
                  title: 'WORK INFORMATION',
                  child: Column(
                    children: [
                      _buildInfoBlock('Department', department),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      _buildInfoBlock('Office Location', location),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      _buildInfoBlock('Designation', designation),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      _buildInfoBlock('Employee Type', employeeType),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      _buildInfoBlock('Employment Status', status),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      _buildInfoBlock('Assigned Shift', shift),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Reporting Manager', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              Text(managerName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: () => _showManagerProfileSheet(managerName, managerEmail),
                            icon: const Icon(Icons.person_outline, size: 16, color: Color(0xFF4F46E5)),
                            label: const Text('View Profile', style: TextStyle(color: Color(0xFF4F46E5), fontSize: 13, fontWeight: FontWeight.w600)),
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFFEEF2FF),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Personal Information Card
                _buildCard(
                  title: 'PERSONAL INFORMATION',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoBlock('Date of Birth', dobStr),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      _buildInfoBlock('Age', age),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      _buildInfoBlock('Gender', gender),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      _buildInfoBlock('Marital Status', maritalStatus),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () => _showEditProfileSheet(data),
                          icon: const Icon(Icons.edit_outlined, color: Color(0xFF4F46E5), size: 18),
                          label: const Text('Edit Personal Information', style: TextStyle(color: Color(0xFF4F46E5), fontSize: 14, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFFEEF2FF),
                            side: const BorderSide(color: Color(0xFFC7D2FE)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Contact Details Card
                _buildCard(
                  title: 'CONTACT DETAILS',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoBlock('Personal Phone', data['personalPhone'] ?? '+91 98765 00001'),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      _buildInfoBlock('Personal Email', data['personalEmail'] ?? 'rahul.personal@gmail.com'),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      _buildInfoBlock('Current Address', data['currentAddress'] ?? '42 Indiranagar, 1st Cross, Bangalore - 560038'),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      _buildInfoBlock('Permanent Address', data['permanentAddress'] ?? '12 Gandhi Nagar, Patna - 800001, Bihar'),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: () => _showEditContactSheet(data),
                                icon: const Icon(Icons.edit_outlined, color: Color(0xFF4F46E5), size: 18),
                                label: const Text('Edit Contact', style: TextStyle(color: Color(0xFF4F46E5), fontSize: 13, fontWeight: FontWeight.w600)),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEEF2FF),
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Map View Coming Soon!')));
                                },
                                icon: const Icon(Icons.location_on_outlined, color: Color(0xFF4F46E5), size: 18),
                                label: const Text('View on Map', style: TextStyle(color: Color(0xFF4F46E5), fontSize: 13, fontWeight: FontWeight.w600)),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEEF2FF),
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Color(0xFF9CA3AF),
            ),
          ),
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
          ],
        ),
        if (trailingIcon != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(8)),
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

// â”€â”€ MANAGER PROFILE BOTTOM SHEET â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
            const Text('Design Manager Â· EMP-1102', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 32),
            _buildManagerInfoRow('Department', 'Design'),
            const Divider(height: 24, color: Color(0xFFF3F4F6)),
            _buildManagerInfoRow('Phone', '+91 98765 11111'),
            const Divider(height: 24, color: Color(0xFFF3F4F6)),
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

// â”€â”€ EDIT PROFILE BOTTOM SHEET â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _EditProfileSheet extends StatefulWidget {
  final Map<String, dynamic> userData;

  const _EditProfileSheet({required this.userData});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _dobController = TextEditingController();
  String _selectedGender = 'Male';
  String _selectedMaritalStatus = 'Single';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _dobController.text = widget.userData['dob'] ?? 'March 14, 1996';
    _selectedGender = widget.userData['gender'] ?? 'Male';
    _selectedMaritalStatus = widget.userData['maritalStatus'] ?? 'Single';
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final email = FirebaseAuth.instance.currentUser?.email ?? '';
      await FirestoreService.employeeDoc(email).update({
        'dob': _dobController.text,
        'gender': _selectedGender,
        'maritalStatus': _selectedMaritalStatus,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully'), backgroundColor: Color(0xFF10B981)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating profile: $e'), backgroundColor: const Color(0xFFEF4444)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Edit Personal Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Date of Birth', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _dobController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('March 14, 1996 Â· Age 30 years', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))), // Mock calculation
                  const SizedBox(height: 24),
                  
                  const Text('Gender', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                  const SizedBox(height: 8),
                  Row(
                    children: ['Male', 'Female', 'Other'].map((gender) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedGender = gender),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: _selectedGender == gender ? const Color(0xFFEEF2FF) : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _selectedGender == gender ? const Color(0xFFC7D2FE) : Colors.transparent),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_selectedGender == gender) ...[
                                  const Icon(Icons.circle, color: Color(0xFF4F46E5), size: 10),
                                  const SizedBox(width: 6),
                                ],
                                Text(gender, style: TextStyle(
                                  color: _selectedGender == gender ? const Color(0xFF4F46E5) : const Color(0xFF4B5563),
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                )),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 24),

                  const Text('Marital Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                  const SizedBox(height: 8),
                  Row(
                    children: ['Single', 'Married', 'Divorced', 'Widowed'].map((status) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4.0),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedMaritalStatus = status),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: _selectedMaritalStatus == status ? const Color(0xFFEEF2FF) : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _selectedMaritalStatus == status ? const Color(0xFFC7D2FE) : Colors.transparent),
                            ),
                            alignment: Alignment.center,
                            child: Text(status, style: TextStyle(
                              color: _selectedMaritalStatus == status ? const Color(0xFF4F46E5) : const Color(0xFF4B5563),
                              fontSize: 12, fontWeight: FontWeight.w600,
                            )),
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: const Text(
                            'Changes will be reviewed by HR before being reflected on your profile.',
                            style: TextStyle(color: Color(0xFFB45309), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5C5CFF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
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

// â”€â”€ EDIT CONTACT BOTTOM SHEET â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _EditContactSheet extends StatefulWidget {
  final Map<String, dynamic> userData;

  const _EditContactSheet({required this.userData});

  @override
  State<_EditContactSheet> createState() => _EditContactSheetState();
}

class _EditContactSheetState extends State<_EditContactSheet> {
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentAddressController = TextEditingController();
  final _permanentAddressController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.userData['personalPhone'] ?? '';
    _emailController.text = widget.userData['personalEmail'] ?? '';
    _currentAddressController.text = widget.userData['currentAddress'] ?? '';
    _permanentAddressController.text = widget.userData['permanentAddress'] ?? '';
  }

  void _copyCurrentToPermanent() {
    setState(() {
      _permanentAddressController.text = _currentAddressController.text;
    });
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final email = FirebaseAuth.instance.currentUser?.email ?? '';
      await FirestoreService.employeeDoc(email).update({
        'personalPhone': _phoneController.text,
        'personalEmail': _emailController.text,
        'currentAddress': _currentAddressController.text,
        'permanentAddress': _permanentAddressController.text,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact details updated successfully'), backgroundColor: Color(0xFF10B981)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating contact details: $e'), backgroundColor: const Color(0xFFEF4444)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: 20),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                const Text('Edit Contact Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Personal Phone', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Personal Email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Current Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _currentAddressController,
                      maxLines: 3,
                      decoration: _inputDecoration(hintText: 'Door No, Street, City - Pincode'),
                    ),
                    const SizedBox(height: 16),
                    const Text('Permanent Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _permanentAddressController,
                      maxLines: 3,
                      decoration: _inputDecoration(hintText: 'Door No, Street, City - Pincode'),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _copyCurrentToPermanent,
                      child: Row(
                        children: [
                          const Icon(Icons.content_copy_outlined, color: Color(0xFF4F46E5), size: 16),
                          const SizedBox(width: 8),
                          const Text('Same as current address', style: TextStyle(color: Color(0xFF4F46E5), fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: const Text(
                              'Changes will be reviewed by HR before being reflected on your profile.',
                              style: TextStyle(color: Color(0xFFB45309), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5C5CFF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4F46E5))),
    );
  }
}
