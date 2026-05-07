import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/widgets/notification_action.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';

class AddEmployeeScreen extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? employeeId;

  const AddEmployeeScreen({super.key, this.existingData, this.employeeId});

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _roleController = TextEditingController();
  final _passwordController = TextEditingController();
  final _managerController = TextEditingController();
  final _locationController = TextEditingController();
  final _employeeIdController = TextEditingController();
  String _selectedDepartment = 'Engineering';
  String _selectedRole = 'Employee';
  bool _isLoading = false;

  final _departments = [
    'Select Department',
    'Engineering',
    'Design',
    'Marketing',
    'HR',
    'Finance',
    'Operations',
  ];

  final _roles = ['Employee', 'Manager'];

  bool get isEditing => widget.existingData != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _nameController.text = widget.existingData!['name'] ?? '';
      _emailController.text = widget.existingData!['email'] ?? '';
      _phoneController.text = widget.existingData!['phone'] ?? '';
      _roleController.text = widget.existingData!['designation'] ?? '';
      _selectedDepartment =
          widget.existingData!['department'] ?? 'Engineering';
      _selectedRole = (widget.existingData!['role'] ?? 'Employee').toString().toUpperCase() == 'MANAGER' ? 'Manager' : 'Employee';
      _managerController.text = widget.existingData!['reportingManager'] ?? '';
      _locationController.text = widget.existingData!['location'] ?? '';
      _employeeIdController.text = widget.existingData!['employeeId'] ?? '';
    } else {
      _generateEmployeeId();
    }
  }

  Future<void> _generateEmployeeId() async {
    try {
      // Count employees inside the current company's users sub-collection.
      final snapshot = await FirestoreService.companyUsersQuery.get();
      final count = snapshot.docs.length + 1;
      _employeeIdController.text = 'EMP${count.toString().padLeft(4, '0')}';
    } catch (e) {
      debugPrint('Error generating employee ID: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _roleController.dispose();
    _passwordController.dispose();
    _managerController.dispose();
    _locationController.dispose();
    _employeeIdController.dispose();
    super.dispose();
  }

  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) return;


    if (!isEditing && _passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim().toLowerCase();
      final currentCompanyId = AppSession().companyId;

      if (currentCompanyId == null) {
        throw 'Company context is missing. Please log in again.';
      }

      // Check if employee already exists in this company
      final existingDoc = await FirestoreService.userDocByEmail(email).get();
      if (existingDoc.exists) {
        throw 'This email is already registered as an employee in your company.';
      }

      final role = _selectedRole.toLowerCase();
      final data = {
        'name': _nameController.text.trim(),
        'email': email,
        'phone': _phoneController.text.trim(),
        'designation': _roleController.text.trim(),
        'department': _selectedDepartment,
        'reportingManager': _managerController.text.trim(),
        'location': _locationController.text.trim(),
        'employeeId': _employeeIdController.text.trim(),
        'status': 'approved',
        'role': role,
        'companyId': currentCompanyId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (isEditing && widget.employeeId != null) {
        await FirestoreService.usersCol
            .doc(widget.employeeId)
            .update(data);
      } else {
        // Create: Check if already in global approved_users
        final globalDoc = await FirestoreService.approvedUserDoc(email).get();
        if (globalDoc.exists) {
          throw 'This email is already registered in another company or as a manager.';
        }

        final appName = 'Temp-App-${DateTime.now().millisecondsSinceEpoch}';
        FirebaseApp secondaryApp = await Firebase.initializeApp(
          name: appName,
          options: Firebase.app().options,
        );

        try {
          final managerQuery = await FirestoreService.usersCol
              .where('email', isEqualTo: AppSession().email ?? '')
              .limit(1)
              .get();
          final currManagerName = managerQuery.docs.isNotEmpty
              ? managerQuery.docs.first.data()['name'] ?? 'Manager'
              : 'Manager';
          
          final userCredential =
              await FirebaseAuth.instanceFor(app: secondaryApp)
                  .createUserWithEmailAndPassword(
            email: email,
            password: _passwordController.text.trim(),
          );

          if (userCredential.user != null) {
            final uid = userCredential.user!.uid;
            data['uid'] = uid;
            data['createdAt'] = FieldValue.serverTimestamp();
            data['approvedBy'] = currManagerName;

            // Write 1: company-scoped users sub-collection & Write 2: global approved_users mapping
            final batch = FirebaseFirestore.instance.batch();
            batch.set(FirestoreService.userDocByEmail(email), data);
            batch.set(FirestoreService.approvedUserDoc(email), {
              'email': email,
              'role': role,
              'companyId': currentCompanyId,
              'status': 'approved',
              'approvedAt': FieldValue.serverTimestamp(),
            });
            await batch.commit();
            await FirebaseAuth.instanceFor(app: secondaryApp).signOut();
          }
        } finally {
          await secondaryApp.delete();
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Text(isEditing
                ? 'Details updated successfully'
                : '${_selectedRole} account created and approved!'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (authError) {
      String msg = 'Auth Error: ${authError.message}';
      if (authError.code == 'email-already-in-use') {
        msg = 'This email is already registered.';
      } else if (authError.code == 'invalid-email') {
        msg = 'The email address is not valid.';
      } else if (authError.code == 'weak-password') {
        msg = 'The password is too weak.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppTheme.danger),
        );
      }
    } catch (e) {
      debugPrint('Save Employee Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save employee: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      resizeToAvoidBottomInset: false, // Prevents DDC Web engine ViewInsets assertions
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          isEditing ? 'Edit Employee' : 'Add Employee',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          NotificationAction(),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Photo placeholder
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.primarySurface,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppTheme.primary.withOpacity(0.3), width: 2),
                      ),
                      child: const Icon(Icons.person,
                          color: AppTheme.primary, size: 40),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        'Upload Photo',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildField('EMPLOYEE ID', _employeeIdController, 'EMP0001', readOnly: true),
              const SizedBox(height: 16),
              _buildField('FULL NAME', _nameController, 'John Doe'),
              const SizedBox(height: 16),
              _buildField(
                  'EMAIL ADDRESS', _emailController, 'john.doe@company.com',
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _buildField('PHONE NUMBER', _phoneController, '+1 (555) 000-0000',
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              if (!isEditing) ...[
                _buildField('PASSWORD', _passwordController, '••••••••',
                    keyboardType: TextInputType.visiblePassword),
                const SizedBox(height: 16),
              ],

              // Department dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DEPARTMENT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textHint,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedDepartment,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down,
                            color: AppTheme.textHint),
                        style: const TextStyle(
                            fontSize: 14, color: AppTheme.textPrimary),
                        onChanged: (v) =>
                            setState(() => _selectedDepartment = v!),
                        items: _departments
                            .map((d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(d),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Role Select
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ACCOUNT ROLE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textHint,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedRole,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down,
                            color: AppTheme.textHint),
                        style: const TextStyle(
                            fontSize: 14, color: AppTheme.textPrimary),
                        onChanged: (v) =>
                            setState(() => _selectedRole = v!),
                        items: _roles
                            .map((r) => DropdownMenuItem(
                                  value: r,
                                  child: Text(r),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildField('DESIGNATION', _roleController, 'e.g. Senior Developer'),
              const SizedBox(height: 16),
              _buildField('REPORTING MANAGER', _managerController, 'e.g. Michael Scott'),
              const SizedBox(height: 16),
              _buildField('WORK LOCATION', _locationController, 'e.g. Mumbai HQ / WFH'),
              const SizedBox(height: 32),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveEmployee,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          isEditing ? 'Update Employee' : 'Save Employee',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
      String label, TextEditingController controller, String hint,
      {TextInputType keyboardType = TextInputType.text, bool readOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.textHint,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            return null;
          },
          style: TextStyle(fontSize: 14, color: readOnly ? AppTheme.textHint : AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppTheme.textHint, fontSize: 14),
            filled: true,
            fillColor: readOnly ? AppTheme.surface : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              borderSide: BorderSide(color: AppTheme.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              borderSide: BorderSide(color: AppTheme.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              borderSide: BorderSide(color: readOnly ? AppTheme.divider : AppTheme.primary, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}
