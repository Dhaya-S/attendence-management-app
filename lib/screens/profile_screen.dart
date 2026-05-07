import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/utils/firestore_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final user = FirebaseAuth.instance.currentUser;

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bloodGroupController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _joiningDateController = TextEditingController();
  final _endingDateController = TextEditingController();

  String? _profileImageUrl;
  File? _imageFile;
  String? _pickedImageBase64;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bloodGroupController.dispose();
    _aadhaarController.dispose();
    _emergencyPhoneController.dispose();
    _joiningDateController.dispose();
    _endingDateController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    if (user == null) return;

    try {
      final querySnapshot = await FirestoreService.usersCol
          .where('email', isEqualTo: user!.email ?? '')
          .limit(1)
          .get();
      
      DocumentSnapshot? doc;
      if (querySnapshot.docs.isNotEmpty) {
        doc = querySnapshot.docs.first;
      } else {
        doc = await FirestoreService.userDocByEmail(user!.email ?? '').get();
      }

      if (doc != null && doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _nameController.text = data['name'] ?? '';
        _ageController.text = data['age']?.toString() ?? '';
        _addressController.text = data['address'] ?? '';
        _emailController.text = data['email'] ?? user!.email ?? '';
        _phoneController.text = data['phone'] ?? '';
        _bloodGroupController.text = data['bloodGroup'] ?? '';
        _aadhaarController.text = data['aadhaar'] ?? '';
        _emergencyPhoneController.text = data['emergencyPhone'] ?? '';
        _joiningDateController.text = data['joiningDate'] ?? '';
        _endingDateController.text = data['endingDate'] ?? '';
        _profileImageUrl = data['profileImageUrl'];
      } else {
        _emailController.text = user!.email ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 40, // Lower quality for Firestore limits
      maxWidth: 300, // Smaller dimensions
      maxHeight: 300,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageFile = File(pickedFile.path);
        _pickedImageBase64 = base64Encode(bytes);
      });
    }
  }

  Future<void> _selectDate(
      BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? imageUrl = _profileImageUrl;
      if (_pickedImageBase64 != null) {
        imageUrl = _pickedImageBase64;
      }

      final querySnapshot = await FirestoreService.usersCol
          .where('email', isEqualTo: user!.email ?? '')
          .limit(1)
          .get();

      DocumentReference userRef;
      if (querySnapshot.docs.isNotEmpty) {
        userRef = querySnapshot.docs.first.reference;
      } else {
        userRef = FirestoreService.userDocByEmail(user!.email ?? '');
      }

      await userRef.set({
        'name': _nameController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()),
        'address': _addressController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'bloodGroup': _bloodGroupController.text.trim(),
        'aadhaar': _aadhaarController.text.trim(),
        'emergencyPhone': _emergencyPhoneController.text.trim(),
        'joiningDate': _joiningDateController.text.trim(),
        'endingDate': _endingDateController.text.trim(),
        'profileImageUrl': imageUrl,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error: $e';
        if (e.toString().contains('permission-denied')) {
          errorMessage =
              'Permission Denied: You may not have access to update your profile. Please contact the manager.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('My Profile',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppTheme.primary.withOpacity(0.2),
                                width: 4),
                          ),
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.white,
                            backgroundImage: _pickedImageBase64 != null
                                ? MemoryImage(base64Decode(_pickedImageBase64!))
                                    as ImageProvider
                                : (_profileImageUrl != null &&
                                        _profileImageUrl!.isNotEmpty
                                    ? (_profileImageUrl!.startsWith('http')
                                        ? NetworkImage(_profileImageUrl!)
                                            as ImageProvider
                                        : MemoryImage(
                                            base64Decode(_profileImageUrl!)))
                                    : null),
                            child: _pickedImageBase64 == null &&
                                    (_profileImageUrl == null ||
                                        _profileImageUrl!.isEmpty)
                                ? const Icon(Icons.person_rounded,
                                    size: 70, color: AppTheme.primary)
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit,
                                  size: 20, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildTextField(_nameController, 'Full Name',
                        Icons.person_outline_rounded),
                    _buildTextField(_ageController, 'Age', Icons.cake_outlined,
                        keyboardType: TextInputType.number, validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Please fill this mandatory field';
                      if (int.tryParse(value) == null)
                        return 'Please enter a valid age';
                      return null;
                    }),
                    _buildTextField(
                        _emailController, 'Email Address', Icons.email_outlined,
                        enabled: false),
                    _buildTextField(_phoneController, 'Phone Number',
                        Icons.phone_android_outlined,
                        keyboardType: TextInputType.phone, validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Please fill this mandatory field';
                      if (value.length < 10)
                        return 'Please enter a valid 10-digit number';
                      return null;
                    }),
                    _buildTextField(_bloodGroupController, 'Blood Group',
                        Icons.bloodtype_outlined),
                    _buildTextField(_aadhaarController, 'Aadhaar Number',
                        Icons.badge_outlined,
                        keyboardType: TextInputType.number, validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Please fill this mandatory field';
                      if (value.length != 12)
                        return 'Aadhaar number must be 12 digits';
                      return null;
                    }),
                    _buildTextField(
                        _emergencyPhoneController,
                        'Emergency Phone Number',
                        Icons.contact_emergency_outlined,
                        keyboardType: TextInputType.phone, validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Please fill this mandatory field';
                      if (value.length < 10)
                        return 'Please enter a valid 10-digit number';
                      return null;
                    }),
                    _buildTextField(_joiningDateController, 'Joining Date',
                        Icons.calendar_today_outlined,
                        readOnly: true,
                        onTap: () =>
                            _selectDate(context, _joiningDateController)),
                    _buildTextField(_endingDateController,
                        'Ending Date (Optional)', Icons.event_busy_outlined,
                        readOnly: true,
                        onTap: () =>
                            _selectDate(context, _endingDateController),
                        isOptional: true),
                    _buildTextField(_addressController, 'Home Address',
                        Icons.location_on_outlined,
                        maxLines: 3),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                            borderRadius: AppTheme.buttonRadius),
                        elevation: 2,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'SAVE CHANGES',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
    bool isOptional = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppTheme.textMuted.withOpacity(0.8),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            enabled: enabled,
            readOnly: readOnly,
            onTap: onTap,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: TextStyle(
              color: enabled ? AppTheme.textPrimary : AppTheme.textMuted,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
              filled: true,
              fillColor: enabled ? Colors.white : Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: AppTheme.inputRadius,
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppTheme.inputRadius,
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppTheme.inputRadius,
                borderSide: const BorderSide(color: AppTheme.primary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: AppTheme.inputRadius,
                borderSide: const BorderSide(color: Colors.red, width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: AppTheme.inputRadius,
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
            ),
            validator: validator ??
                (value) {
                  if (!isOptional &&
                      enabled &&
                      (value == null || value.trim().isEmpty)) {
                    return 'Please fill this mandatory field';
                  }
                  return null;
                },
          ),
        ],
      ),
    );
  }
}
