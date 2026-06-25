import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:attendance_app/features/manager_main_screen.dart';
import 'package:attendance_app/screens/organization_configuration_screen.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/message_helper.dart';

// ── Employee Model ────────────────────────────────────────────────────────────

class _EmpModel {
  final String id;
  String firstName, lastName;
  String email, phone, alternatePhone;
  DateTime? joiningDate;
  String employeeId;
  String deptId, deptName;
  String designation;
  String role;
  String empType;
  String location;
  String? reportingManagerId, reportingManagerName;
  DateTime? dob;
  String gender, maritalStatus, bloodGroup;
  String emergencyName, emergencyPhone;
  String govtIdType, govtIdNumber;
  String homeAddress;
  String invitationStatus;
  Color color;

  _EmpModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    this.alternatePhone = '',
    this.joiningDate,
    required this.employeeId,
    required this.deptId,
    required this.deptName,
    required this.designation,
    required this.role,
    required this.empType,
    required this.location,
    this.reportingManagerId,
    this.reportingManagerName,
    this.dob,
    this.gender = 'Male',
    this.maritalStatus = 'Single',
    this.bloodGroup = 'O+',
    this.emergencyName = '',
    this.emergencyPhone = '',
    this.govtIdType = 'Aadhaar Card',
    this.govtIdNumber = '',
    this.homeAddress = '',
    this.invitationStatus = 'pending',
    required this.color,
  });

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$f$l'.isEmpty ? '?' : '$f$l';
  }
}

// ── Supporting Models ─────────────────────────────────────────────────────────

class _DeptInfo {
  final String id, name;
  const _DeptInfo(this.id, this.name);
}

class _ManagerInfo {
  final String id, name, role;
  const _ManagerInfo(this.id, this.name, this.role);
}

// ── Screen ────────────────────────────────────────────────────────────────────

class EmployeeSetupScreen extends StatefulWidget {
  final String orgId;
  final String orgName;

  const EmployeeSetupScreen({
    super.key,
    required this.orgId,
    required this.orgName,
  });

  @override
  State<EmployeeSetupScreen> createState() => _EmployeeSetupScreenState();
}

class _EmployeeSetupScreenState extends State<EmployeeSetupScreen> {
  // ─── Navigation state ───────────────────────────────────────────────────────
  // 0=intro, 1=list, 2=form, 3=review, 4=success, 5=invite, 6=complete
  int _step = 0;
  int _formStep = 1; // 1=basic, 2=work, 3=personal

  bool _isSubmitting = false;
  bool _isSendingInvitations = false;

  // ─── Loaded data ────────────────────────────────────────────────────────────
  List<_DeptInfo> _departments = [];
  List<_ManagerInfo> _managers = [];
  bool _loadingData = true;

  // ─── Session employees ──────────────────────────────────────────────────────
  final List<_EmpModel> _employees = [];
  _EmpModel? _editingEmp;
  _EmpModel? _lastAddedEmp;

  // ─── Invite ─────────────────────────────────────────────────────────────────
  final Set<String> _selectedForInvite = {};

  // ─── Search ─────────────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // ─── Form step 1: Basic Info ────────────────────────────────────────────────
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _altPhoneCtrl = TextEditingController();
  DateTime? _joiningDate;

  // ─── Form step 2: Work Info ─────────────────────────────────────────────────
  String _empIdValue = '';
  String _selectedDeptId = '';
  String _selectedDeptName = '';
  final _designationCtrl = TextEditingController();
  String? _selectedRole;
  String? _selectedEmpType;
  String? _selectedLocation;
  String? _selectedManagerId;
  String? _selectedManagerName;

  // ─── Form step 3: Personal Info ─────────────────────────────────────────────
  DateTime? _dob;
  String? _selectedGender;
  String? _selectedMarital;
  String? _selectedBloodGroup;
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();
  String? _selectedGovtIdType;
  final _govtIdNumberCtrl = TextEditingController();
  final _homeAddressCtrl = TextEditingController();

  // ─── Constants ──────────────────────────────────────────────────────────────
  static const _roles = ['Employee', 'Manager', 'Team Lead', 'Intern'];
  static const _empTypes = ['Permanent', 'Contract', 'Part-time', 'Intern'];
  static const _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];
  static const _maritalStatuses = ['Single', 'Married', 'Divorced', 'Widowed'];
  static const _bloodGroups = ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'];
  static const _govtIdTypes = ['Aadhaar Card', 'PAN Card', 'Passport', "Driver's License"];

  static const _avatarColors = [
    Color(0xFF5C5CFF),
    Color(0xFF23A6F0),
    Color(0xFFF59E0B),
    Color(0xFF22C55E),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
  ];

  Color _nextColor() => _avatarColors[_employees.length % _avatarColors.length];

  // ─── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final deptSnap = await FirestoreService.orgDepartmentsCol(widget.orgId).get();
      final membersSnap = await FirestoreService.orgMembersCol(widget.orgId).get();

      final depts = deptSnap.docs
          .map((d) => _DeptInfo(d.id, d.data()['name'] as String? ?? d.id))
          .toList();

      final managers = membersSnap.docs
          .where((d) {
            final r = (d.data()['role'] as String? ?? '').toLowerCase();
            return r == 'admin' || r == 'manager';
          })
          .map((d) => _ManagerInfo(
                d.id,
                d.data()['fullName'] as String? ?? d.data()['email'] as String? ?? 'Admin',
                d.data()['role'] as String? ?? 'admin',
              ))
          .toList();

      if (mounted) {
        setState(() {
          _departments = depts;
          _managers = managers;
          _loadingData = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _altPhoneCtrl.dispose();
    _designationCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _govtIdNumberCtrl.dispose();
    _homeAddressCtrl.dispose();
    super.dispose();
  }

  // ─── Navigation helpers ──────────────────────────────────────────────────────

  void _goBack() {
    switch (_step) {
      case 0:
        Navigator.pop(context);
      case 1:
        setState(() => _step = 0);
      case 2:
        if (_formStep > 1) {
          setState(() => _formStep--);
        } else {
          setState(() {
            _step = 1;
            _editingEmp = null;
          });
        }
      case 3:
        setState(() {
          _step = 2;
          _formStep = 3;
        });
      case 4:
        setState(() => _step = 1);
      case 5:
        setState(() => _step = 1);
      default:
        break;
    }
  }

  String _generateEmpId() {
    final initials = widget.orgName
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .take(2)
        .join();
    return '$initials-${(_employees.length + 1).toString().padLeft(3, '0')}';
  }

  void _openAddForm({_EmpModel? existing}) {
    _editingEmp = existing;
    if (existing != null) {
      _firstNameCtrl.text = existing.firstName;
      _lastNameCtrl.text = existing.lastName;
      _emailCtrl.text = existing.email;
      _phoneCtrl.text = existing.phone;
      _altPhoneCtrl.text = existing.alternatePhone;
      _joiningDate = existing.joiningDate;
      _empIdValue = existing.employeeId;
      _selectedDeptId = existing.deptId;
      _selectedDeptName = existing.deptName;
      _designationCtrl.text = existing.designation;
      _selectedRole = existing.role;
      _selectedEmpType = existing.empType;
      _selectedLocation = existing.location;
      _selectedManagerId = existing.reportingManagerId;
      _selectedManagerName = existing.reportingManagerName;
      _dob = existing.dob;
      _selectedGender = existing.gender;
      _selectedMarital = existing.maritalStatus;
      _selectedBloodGroup = existing.bloodGroup;
      _emergencyNameCtrl.text = existing.emergencyName;
      _emergencyPhoneCtrl.text = existing.emergencyPhone;
      _selectedGovtIdType = existing.govtIdType;
      _govtIdNumberCtrl.text = existing.govtIdNumber;
      _homeAddressCtrl.text = existing.homeAddress;
    } else {
      _firstNameCtrl.clear();
      _lastNameCtrl.clear();
      _emailCtrl.clear();
      _phoneCtrl.clear();
      _altPhoneCtrl.clear();
      _joiningDate = null;
      _empIdValue = _generateEmpId();
      if (_departments.isNotEmpty) {
        _selectedDeptId = _departments.first.id;
        _selectedDeptName = _departments.first.name;
      }
      _designationCtrl.clear();
      _selectedRole = 'Employee';
      _selectedEmpType = 'Permanent';
      _selectedLocation = widget.orgName;
      _selectedManagerId = null;
      _selectedManagerName = null;
      _dob = null;
      _selectedGender = 'Male';
      _selectedMarital = 'Single';
      _selectedBloodGroup = 'O+';
      _emergencyNameCtrl.clear();
      _emergencyPhoneCtrl.clear();
      _selectedGovtIdType = 'Aadhaar Card';
      _govtIdNumberCtrl.clear();
      _homeAddressCtrl.clear();
    }
    setState(() {
      _step = 2;
      _formStep = 1;
    });
  }

  bool _validateStep() {
    switch (_formStep) {
      case 1:
        if (_firstNameCtrl.text.trim().isEmpty) {
          MessageHelper.showWarning(context, 'First name is required.');
          return false;
        }
        if (_lastNameCtrl.text.trim().isEmpty) {
          MessageHelper.showWarning(context, 'Last name is required.');
          return false;
        }
        if (!_emailCtrl.text.trim().contains('@')) {
          MessageHelper.showWarning(context, 'Enter a valid email address.');
          return false;
        }
        if (_phoneCtrl.text.trim().isEmpty) {
          MessageHelper.showWarning(context, 'Phone number is required.');
          return false;
        }
        return true;
      case 2:
        if (_designationCtrl.text.trim().isEmpty) {
          MessageHelper.showWarning(context, 'Designation is required.');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _goNextFormStep() {
    if (!_validateStep()) return;
    if (_formStep < 3) {
      setState(() => _formStep++);
    } else {
      setState(() => _step = 3);
    }
  }

  // ─── Firestore writes ────────────────────────────────────────────────────────

  Future<void> _createEmployee() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final now = FieldValue.serverTimestamp();
      final docRef = FirestoreService.orgMembersCol(widget.orgId).doc();
      final color = _nextColor();

      final emp = _EmpModel(
        id: docRef.id,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        email: _emailCtrl.text.trim().toLowerCase(),
        phone: _phoneCtrl.text.trim(),
        alternatePhone: _altPhoneCtrl.text.trim(),
        joiningDate: _joiningDate,
        employeeId: _empIdValue,
        deptId: _selectedDeptId,
        deptName: _selectedDeptName,
        designation: _designationCtrl.text.trim(),
        role: _selectedRole ?? '',
        empType: _selectedEmpType ?? '',
        location: _selectedLocation ?? '',
        reportingManagerId: _selectedManagerId,
        reportingManagerName: _selectedManagerName,
        dob: _dob,
        gender: _selectedGender ?? '',
        maritalStatus: _selectedMarital ?? '',
        bloodGroup: _selectedBloodGroup ?? '',
        emergencyName: _emergencyNameCtrl.text.trim(),
        emergencyPhone: _emergencyPhoneCtrl.text.trim(),
        govtIdType: _selectedGovtIdType ?? '',
        govtIdNumber: _govtIdNumberCtrl.text.trim(),
        homeAddress: _homeAddressCtrl.text.trim(),
        color: color,
      );

      await docRef.set({
        'uid': null,
        'email': emp.email,
        'firstName': emp.firstName,
        'lastName': emp.lastName,
        'fullName': emp.fullName,
        'employeeId': emp.employeeId,
        'role': emp.role.toLowerCase(),
        'designation': emp.designation,
        'department': emp.deptName,
        'departmentId': emp.deptId,
        'location': emp.location,
        'employeeType': emp.empType,
        'reportingManagerId': emp.reportingManagerId,
        'reportingManagerName': emp.reportingManagerName,
        'phone': emp.phone,
        'alternatePhone': emp.alternatePhone,
        'joiningDate': emp.joiningDate?.toIso8601String(),
        'dob': emp.dob?.toIso8601String(),
        'gender': emp.gender,
        'maritalStatus': emp.maritalStatus,
        'bloodGroup': emp.bloodGroup,
        'emergencyContact': {'name': emp.emergencyName, 'phone': emp.emergencyPhone},
        'govtIdType': emp.govtIdType,
        'govtIdNumber': emp.govtIdNumber,
        'homeAddress': emp.homeAddress,
        'invitationStatus': 'pending',
        'status': 'pending',
        'orgId': widget.orgId,
        'companyId': widget.orgId,
        'workEmail': emp.email,
        'createdAt': now,
        'updatedAt': now,
      });

      if (!mounted) return;
      setState(() {
        _employees.add(emp);
        _selectedForInvite.add(emp.id);
        _lastAddedEmp = emp;
        _isSubmitting = false;
        _editingEmp = null;
        _step = 4;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      MessageHelper.showError(context, 'Failed to create employee: $e');
    }
  }

  Future<void> _updateEmployee() async {
    if (_isSubmitting || _editingEmp == null) return;
    setState(() => _isSubmitting = true);
    try {
      final emp = _editingEmp!;
      emp.firstName = _firstNameCtrl.text.trim();
      emp.lastName = _lastNameCtrl.text.trim();
      emp.email = _emailCtrl.text.trim().toLowerCase();
      emp.phone = _phoneCtrl.text.trim();
      emp.alternatePhone = _altPhoneCtrl.text.trim();
      emp.joiningDate = _joiningDate;
      emp.deptId = _selectedDeptId;
      emp.deptName = _selectedDeptName;
      emp.designation = _designationCtrl.text.trim();
      emp.role = _selectedRole ?? '';
      emp.empType = _selectedEmpType ?? '';
      emp.location = _selectedLocation ?? '';
      emp.reportingManagerId = _selectedManagerId;
      emp.reportingManagerName = _selectedManagerName;
      emp.dob = _dob;
      emp.gender = _selectedGender ?? '';
      emp.maritalStatus = _selectedMarital ?? '';
      emp.bloodGroup = _selectedBloodGroup ?? '';
      emp.emergencyName = _emergencyNameCtrl.text.trim();
      emp.emergencyPhone = _emergencyPhoneCtrl.text.trim();
      emp.govtIdType = _selectedGovtIdType ?? '';
      emp.govtIdNumber = _govtIdNumberCtrl.text.trim();
      emp.homeAddress = _homeAddressCtrl.text.trim();

      await FirestoreService.orgMemberDoc(widget.orgId, emp.id).update({
        'email': emp.email,
        'firstName': emp.firstName,
        'lastName': emp.lastName,
        'fullName': emp.fullName,
        'designation': emp.designation,
        'department': emp.deptName,
        'departmentId': emp.deptId,
        'location': emp.location,
        'employeeType': emp.empType,
        'role': emp.role.toLowerCase(),
        'reportingManagerId': emp.reportingManagerId,
        'reportingManagerName': emp.reportingManagerName,
        'phone': emp.phone,
        'alternatePhone': emp.alternatePhone,
        'joiningDate': emp.joiningDate?.toIso8601String(),
        'dob': emp.dob?.toIso8601String(),
        'gender': emp.gender,
        'maritalStatus': emp.maritalStatus,
        'bloodGroup': emp.bloodGroup,
        'emergencyContact': {'name': emp.emergencyName, 'phone': emp.emergencyPhone},
        'govtIdType': emp.govtIdType,
        'govtIdNumber': emp.govtIdNumber,
        'homeAddress': emp.homeAddress,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _editingEmp = null;
        _step = 1;
      });
      MessageHelper.showSuccess(context, 'Employee updated!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      MessageHelper.showError(context, 'Failed to update: $e');
    }
  }

  Future<void> _sendInvitations() async {
    if (_isSendingInvitations || _selectedForInvite.isEmpty) return;
    setState(() => _isSendingInvitations = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final empId in _selectedForInvite) {
        batch.update(FirestoreService.orgMemberDoc(widget.orgId, empId), {
          'invitationStatus': 'sent',
          'invitedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      for (final emp in _employees) {
        if (_selectedForInvite.contains(emp.id)) emp.invitationStatus = 'sent';
      }

      if (!mounted) return;
      setState(() {
        _isSendingInvitations = false;
        _step = 6;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingInvitations = false);
      MessageHelper.showError(context, 'Failed to send: $e');
    }
  }

  // ─── Computed ────────────────────────────────────────────────────────────────

  List<_EmpModel> get _filtered {
    if (_searchQuery.isEmpty) return _employees;
    final q = _searchQuery.toLowerCase();
    return _employees
        .where((e) =>
            e.fullName.toLowerCase().contains(q) ||
            e.designation.toLowerCase().contains(q) ||
            e.deptName.toLowerCase().contains(q))
        .toList();
  }

  int get _pendingCount =>
      _employees.where((e) => e.invitationStatus == 'pending').length;

  String get _currentInitials {
    final f = _firstNameCtrl.text.trim();
    final l = _lastNameCtrl.text.trim();
    if (f.isEmpty && l.isEmpty) return '?';
    return '${f.isNotEmpty ? f[0].toUpperCase() : ''}${l.isNotEmpty ? l[0].toUpperCase() : ''}';
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _step != 6
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: AppTheme.textPrimary),
                onPressed: _goBack,
              ),
              title: _appBarTitle(),
            )
          : null,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: KeyedSubtree(
            key: ValueKey('$_step-$_formStep'),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget? _appBarTitle() {
    switch (_step) {
      case 1:
        return Row(children: [
          const Text('Employees',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          if (_employees.isNotEmpty) ...[
            const SizedBox(width: 8),
            _badge('${_employees.length}', AppTheme.primary, Colors.white),
          ],
        ]);
      case 3:
        return const Text('Review Employee',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary));
      case 5:
        return Row(children: [
          const Text('Invite Employees',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          const Spacer(),
          _badge('${_selectedForInvite.length} selected', AppTheme.primary, Colors.white),
        ]);
      default:
        return null;
    }
  }

  Widget _buildBody() {
    switch (_step) {
      case 0:
        return _buildIntroStep();
      case 1:
        return _buildListStep();
      case 2:
        return _buildFormStep();
      case 3:
        return _buildReviewStep();
      case 4:
        return _buildSuccessStep();
      case 5:
        return _buildInviteStep();
      case 6:
        return _buildCompleteStep();
      default:
        return _buildIntroStep();
    }
  }

  // ── Step 0: Intro ─────────────────────────────────────────────────────────────

  Widget _buildIntroStep() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Header Header Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.people_outline_rounded, color: AppTheme.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('SYSTEM-05', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                          SizedBox(height: 2),
                          Text('Employee Setup', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Breadcrumbs
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Organization', style: TextStyle(fontSize: 10, color: AppTheme.textHint)),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.chevron_right, size: 12, color: AppTheme.textHint)),
                      const Text('Admin', style: TextStyle(fontSize: 10, color: AppTheme.textHint)),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.chevron_right, size: 12, color: AppTheme.textHint)),
                      const Text('Departments', style: TextStyle(fontSize: 10, color: AppTheme.textHint)),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.chevron_right, size: 12, color: AppTheme.textHint)),
                      const Text('Employees', style: TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.chevron_right, size: 12, color: AppTheme.textHint)),
                      const Text('Config', style: TextStyle(fontSize: 10, color: AppTheme.textHint)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Card 1: Avatars and Stats
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      children: [
                        // Avatars
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _avatarItem('PS', 'Product\nDesigner', const Color(0xFFDBEAFE), const Color(0xFF2563EB)),
                              _avatarItem('AK', 'Eng.\nManager', const Color(0xFFF3E8FF), const Color(0xFF9333EA)),
                              _avatarItem('RV', 'HR\nExecutive', const Color(0xFFD1FAE5), const Color(0xFF059669)),
                              _avatarItem('NJ', 'Sales\nLead', const Color(0xFFFEF3C7), const Color(0xFFD97706)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Divider with Icon
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            const Divider(color: Color(0xFFF3F4F6), thickness: 2),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.domain_rounded, color: Colors.white, size: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Stats row
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              _statBox('12', 'Engineers', const Color(0xFF2563EB)),
                              const SizedBox(width: 8),
                              _statBox('4', 'Designers', const Color(0xFF0EA5E9)),
                              const SizedBox(width: 8),
                              _statBox('3', 'HR', const Color(0xFF10B981)),
                              const SizedBox(width: 8),
                              _statBox('8', 'Sales', const Color(0xFFF59E0B)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Title and Subtitle
                  const Text('Build Your Workforce', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                  const SizedBox(height: 12),
                  const Text(
                    'Add employees, assign departments, define managers, and prepare your organization for attendance tracking.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  // What you can do card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: const [
                              Icon(Icons.people_outline_rounded, color: AppTheme.primary, size: 18),
                              SizedBox(width: 8),
                              Text('What you can do', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFF3F4F6)),
                        _featureItemNew('Employee Records', 'Maintain complete employee profiles'),
                        const Divider(height: 1, color: Color(0xFFF3F4F6)),
                        _featureItemNew('Reporting Structure', 'Define managers and reporting lines'),
                        const Divider(height: 1, color: Color(0xFFF3F4F6)),
                        _featureItemNew('Attendance Tracking', 'Enable per-employee attendance logs'),
                        const Divider(height: 1, color: Color(0xFFF3F4F6)),
                        _featureItemNew('Leave Management', 'Manage leave balances and requests'),
                        const Divider(height: 1, color: Color(0xFFF3F4F6)),
                        _featureItemNew('Team Collaboration', 'Assign teams, announcements, approvals'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
        // Bottom Actions
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => setState(() => _step = 1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Add Employees', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => OrganizationConfigurationScreen(orgId: widget.orgId, orgName: widget.orgName)),
                    (r) => false,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Skip for Now', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatarItem(String initials, String role, Color bgColor, Color textColor) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: textColor.withValues(alpha: 0.2), width: 2),
          ),
          alignment: Alignment.center,
          child: Text(initials, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
        ),
        const SizedBox(height: 8),
        Text(role, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: AppTheme.textHint, height: 1.2)),
      ],
    );
  }

  Widget _statBox(String value, String label, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textHint)),
          ],
        ),
      ),
    );
  }

  Widget _featureItemNew(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1: Employee List ─────────────────────────────────────────────────────

  Widget _buildListStep() {
    return Column(
      children: [
        // Stats row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Row(
            children: [
              _statPill('${_employees.length}', 'Added', AppTheme.primary),
              const SizedBox(width: 8),
              _statPill('${_departments.length}', 'Depts', const Color(0xFF23A6F0)),
              const SizedBox(width: 8),
              _statPill('$_pendingCount', 'Pending', AppTheme.warning),
            ],
          ),
        ),
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search employees...',
              prefixIcon: const Icon(Icons.search_rounded,
                  size: 20, color: AppTheme.textHint),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 16, color: AppTheme.textHint),
                      onPressed: () =>
                          setState(() { _searchCtrl.clear(); _searchQuery = ''; }),
                    )
                  : null,
            ),
          ),
        ),
        // Employee list
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline_rounded,
                          size: 48,
                          color: AppTheme.textHint.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text(
                        _employees.isEmpty
                            ? 'No employees yet'
                            : 'No results for "$_searchQuery"',
                        style: const TextStyle(
                            fontSize: 14, color: AppTheme.textMuted),
                      ),
                      if (_employees.isEmpty) ...[
                        const SizedBox(height: 4),
                        const Text('Tap "+ Add Employee" to create one',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textHint)),
                      ],
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _empListTile(_filtered[i]),
                ),
        ),
        // Bottom bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Column(
            children: [
              OutlinedButton.icon(
                onPressed: () => _openAddForm(),
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text('Add Employee',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 10),
              _primaryBtn(
                'Continue',
                _employees.isEmpty ? null : () => setState(() => _step = 5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _empListTile(_EmpModel emp) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          _avatarCircle(emp.initials, emp.color, 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emp.fullName,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text('${emp.designation} · ${emp.deptName}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textHint)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _miniTag(emp.role,
                        emp.role == 'Manager'
                            ? const Color(0xFFE8E9FB)
                            : const Color(0xFFF3F4F6),
                        emp.role == 'Manager'
                            ? AppTheme.primary
                            : AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    _miniTag(emp.employeeId, const Color(0xFFF3F4F6),
                        AppTheme.textMuted),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                size: 18, color: AppTheme.textSecondary),
            onPressed: () => _openAddForm(existing: emp),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Add / Edit Employee Form ──────────────────────────────────────────

  Widget _buildFormStep() {
    final title = _formStep == 1
        ? 'Basic Information'
        : _formStep == 2
            ? 'Work Information'
            : 'Personal Information';

    return _padded(_scrollable(children: [
      // Header
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 12),
            child: GestureDetector(
              onTap: () {
                if (_formStep > 1) {
                  setState(() => _formStep--);
                } else {
                  _goBack();
                }
              },
              child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('STEP $_formStep OF 3', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textHint, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      // Progress Bar
      _formProgressBar(),
      const SizedBox(height: 32),
      // Form content
      if (_formStep == 1) _buildBasicInfoForm(),
      if (_formStep == 2) _buildWorkInfoForm(),
      if (_formStep == 3) _buildPersonalInfoForm(),
      const SizedBox(height: 32),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _goNextFormStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5C5CFF),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('Continue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton(
          onPressed: () {
            if (_formStep > 1) {
              setState(() => _formStep--);
            } else {
              _goBack();
            }
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textPrimary,
            side: const BorderSide(color: Color(0xFFE5E7EB)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('Back', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ),
    ]));
  }

  Widget _formProgressBar() {
    return Row(
      children: [
        _progCircle(1, _formStep == 1, _formStep > 1),
        _progLine(_formStep > 1),
        _progCircle(2, _formStep == 2, _formStep > 2),
        _progLine(_formStep > 2),
        _progCircle(3, _formStep == 3, false),
      ],
    );
  }

  Widget _progCircle(int n, bool active, bool done) {
    if (done) {
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF5C5CFF),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
      );
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: active ? const Color(0xFF5C5CFF) : const Color(0xFFE5E7EB),
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: Text('$n',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: active ? const Color(0xFF5C5CFF) : AppTheme.textHint)),
    );
  }

  Widget _progLine(bool active) => Expanded(
        child: Container(
            height: 2,
            color: active ? const Color(0xFF5C5CFF) : const Color(0xFFF3F4F6)),
      );

  // ─── Basic Info Form ─────────────────────────────────────────────────────────

  Widget _buildBasicInfoForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar Section
        Row(
          children: [
            Stack(
              children: [
                _avatarCircle(_currentInitials, const Color(0xFF5C5CFF), 64),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.edit_outlined, size: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_firstNameCtrl.text.isEmpty && _lastNameCtrl.text.isEmpty ? 'New Employee' : '${_firstNameCtrl.text} ${_lastNameCtrl.text}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  const Text('JPG, PNG up to 5MB\nRecommended: 400x400px', style: TextStyle(fontSize: 10, color: AppTheme.textHint, height: 1.3)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {}, // Remove logic
                    child: Row(
                      children: const [
                        Icon(Icons.close_rounded, size: 12, color: Color(0xFFEF4444)),
                        SizedBox(width: 4),
                        Text('Remove photo', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444), fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _sectionLabel('PERSONAL DETAILS'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _inputField(_firstNameCtrl, 'First Name *', Icons.person_outline_rounded,
                  onChanged: (_) => setState(() {})),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _inputField(_lastNameCtrl, 'Last Name *', null,
                  onChanged: (_) => setState(() {})),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _inputField(_emailCtrl, 'Work Email *', Icons.email_outlined,
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 16),
        _inputField(_phoneCtrl, 'Phone Number *', Icons.phone_outlined,
            keyboardType: TextInputType.phone),
        const SizedBox(height: 16),
        _inputField(_altPhoneCtrl, 'Alternate Phone', Icons.phone_outlined,
            keyboardType: TextInputType.phone),
      ],
    );
  }

  // ─── Work Info Form ──────────────────────────────────────────────────────────

  Widget _buildWorkInfoForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('ROLE & IDENTITY'),
        const SizedBox(height: 16),
        // Employee ID + Joining date
        Row(children: [
          Expanded(
            child: _inputField(
              TextEditingController(text: _empIdValue),
              'Employee ID *',
              Icons.numbers_rounded,
              onChanged: (v) => _empIdValue = v,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: _pickJoiningDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 18, color: AppTheme.textHint),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Joining Date *',
                          style: TextStyle(fontSize: 10, color: AppTheme.textHint)),
                      const SizedBox(height: 2),
                      Text(
                        _joiningDate != null
                            ? DateFormat('dd MMM yyyy').format(_joiningDate!)
                            : '',
                        style: TextStyle(
                          fontSize: 13,
                          color: _joiningDate != null
                              ? AppTheme.textPrimary
                              : AppTheme.textHint,
                          fontWeight: _joiningDate != null
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        // Department
        _loadingData
            ? _loadingField('Department')
            : _dropdownField(
                label: 'Department *',
                icon: Icons.domain_rounded,
                value: _selectedDeptId,
                items: _departments.map((d) => d.id).toList(),
                labels: _departments.map((d) => d.name).toList(),
                onChanged: (v) {
                  if (v == null) return;
                  final dept = _departments.firstWhere((d) => d.id == v,
                      orElse: () => _departments.first);
                  setState(() {
                    _selectedDeptId = dept.id;
                    _selectedDeptName = dept.name;
                  });
                },
              ),
        const SizedBox(height: 16),
        _inputField(_designationCtrl, 'Designation *', Icons.work_outline_rounded),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: _dropdownStrField(
              label: 'Role *',
              icon: Icons.shield_outlined,
              value: _selectedRole,
              items: _roles,
              onChanged: (v) => setState(() => _selectedRole = v!),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _dropdownStrField(
              label: 'Emp Type *',
              icon: null, // The icon seems missing or hard to tell, but it's empty in UI
              value: _selectedEmpType,
              items: _empTypes,
              onChanged: (v) => setState(() => _selectedEmpType = v!),
            ),
          ),
        ]),
        const SizedBox(height: 24),
        _sectionLabel('LOCATION & REPORTING'),
        const SizedBox(height: 16),
        _dropdownStrField(
          label: 'Location *',
          icon: Icons.location_on_outlined,
          value: _selectedLocation,
          items: const ['Bengaluru HQ', 'Mumbai Office', 'Delhi Office', 'Remote'], // Need actual locations later or make it text
          onChanged: (v) => setState(() => _selectedLocation = v!),
        ),
        const SizedBox(height: 16),
        // Reporting manager
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(children: [
            const Icon(Icons.people_outline_rounded, size: 20, color: AppTheme.textHint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Reporting Manager', style: TextStyle(fontSize: 10, color: AppTheme.textHint)),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _selectedManagerId,
                      isExpanded: true,
                      isDense: true,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500),
                      icon: const Icon(Icons.expand_more_rounded,
                          size: 18, color: AppTheme.textHint),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('No reporting manager',
                              style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                        ),
                        ..._managers.map((m) => DropdownMenuItem<String?>(
                              value: m.id,
                              child: Text(
                                  '${m.name} (${m.role == 'admin' ? 'Manager' : m.role})',
                                  style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                            )),
                        ..._employees
                            .where((e) =>
                                e.role == 'Manager' &&
                                e.id != _editingEmp?.id)
                            .map((e) => DropdownMenuItem<String?>(
                                  value: e.id,
                                  child: Text('${e.fullName} (Manager)',
                                      style: const TextStyle(fontSize: 13)),
                                )),
                      ],
                      onChanged: (v) {
                        String? name;
                        if (v != null) {
                          final mgr = _managers.where((m) => m.id == v).firstOrNull;
                          if (mgr != null) {
                            name = '${mgr.name} (${mgr.role == 'admin' ? 'Manager' : mgr.role})';
                          } else {
                            final emp = _employees.where((e) => e.id == v).firstOrNull;
                            if (emp != null) name = '${emp.fullName} (Manager)';
                          }
                        }
                        setState(() {
                          _selectedManagerId = v;
                          _selectedManagerName = name;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ],
    );
  }

  // ─── Personal Info Form ──────────────────────────────────────────────────────

  Widget _buildPersonalInfoForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('PERSONAL DETAILS', isOptional: true),
        const SizedBox(height: 16),
        // DOB
        GestureDetector(
          onTap: _pickDob,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 20, color: AppTheme.textHint),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Date of Birth',
                      style:
                          TextStyle(fontSize: 10, color: AppTheme.textHint)),
                  const SizedBox(height: 2),
                  Text(
                    _dob != null
                        ? DateFormat('dd MMM yyyy').format(_dob!)
                        : '',
                    style: TextStyle(
                      fontSize: 13,
                      color: _dob != null
                          ? AppTheme.textPrimary
                          : AppTheme.textHint,
                      fontWeight:
                          _dob != null ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: _dropdownStrField(
              label: 'Gender',
              icon: Icons.person_outline_rounded,
              value: _selectedGender,
              items: _genders,
              onChanged: (v) => setState(() => _selectedGender = v!),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _dropdownStrField(
              label: 'Marital',
              icon: Icons.favorite_border_rounded,
              value: _selectedMarital,
              items: _maritalStatuses,
              onChanged: (v) => setState(() => _selectedMarital = v!),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _dropdownStrField(
          label: 'Blood Group',
          icon: Icons.favorite_border_rounded,
          value: _selectedBloodGroup,
          items: _bloodGroups,
          onChanged: (v) => setState(() => _selectedBloodGroup = v!),
        ),
        const SizedBox(height: 24),
        _sectionLabel('EMERGENCY CONTACT', isOptional: true),
        const SizedBox(height: 16),
        _inputField(_emergencyNameCtrl, 'Contact Name', Icons.person_outline_rounded),
        const SizedBox(height: 16),
        _inputField(_emergencyPhoneCtrl, 'Contact Phone', Icons.phone_outlined,
            keyboardType: TextInputType.phone),
        const SizedBox(height: 24),
        _sectionLabel('GOVERNMENT ID', isOptional: true),
        const SizedBox(height: 16),
        _dropdownStrField(
          label: 'ID Type',
          icon: Icons.credit_card_outlined,
          value: _selectedGovtIdType,
          items: _govtIdTypes,
          onChanged: (v) => setState(() => _selectedGovtIdType = v!),
        ),
        const SizedBox(height: 16),
        _inputField(_govtIdNumberCtrl, 'ID Number', Icons.numbers_rounded),
        const SizedBox(height: 24),
        _sectionLabel('ADDRESS', isOptional: true),
        const SizedBox(height: 16),
        _inputField(_homeAddressCtrl, 'Home Address', Icons.location_on_outlined,
            maxLines: 2),
      ],
    );
  }

  // ── Step 3: Review ────────────────────────────────────────────────────────────

  Widget _buildReviewStep() {
    final isEdit = _editingEmp != null;
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final fullName = '$firstName $lastName'.trim();
    final initials = '${firstName.isNotEmpty ? firstName[0].toUpperCase() : ''}${lastName.isNotEmpty ? lastName[0].toUpperCase() : ''}';
    final color = _editingEmp?.color ?? _nextColor();

    return _padded(_scrollable(children: [
      const Text('Verify the information before creating the employee record.',
          style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
      const SizedBox(height: 16),
      // Employee preview card
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6EAF2)),
        ),
        child: Row(children: [
          _avatarCircle(initials.isEmpty ? '?' : initials, color, 50),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(fullName.isEmpty ? 'Employee' : fullName,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 2),
              Text(_designationCtrl.text.trim().isEmpty
                      ? 'Designation'
                      : _designationCtrl.text.trim(),
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 6),
              Row(children: [
                _miniTag(_selectedRole ?? '', const Color(0xFFE8E9FB), AppTheme.primary),
                const SizedBox(width: 6),
                _miniTag(_empIdValue, const Color(0xFFF3F4F6), AppTheme.textMuted),
              ]),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
            onPressed: () => setState(() { _step = 2; _formStep = 1; }),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      // Basic Info
      _reviewSection('Basic Information', onEdit: () => setState(() { _step = 2; _formStep = 1; }), rows: [
        _reviewRow('Full Name', fullName),
        _reviewRow('Work Email', _emailCtrl.text.trim()),
        _reviewRow('Phone', _phoneCtrl.text.trim()),
        _reviewRow('Joining Date', _joiningDate != null
            ? DateFormat('dd MMMM yyyy').format(_joiningDate!)
            : '-'),
      ]),
      const SizedBox(height: 12),
      // Work Info
      _reviewSection('Work Information', onEdit: () => setState(() { _step = 2; _formStep = 2; }), rows: [
        _reviewRow('Employee ID', _empIdValue),
        _reviewRow('Department', _selectedDeptName),
        _reviewRow('Designation', _designationCtrl.text.trim()),
        _reviewRow('Role', _selectedRole ?? '-'),
        _reviewRow('Reporting Manager', _selectedManagerName ?? 'Not assigned'),
        _reviewRow('Location', _selectedLocation ?? '-'),
      ]),
      const SizedBox(height: 12),
      // Personal Info
      _reviewSection('Personal Information', onEdit: () => setState(() { _step = 2; _formStep = 3; }), rows: [
        _reviewRow('Date of Birth', _dob != null
            ? DateFormat('dd MMMM yyyy').format(_dob!)
            : '-'),
        _reviewRow('Gender', _selectedGender ?? '-'),
        _reviewRow('Blood Group', _selectedBloodGroup ?? '-'),
        _reviewRow('Emergency Contact', _emergencyNameCtrl.text.trim().isNotEmpty
            ? '${_emergencyNameCtrl.text.trim()} · ${_emergencyPhoneCtrl.text.trim()}'
            : '-'),
        _reviewRow('Govt ID', _govtIdNumberCtrl.text.trim().isNotEmpty
            ? '${_selectedGovtIdType ?? '-'} · ${_govtIdNumberCtrl.text.trim()}'
            : '-'),
      ]),
      const Spacer(),
      _primaryBtn(
        _isSubmitting
            ? (isEdit ? 'Updating…' : 'Creating…')
            : (isEdit ? 'Update Employee' : 'Create Employee'),
        _isSubmitting ? null : (isEdit ? _updateEmployee : _createEmployee),
      ),
      const SizedBox(height: 10),
      _secondaryBtn('Back', _goBack),
    ]));
  }

  // ── Step 4: Employee Added Successfully ───────────────────────────────────────

  Widget _buildSuccessStep() {
    final emp = _lastAddedEmp;
    if (emp == null) return const SizedBox();

    return _padded(_scrollable(crossAxisAlignment: CrossAxisAlignment.center, children: [
      const Spacer(),
      // Avatar with check
      Stack(
        children: [
          _avatarCircle(emp.initials, emp.color, 80),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppTheme.success,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.check_rounded,
                  size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      const Text(
        'Employee Added Successfully',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            height: 1.2),
      ),
      const SizedBox(height: 8),
      const Text(
        'The employee record has been created and is ready for invitation.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.5),
      ),
      const SizedBox(height: 20),
      // Employee summary card
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE6EAF2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _avatarCircle(emp.initials, emp.color, 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(emp.fullName,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  Text(emp.designation,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMuted)),
                ]),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Pending Invitation',
                    style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFFB45309),
                        fontWeight: FontWeight.w600)),
              ),
            ]),
            const Divider(height: 20),
            _successInfoRow(Icons.tag_rounded, 'Employee ID', emp.employeeId),
            const SizedBox(height: 8),
            _successInfoRow(Icons.account_tree_outlined, 'Department', emp.deptName),
            const SizedBox(height: 8),
            _successInfoRow(Icons.shield_outlined, 'Role', emp.role),
            if (emp.joiningDate != null) ...[
              const SizedBox(height: 8),
              _successInfoRow(Icons.calendar_today_outlined, 'Joining',
                  DateFormat('dd MMMM yyyy').format(emp.joiningDate!)),
            ],
            const Divider(height: 20),
            // Send Invitation row
            GestureDetector(
              onTap: () => setState(() => _step = 5),
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F1FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.mail_outline_rounded,
                      size: 18, color: AppTheme.primary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Send Invitation',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600)),
                    Text('Employee needs to activate their account',
                        style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.primary, size: 20),
              ]),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      const Spacer(),
      _primaryBtn('Invite Employee', () => setState(() => _step = 5)),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: () => _openAddForm(),
          child: const Text('Add Another Employee',
              style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500)),
        ),
      ),
    ]));
  }

  // ── Step 5: Invite Employees ──────────────────────────────────────────────────

  Widget _buildInviteStep() {
    final selected = _selectedForInvite.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'Employees will receive an email invitation to activate their accounts.',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.5),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Text('${_employees.length} employees',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (_selectedForInvite.length == _employees.length) {
                      _selectedForInvite.clear();
                    } else {
                      _selectedForInvite.addAll(_employees.map((e) => e.id));
                    }
                  });
                },
                child: Text(
                  _selectedForInvite.length == _employees.length
                      ? 'Deselect All'
                      : 'Select All',
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ]),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _employees.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final emp = _employees[i];
              final isSelected = _selectedForInvite.contains(emp.id);
              return GestureDetector(
                onTap: () => setState(() {
                  if (isSelected) {
                    _selectedForInvite.remove(emp.id);
                  } else {
                    _selectedForInvite.add(emp.id);
                  }
                }),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primary
                          : const Color(0xFFE5E7EB),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(children: [
                    // Checkbox
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary
                            : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primary
                              : const Color(0xFFD1D5DB),
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    _avatarCircle(emp.initials, emp.color, 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(emp.fullName,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary)),
                          Text('${emp.designation} · ${emp.deptName}',
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textHint)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: emp.invitationStatus == 'sent'
                            ? AppTheme.successLight
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        emp.invitationStatus == 'sent' ? 'Sent' : 'Pending',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: emp.invitationStatus == 'sent'
                              ? const Color(0xFF15803D)
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: _primaryBtn(
            _isSendingInvitations
                ? 'Sending…'
                : 'Send Invitations ($selected)',
            (_isSendingInvitations || selected == 0)
                ? null
                : _sendInvitations,
          ),
        ),
      ],
    );
  }

  // ── Step 6: Workforce Setup Complete ──────────────────────────────────────────

  Widget _buildCompleteStep() {
    return _padded(_scrollable(crossAxisAlignment: CrossAxisAlignment.center, children: [
      const Spacer(),
      Container(
        width: 80,
        height: 80,
        decoration: const BoxDecoration(
          color: Color(0xFFDCFCE7),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.people_alt_rounded,
            color: Color(0xFF16A34A), size: 38),
      ),
      const SizedBox(height: 20),
      const Text(
        'Workforce Setup\nComplete',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            height: 1.2),
      ),
      const SizedBox(height: 8),
      const Text(
        'Your employees have been added. Next, configure holidays, shifts, attendance, and leave policies.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: AppTheme.textMuted, height: 1.5),
      ),
      const SizedBox(height: 24),
      // Employees added
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE6EAF2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('Employees Added',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              const Spacer(),
              _badge('${_employees.length}', AppTheme.primary, Colors.white),
            ]),
            const SizedBox(height: 12),
            ..._employees.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    _avatarCircle(e.initials, e.color, 32),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.fullName,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary)),
                          Text(e.deptName,
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textHint)),
                        ],
                      ),
                    ),
                    const Icon(Icons.check_circle_rounded,
                        size: 18, color: AppTheme.success),
                  ]),
                )),
          ],
        ),
      ),
      const SizedBox(height: 16),
      // Setup Progress
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE6EAF2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('Setup Progress',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              const Spacer(),
              const Text('4 of 8 complete',
                  style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
            ]),
            const SizedBox(height: 12),
            _progressItem(true, false, 'Organization Created'),
            const SizedBox(height: 8),
            _progressItem(true, false, 'Administrator Created'),
            const SizedBox(height: 8),
            _progressItem(true, false, 'Departments Created'),
            const SizedBox(height: 8),
            _progressItem(true, false, 'Employees Added'),
            const SizedBox(height: 8),
            _progressItem(false, true, 'Holidays Setup'),
            const SizedBox(height: 8),
            _progressItem(false, false, 'Shift Setup'),
            const SizedBox(height: 8),
            _progressItem(false, false, 'Attendance Policy'),
            const SizedBox(height: 8),
            _progressItem(false, false, 'Leave Policy'),
          ],
        ),
      ),
      const SizedBox(height: 16),
      // Next step banner
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F1FF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(children: [
          Icon(Icons.settings_outlined, color: AppTheme.primary),
          SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Next: Organization Configuration',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: 2),
              Text('Holidays, shifts, attendance & leave policies',
                  style: TextStyle(fontSize: 11, color: AppTheme.primary)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: AppTheme.primary),
        ]),
      ),
      const Spacer(),
      _primaryBtn(
        'Continue to Configuration',
        () => Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => OrganizationConfigurationScreen(orgId: widget.orgId, orgName: widget.orgName)),
          (r) => false,
        ),
      ),
    ]));
  }

  // ─── Shared Helpers ───────────────────────────────────────────────────────────

  Widget _padded(Widget child) =>
      Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), child: child);

  Widget _scrollable({
    required List<Widget> children,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
  }) {
    return LayoutBuilder(
      builder: (ctx, constraints) => SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
                crossAxisAlignment: crossAxisAlignment, children: children),
          ),
        ),
      ),
    );
  }

  Widget _avatarCircle(String initials, Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w700)),
    );
  }

  Widget _miniTag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
    );
  }

  Widget _statPill(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: color.withValues(alpha: 0.7))),
        ]),
      ),
    );
  }

  Widget _breadcrumb(List<String> steps, int activeIndex) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: steps.asMap().entries.map((e) {
        final isActive = e.key == activeIndex;
        final isPast = e.key < activeIndex;
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Text(e.value,
              style: TextStyle(
                  fontSize: 11,
                  color: isActive ? AppTheme.primary : (isPast ? AppTheme.textPrimary : AppTheme.textHint),
                  fontWeight: isActive ? FontWeight.w700 : (isPast ? FontWeight.w600 : FontWeight.w500))),
          if (e.key != steps.length - 1) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                size: 12, color: AppTheme.textHint),
            const SizedBox(width: 4),
          ],
        ]);
      }).toList(),
      ),
    );
  }

  Widget _sectionLabel(String label, {bool isOptional = false}) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textHint,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
        if (isOptional) ...[
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Text('Optional', style: TextStyle(fontSize: 10, color: AppTheme.textHint, fontWeight: FontWeight.w500)),
          ),
        ],
      ],
    );
  }

  Widget _featureItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        const Icon(Icons.check_circle_rounded, size: 18, color: AppTheme.success),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            Text(subtitle,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ]),
        ),
      ]),
    );
  }


  Widget _inputField(
    TextEditingController ctrl,
    String label,
    IconData? icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 20, color: AppTheme.textHint) : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }


  Widget _loadingField(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(children: [
        const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTheme.primary)),
        const SizedBox(width: 10),
        Text('Loading $label…',
            style: const TextStyle(fontSize: 13, color: AppTheme.textHint)),
      ]),
    );
  }

  Widget _dropdownField({
    required String label,
    IconData? icon,
    String? value,
    required List<String> items,
    required List<String> labels,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: items.contains(value) ? value : null,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 20, color: AppTheme.textHint) : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      items: items
          .asMap()
          .entries
          .map((e) => DropdownMenuItem<String>(
                value: e.value,
                child: Text(labels[e.key],
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14)),
              ))
          .toList(),
    );
  }

  Widget _dropdownStrField({
    required String label,
    IconData? icon,
    String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: (value != null && items.contains(value)) ? value : null,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 20, color: AppTheme.textHint) : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      items: items
          .map((item) => DropdownMenuItem<String>(
                value: item,
                child: Text(item, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
              ))
          .toList(),
    );
  }

  Widget _yellowInfo(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF9C3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDE047)),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded,
            size: 14, color: Color(0xFFCA8A04)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF92400E), height: 1.4)),
        ),
      ]),
    );
  }

  Widget _reviewSection(String title,
      {required VoidCallback onEdit, required List<Widget> rows}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Row(children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
              ),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 13),
                label: const Text('Edit',
                    style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ]),
          ),
          const Divider(height: 1),
          ...rows,
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }

  Widget _successInfoRow(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 15, color: AppTheme.textHint),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
      const Spacer(),
      Text(value,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary)),
    ]);
  }

  Widget _progressItem(bool done, bool isNext, String label) {
    return Row(children: [
      Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done
              ? AppTheme.success
              : isNext
                  ? AppTheme.primary
                  : const Color(0xFFE5E7EB),
        ),
        alignment: Alignment.center,
        child: done
            ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
            : isNext
                ? const Icon(Icons.chevron_right_rounded,
                    size: 12, color: Colors.white)
                : null,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: done
                ? AppTheme.textPrimary
                : isNext
                    ? AppTheme.primary
                    : AppTheme.textHint,
            fontWeight: (done || isNext) ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
      if (isNext)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F1FF),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text('NEXT',
              style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700)),
        ),
      if (done)
        const Icon(Icons.check_circle_rounded,
            size: 16, color: AppTheme.success),
    ]);
  }

  Widget _primaryBtn(String label, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFB0B2FF),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _secondaryBtn(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.textPrimary,
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ─── Date pickers ─────────────────────────────────────────────────────────────

  Future<void> _pickJoiningDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _joiningDate = picked);
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1995, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }
}
