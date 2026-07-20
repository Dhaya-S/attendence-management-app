import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:attendance_app/screens/department_setup_screen.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/message_helper.dart';

class AdminSetupScreen extends StatefulWidget {
  final Map<String, dynamic> organizationData;

  const AdminSetupScreen({super.key, required this.organizationData});

  @override
  State<AdminSetupScreen> createState() => _AdminSetupScreenState();
}

class _AdminSetupScreenState extends State<AdminSetupScreen> {
  // 0=intro, 1=basic, 2=work, 3=personal, 4=review, 5=success
  int _step = 0;
  bool _isSubmitting = false;

  // â”€â”€ Step 1: Basic Info â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();


  // â”€â”€ Step 2: Work Info â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String _employeeId = '';
  String? _department;
  final _locationCtrl = TextEditingController();
  String? _employeeType;

  // â”€â”€ Step 3: Personal Info (optional) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  DateTime? _dob;
  String? _gender;
  String? _maritalStatus;
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();
  String? _govtIdType;
  final _govtIdNumberCtrl = TextEditingController();
  final _personalAddressCtrl = TextEditingController();

  // â”€â”€ Results â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String? _createdOrgId;

  // â”€â”€ Dropdown Options â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const _departments = [
    'Engineering',
    'Human Resources',
    'Finance',
    'Sales',
    'Operations',
    'Marketing',
    'Design',
    'Product',
    'Legal',
  ];
  static const _employeeTypes = ['Permanent', 'Contract', 'Part-time', 'Intern'];
  static const _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];
  static const _maritalStatuses = ['Single', 'Married', 'Divorced', 'Widowed'];
  static const _govtIdTypes = [
    'Aadhaar Card',
    'PAN Card',
    'Passport',
    "Driver's License",
  ];

  @override
  void initState() {
    super.initState();
    _generateEmployeeId();
    
    // Pre-fill location from org city
    final city = widget.organizationData['city'] as String? ?? '';
    _locationCtrl.text = city.isNotEmpty ? '$city HQ' : '';

    // Pre-fill from org contact info
    final contactPerson = widget.organizationData['contactPerson'] as String? ?? '';
    final contactEmail = widget.organizationData['contactEmail'] as String? ?? '';
    final contactNumber = widget.organizationData['contactNumber'] as String? ?? '';
    
    final names = contactPerson.trim().split(' ');
    if (names.isNotEmpty) {
      _firstNameCtrl.text = names.first;
      if (names.length > 1) {
        _lastNameCtrl.text = names.skip(1).join(' ');
      }
    }
    _emailCtrl.text = FirebaseAuth.instance.currentUser?.email ?? contactEmail;
    _phoneCtrl.text = contactNumber;
  }

  void _generateEmployeeId() {
    final orgName = widget.organizationData['companyName'] as String? ?? 'ORG';
    final initials = orgName
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .take(2)
        .join();
    setState(() => _employeeId = '$initials-ADM-001');
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();

    _locationCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _govtIdNumberCtrl.dispose();
    _personalAddressCtrl.dispose();
    super.dispose();
  }

  // â”€â”€ Validation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  bool _validateStep() {
    switch (_step) {
      case 1:
        if (_firstNameCtrl.text.trim().isEmpty || _lastNameCtrl.text.trim().isEmpty) {
          MessageHelper.showWarning(context, 'Please enter first and last name.');
          return false;
        }
        if (!_emailCtrl.text.trim().contains('@')) {
          MessageHelper.showWarning(context, 'Please enter a valid email address.');
          return false;
        }
        if (_phoneCtrl.text.trim().isEmpty) {
          MessageHelper.showWarning(context, 'Please enter a phone number.');
          return false;
        }
        return true;
      case 2:
        if (_department == null || _locationCtrl.text.trim().isEmpty || _employeeType == null) {
          MessageHelper.showWarning(context, 'Please fill all required work details.');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _goNext() {
    if (!_validateStep()) return;
    setState(() => _step++);
  }

  void _goBack() {
    if (_step <= 1) {
      Navigator.pop(context);
      return;
    }
    setState(() => _step--);
  }

  // â”€â”€ Create Admin Account â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _createAdminAccount() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final orgId = widget.organizationData['companyId'] as String;
      final now = FieldValue.serverTimestamp();
      final fullName = '${ _firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}';

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        MessageHelper.showError(context, 'You must be signed in to complete setup.');
        setState(() => _isSubmitting = false);
        return;
      }
      
      final uid = currentUser.uid;
      final email = currentUser.email ?? _emailCtrl.text.trim().toLowerCase();

      final orgData = {
        ...widget.organizationData,
        'orgId': orgId,
        'setupStep': 'departments',
        'createdAt': now,
        'updatedAt': now,
      };
      await FirestoreService.orgDoc(orgId).set(orgData);

      await FirestoreService.orgMemberDoc(orgId, uid).set({
        'uid': uid,
        'email': email,
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'fullName': fullName,
        'employeeId': _employeeId,
        'role': 'admin',
        'department': _department ?? '',
        'location': _locationCtrl.text.trim(),
        'employeeType': _employeeType ?? '',
        'reportingManager': null,
        'dob': _dob?.toIso8601String(),
        'gender': _gender ?? '',
        'maritalStatus': _maritalStatus ?? '',
        'emergencyContact': {
          'name': _emergencyNameCtrl.text.trim(),
          'phone': _emergencyPhoneCtrl.text.trim(),
        },
        'govtIdType': _govtIdType ?? '',
        'govtIdNumber': _govtIdNumberCtrl.text.trim(),
        'personalAddress': _personalAddressCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'workEmail': email,
        'status': 'active',
        'orgId': orgId,
        'companyId': orgId,
        'createdAt': now,
        'updatedAt': now,
      });

      await FirestoreService.approvedUserDoc(email).set({
        'email': email,
        'role': 'admin',
        'orgId': orgId,
        'companyId': orgId,
        'uid': uid,
        'status': 'active',
        'createdAt': now,
      });

      AppSession().populate(
        uid: uid,
        email: email,
        role: 'admin', 
        companyId: orgId,
        companyName: widget.organizationData['companyName'] as String?,
        userName: fullName,
      );

      if (!mounted) return;
      setState(() {
        _createdOrgId = orgId;
        _isSubmitting = false;
        _step = 5; 
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      MessageHelper.showError(context, 'Error creating account: $e');
    }
  }

  // â”€â”€ Computed Getters â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String get _fullName =>
      '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim();

  String get _initials {
    final f = _firstNameCtrl.text.trim();
    final l = _lastNameCtrl.text.trim();
    final f1 = f.isNotEmpty ? f[0].toUpperCase() : '';
    final l1 = l.isNotEmpty ? l[0].toUpperCase() : '';
    final res = '$f1$l1';
    return res.isEmpty ? '?' : res;
  }

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _step < 5
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 18),
                onPressed: _goBack,
              ),
            )
          : null,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(
            key: ValueKey(_step),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case 0:
        return _buildIntroStep();
      case 1:
        return _buildBasicInfoStep();
      case 2:
        return _buildWorkInfoStep();
      case 3:
        return _buildPersonalInfoStep();
      case 4:
        return _buildReviewStep();
      case 5:
        return _buildSuccessStep();
      default:
        return _buildIntroStep();
    }
  }

  Widget _buildScrollableStep({
    required List<Widget> children,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: crossAxisAlignment,
                  children: children,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // â”€â”€ Step 0: Intro â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildIntroStep() {
    return _buildScrollableStep(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F1FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shield_outlined, color: AppTheme.primary, size: 18),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SYSTEM-03', style: TextStyle(fontSize: 10, color: AppTheme.textHint, fontWeight: FontWeight.w700)),
                Text('First Admin Setup', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _systemBreadcrumb(['Organization', 'Admin', 'Departments', 'Config'], 1),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF0F0F0)),
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _fullName.isEmpty ? 'Administrator' : _fullName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.shield_outlined, size: 12, color: AppTheme.primary),
                  SizedBox(width: 4),
                  Text('Administrator', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: const [
                  Expanded(child: _MiniStatBox(label: 'Engineering', value: '48')),
                  SizedBox(width: 10),
                  Expanded(child: _MiniStatBox(label: 'HR', value: '12')),
                  SizedBox(width: 10),
                  Expanded(child: _MiniStatBox(label: 'Finance', value: '8')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Create Your Administrator\nAccount',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'This account will manage employees, departments, attendance, leave policies, and all organization settings.',
          style: TextStyle(fontSize: 14, color: AppTheme.textMuted, height: 1.5),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Administrator Access',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
              child: const Text('Full Access', style: TextStyle(fontSize: 10, color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _featureRow(Icons.people_alt_outlined, 'Employee Management', 'Add, edit, manage all employees'),
        _featureRow(Icons.account_tree_outlined, 'Department Management', 'Create and manage departments'),
        _featureRow(Icons.access_time_rounded, 'Attendance Management', 'Configure policies and tracking'),
        _featureRow(Icons.settings_outlined, 'Organization Settings', 'Manage workspace configuration'),
        _featureRow(Icons.policy_outlined, 'Policies & Configuration', 'Leave, shifts, and work rules'),
        const Spacer(),
        const SizedBox(height: 20),
        _primaryBtn('Continue', () => setState(() => _step = 1)),
      ],
    );
  }

  // â”€â”€ Step 1: Basic Information â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildBasicInfoStep() {
    return _buildScrollableStep(
      children: [
        _stepHeader('Basic Information', 1),
        const SizedBox(height: 20),
        _buildProgressIndicator(1),
        const SizedBox(height: 32),
        Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fullName.isEmpty ? 'Administrator' : _fullName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  const Text('JPG, PNG up to 5MB\nRecommended: 400Ã—400px', style: TextStyle(fontSize: 11, color: AppTheme.textHint, height: 1.4)),
                  const SizedBox(height: 4),
                  const Text('+ Remove photo', style: TextStyle(fontSize: 11, color: AppTheme.danger, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        const Text(
          'PERSONAL DETAILS',
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textHint,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _inputField(_firstNameCtrl, 'First Name *', Icons.person_outline_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _inputField(_lastNameCtrl, 'Last Name *', null)),
          ],
        ),
        const SizedBox(height: 16),
        _inputField(_emailCtrl, 'Work Email *', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFEDD5)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFEA580C)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'The work email will be used as the login credential for this administrator account.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFC2410C), height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _inputField(_phoneCtrl, 'Phone Number *', Icons.phone_outlined, keyboardType: TextInputType.phone),
        const Spacer(),
        const SizedBox(height: 20),
        _primaryBtn('Continue', _goNext),
        const SizedBox(height: 10),
        _secondaryBtn('Back', _goBack),
      ],
    );
  }

  // â”€â”€ Step 2: Work Information â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildWorkInfoStep() {
    return _buildScrollableStep(
      children: [
        _stepHeader('Work Information', 2),
        const SizedBox(height: 20),
        _buildProgressIndicator(2),
        const SizedBox(height: 32),
        const Text('POSITION & IDENTITY', style: TextStyle(fontSize: 11, color: AppTheme.textHint, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 12),
        _inputField(TextEditingController(text: _employeeId), 'Employee ID *', Icons.tag_rounded, readOnly: true),
        const SizedBox(height: 16),
        _dropdownField(
          label: 'Department *',
          icon: Icons.account_tree_outlined,
          value: _department,
          items: _departments,
          onChanged: (v) => setState(() => _department = v),
        ),
        const SizedBox(height: 16),
        _inputField(_locationCtrl, 'Location *', Icons.location_on_outlined),
        const SizedBox(height: 16),
        _dropdownField(
          label: 'Employee Type *',
          icon: Icons.person_outline_rounded,
          value: _employeeType,
          items: _employeeTypes,
          onChanged: (v) => setState(() => _employeeType = v),
        ),
        const SizedBox(height: 24),
        const Text('ROLE & REPORTING', style: TextStyle(fontSize: 11, color: AppTheme.textHint, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 12),
        // Role (read only fake field)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, size: 20, color: AppTheme.textHint),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Role', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                    SizedBox(height: 2),
                    Text('Administrator', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const Text('System', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F1FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'The Administrator role grants full system access and is automatically assigned to the first account.',
                  style: TextStyle(fontSize: 12, color: AppTheme.primary, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 20, color: AppTheme.textHint),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reporting Manager', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                    SizedBox(height: 2),
                    Text('â€”', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const Icon(Icons.expand_more_rounded, size: 20, color: AppTheme.textHint),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: const [
            Icon(Icons.check_rounded, size: 14, color: AppTheme.textHint),
            SizedBox(width: 6),
            Text('No reporting manager â€” this is a top-level account', style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
          ],
        ),
        const Spacer(),
        const SizedBox(height: 20),
        _primaryBtn('Continue', _goNext),
        const SizedBox(height: 10),
        _secondaryBtn('Back', _goBack),
      ],
    );
  }

  // â”€â”€ Step 3: Personal Information â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildPersonalInfoStep() {
    return _buildScrollableStep(
      children: [
        _stepHeader('Personal Information', 3),
        const SizedBox(height: 20),
        _buildProgressIndicator(3),
        const SizedBox(height: 32),
        _sectionLabelOptional('PERSONAL DETAILS'),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickDob,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 20, color: AppTheme.textHint),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Date of Birth', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                      const SizedBox(height: 2),
                      Text(
                        _dob != null ? DateFormat('dd MMMM yyyy').format(_dob!) : 'Select Date',
                        style: TextStyle(
                          fontSize: 14,
                          color: _dob != null ? AppTheme.textPrimary : AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _dropdownField(
                label: 'Gender',
                icon: Icons.person_outline_rounded,
                value: _gender,
                items: _genders,
                onChanged: (v) => setState(() => _gender = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _dropdownField(
                label: 'Marital Status',
                icon: Icons.favorite_border_rounded,
                value: _maritalStatus,
                items: _maritalStatuses,
                onChanged: (v) => setState(() => _maritalStatus = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _sectionLabelOptional('EMERGENCY CONTACT'),
        const SizedBox(height: 12),
        _inputField(_emergencyNameCtrl, 'Contact Name', Icons.person_outline_rounded),
        const SizedBox(height: 16),
        _inputField(_emergencyPhoneCtrl, 'Contact Phone', Icons.phone_outlined, keyboardType: TextInputType.phone),
        const SizedBox(height: 24),
        _sectionLabelOptional('GOVERNMENT ID'),
        const SizedBox(height: 12),
        _dropdownField(
          label: 'ID Type',
          icon: Icons.badge_outlined,
          value: _govtIdType,
          items: _govtIdTypes,
          onChanged: (v) => setState(() => _govtIdType = v),
        ),
        const SizedBox(height: 16),
        _inputField(_govtIdNumberCtrl, 'ID Number', Icons.tag_rounded),
        const SizedBox(height: 24),
        _sectionLabelOptional('PERSONAL ADDRESS'),
        const SizedBox(height: 12),
        _inputField(_personalAddressCtrl, 'Address', Icons.home_outlined),
        const Spacer(),
        const SizedBox(height: 20),
        _primaryBtn('Continue', _goNext),
        const SizedBox(height: 10),
        _secondaryBtn('Back', _goBack),
      ],
    );
  }

  // â”€â”€ Step 4: Review â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildReviewStep() {
    return _buildScrollableStep(
      children: [
        _stepHeader('Review Information', 4),
        const SizedBox(height: 20),
        _buildProgressIndicator(4),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(_initials, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.shield_outlined, size: 12, color: AppTheme.primary),
                            const SizedBox(width: 4),
                            const Text('Administrator', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 6),
                            Text('Â·  $_employeeId', style: const TextStyle(fontSize: 11, color: AppTheme.textHint, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppTheme.primary, size: 18),
                    onPressed: () => setState(() => _step = 1),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _reviewSection('Basic Information', () => setState(() => _step = 1), [
                _reviewRow('Full Name', _fullName, Icons.person_outline_rounded),
                _reviewRow('Work Email', _emailCtrl.text.trim(), Icons.email_outlined),
                _reviewRow('Phone Number', _phoneCtrl.text.trim(), Icons.phone_outlined),
              ]),
              const SizedBox(height: 16),
              _reviewSection('Work Information', () => setState(() => _step = 2), [
                _reviewRow('Employee ID', _employeeId, Icons.tag_rounded),
                _reviewRow('Department', _department ?? '-', Icons.account_tree_outlined),
                _reviewRow('Location', _locationCtrl.text.trim(), Icons.location_on_outlined),
                _reviewRow('Employee Type', _employeeType ?? '-', Icons.person_outline_rounded),
                _reviewRow('Role', 'Administrator', Icons.shield_outlined),
              ]),
              const SizedBox(height: 16),
              _reviewSection('Personal Information', () => setState(() => _step = 3), [
                _reviewRow('Date of Birth', _dob != null ? DateFormat('dd MMMM yyyy').format(_dob!) : '-', Icons.calendar_today_outlined),
                _reviewRow('Gender', _gender ?? '-', Icons.person_outline_rounded),
                _reviewRow('Emergency Contact', _emergencyNameCtrl.text.trim().isNotEmpty ? '${_emergencyNameCtrl.text.trim()} Â· ${_emergencyPhoneCtrl.text.trim()}' : '-', Icons.phone_outlined),
                _reviewRow('Government ID', _govtIdNumberCtrl.text.trim().isNotEmpty ? '${_govtIdType ?? '-'} Â· ${_govtIdNumberCtrl.text.trim()}' : '-', Icons.badge_outlined),
              ]),
            ],
          ),
        ),
        const Spacer(),
        const SizedBox(height: 20),
        _primaryBtn(_isSubmitting ? 'Creating...' : 'Create Admin Account', _isSubmitting ? null : _createAdminAccount),
        const SizedBox(height: 10),
        _secondaryBtn('Back', _goBack),
      ],
    );
  }

  // â”€â”€ Step 5: Success â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildSuccessStep() {
    return _buildScrollableStep(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Spacer(),
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: AppTheme.primarySurface,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(_initials, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppTheme.primary)),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Administrator Account Created',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Your administrator account is ready. Next, set up departments for your organization.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE6EAF2)),
          ),
          child: Column(
            children: [
              _successRow('Organization', widget.organizationData['companyName'] as String? ?? '-'),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: Color(0xFFE5E7EB)),
              ),
              _successRow('Admin Name', _fullName),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: Color(0xFFE5E7EB)),
              ),
              Row(
                children: [
                  const Text('Role', style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
                  const Spacer(),
                  const Text('Administrator', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFE8E9FB), borderRadius: BorderRadius.circular(4)),
                    child: const Text('ADMIN', style: TextStyle(fontSize: 9, color: AppTheme.primary, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: Color(0xFFE5E7EB)),
              ),
              Row(
                children: [
                  const Text('Workspace', style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
                  const Spacer(),
                  const Text('Active', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                    child: const Text('ACTIVE', style: TextStyle(fontSize: 9, color: Color(0xFF16A34A), fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Setup Progress', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        ),
        const SizedBox(height: 16),
        _progressItem(true, false, 'Organization Created'),
        const SizedBox(height: 12),
        _progressItem(true, false, 'Administrator Created'),
        const SizedBox(height: 12),
        _progressItem(false, true, 'Departments Setup'),
        const SizedBox(height: 12),
        _progressItem(false, false, 'Employee Setup'),
        const SizedBox(height: 12),
        _progressItem(false, false, 'Policies Configuration'),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F1FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.account_tree_outlined, color: AppTheme.primary, size: 24),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next: Department Setup',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Create departments and assign teams',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppTheme.primary),
            ],
          ),
        ),
        const Spacer(),
        const SizedBox(height: 20),
        _primaryBtn('Continue to Department Setup', () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => DepartmentSetupScreen(
                orgId: _createdOrgId!,
                orgName: widget.organizationData['companyName'] as String? ?? '',
              ),
            ),
            (route) => false,
          );
        }),
      ],
    );
  }

  // â”€â”€ Helper Widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _stepHeader(String title, int step) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F1FF),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'STEP $step OF 4',
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(int activeStep) {
    List<Widget> children = [];
    for (int i = 0; i < 4; i++) {
      final stepNumber = i + 1;
      final isComplete = stepNumber < activeStep;
      final isActive = stepNumber == activeStep;

      final borderColor = (isComplete || isActive) ? const Color(0xFF5C5CFF) : const Color(0xFFE5E7EB);
      final bgColor = isComplete ? const Color(0xFF5C5CFF) : Colors.white;
      final textColor = isActive ? const Color(0xFF5C5CFF) : const Color(0xFF9CA3AF);

      children.add(
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
            border: Border.all(
              color: borderColor,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: isComplete
              ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
              : Text(
                  '$stepNumber',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
        ),
      );

      if (i < 3) {
        children.add(
          Expanded(
            child: Container(
              height: 1.5,
              color: isComplete ? const Color(0xFF5C5CFF) : const Color(0xFFE5E7EB),
            ),
          ),
        );
      }
    }

    return Row(
      children: children,
    );
  }

  Widget _inputField(
    TextEditingController controller,
    String label,
    IconData? icon, {
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: AppTheme.textHint),
        prefixIcon: icon != null ? Icon(icon, size: 20, color: AppTheme.textHint) : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        fillColor: readOnly ? const Color(0xFFF9FAFB) : Colors.white,
        filled: readOnly,
      ),
    );
  }


  Widget _dropdownField({
    required String label,
    required IconData? icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: value,
      onChanged: onChanged,
      icon: const Icon(Icons.expand_more_rounded, color: AppTheme.textHint, size: 22),
      style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w500, overflow: TextOverflow.ellipsis),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: AppTheme.textHint),
        prefixIcon: icon != null ? Icon(icon, size: 20, color: AppTheme.textHint) : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
    );
  }

  Widget _reviewSection(String title, VoidCallback onEdit, List<Widget> rows) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.textHint),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textHint,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabelOptional(String label) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textHint,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(4)),
          child: const Text('Optional', style: TextStyle(fontSize: 9, color: AppTheme.textHint, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _progressItem(bool done, bool isNext, String label) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AppTheme.success : (isNext ? Colors.white : Colors.white),
            border: Border.all(color: done ? AppTheme.success : (isNext ? AppTheme.primary : const Color(0xFFD1D5DB)), width: 1.5),
          ),
          alignment: Alignment.center,
          child: done ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: done || isNext ? FontWeight.w600 : FontWeight.w400,
              color: done ? AppTheme.textPrimary : (isNext ? AppTheme.textPrimary : AppTheme.textHint),
            ),
          ),
        ),
        if (done) const Icon(Icons.check_circle_outline_rounded, color: AppTheme.success, size: 18),
        if (isNext)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFFF0F1FF), borderRadius: BorderRadius.circular(4)),
            child: const Text('NEXT', style: TextStyle(fontSize: 9, color: AppTheme.primary, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }

  Widget _successRow(String label, String value) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textHint)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      ],
    );
  }

  Widget _featureRow(IconData icon, String title, String subtitle, {Color? badgeColor, String? badgeText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    if (badgeText != null && badgeColor != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(4)),
                        child: Text(badgeText, style: const TextStyle(fontSize: 9, color: AppTheme.primary, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
              ],
            ),
          ),
          const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 18),
        ],
      ),
    );
  }

  Widget _systemBreadcrumb(List<String> items, int activeIndex) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.asMap().entries.map((entry) {
        final isActive = entry.key == activeIndex;
        final isPast = entry.key < activeIndex;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              entry.value,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? AppTheme.primary : (isPast ? AppTheme.textPrimary : AppTheme.textHint),
                fontWeight: isActive ? FontWeight.w700 : (isPast ? FontWeight.w600 : FontWeight.w500),
              ),
            ),
            if (entry.key != items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.chevron_right_rounded, size: 14, color: AppTheme.textHint),
              ),
          ],
        );
      }).toList(),
      ),
    );
  }

  Widget _primaryBtn(String label, VoidCallback? onPressed) {
    return Center(
      child: SizedBox(
        width: 327,
        height: 51,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5C5CFF),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFB0B2FF),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _secondaryBtn(String label, VoidCallback onPressed) {
    return Center(
      child: SizedBox(
        width: 327,
        height: 51,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textPrimary,
            side: const BorderSide(color: Color(0xFFE5E7EB)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: AppTheme.primary)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }
}

class _MiniStatBox extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textHint, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
