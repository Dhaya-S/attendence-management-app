import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';

class ManagerEditProfileScreen extends StatefulWidget {
  const ManagerEditProfileScreen({super.key});

  @override
  State<ManagerEditProfileScreen> createState() =>
      _ManagerEditProfileScreenState();
}

class _ManagerEditProfileScreenState extends State<ManagerEditProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _deptController = TextEditingController();

  bool _isLoading = false;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (user == null) return;
    _emailController.text = user!.email ?? '';

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
        _nameController.text = data['name'] ?? user?.displayName ?? '';
        _phoneController.text = data['phone'] ?? '+1 (555) 000-0000';
        _deptController.text = data['department'] ?? 'Product & Design';
      } else {
        _nameController.text = user?.displayName ?? '';
      }
    } catch (e) {
      // ignores
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
      _uploadImage();
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null || user == null) return;

    setState(() => _isLoading = true);

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images/${user!.email ?? user!.uid}.jpg');
      await storageRef.putFile(_selectedImage!);
      final downloadUrl = await storageRef.getDownloadURL();

      final userRef = FirestoreService.userDocByEmail(user!.email ?? '');


      await userRef.update({
        'profileImageUrl': downloadUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profile photo updated'),
              backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to upload photo: $e'),
              backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _deptController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userRef = FirestoreService.userDocByEmail(user!.email ?? '');


      await userRef.set({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'department': _deptController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: AppTheme.success),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppTheme.danger),
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
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: AppTheme.textPrimary, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildAvatarSection(),
              const SizedBox(height: 24),
              _buildPersonalInfoSection(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveChanges,
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
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirestoreService.userStreamByEmail(user?.email ?? ''),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final rawName = data?['name']?.toString() ?? user?.displayName ?? 'Manager';
        final name = rawName.trim().isEmpty ? 'Manager' : rawName.trim();
        String? imageUrl = data?['profileImageUrl'];

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border:
                          Border.all(color: AppTheme.primarySurface, width: 4),
                    ),
                    child: ClipOval(
                      child: _selectedImage != null
                          ? Image.file(_selectedImage!, fit: BoxFit.cover)
                          : (imageUrl != null && imageUrl.isNotEmpty
                              ? (imageUrl.startsWith('http')
                                  ? Image.network(imageUrl, fit: BoxFit.cover)
                                  : Image.memory(base64Decode(imageUrl),
                                      fit: BoxFit.cover))
                              : Container(
                                  color: AppTheme.primarySurface,
                                  child: const Icon(Icons.person,
                                      color: AppTheme.primary, size: 40),
                                )),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppTheme.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.business_center_rounded,
                        color: Colors.white, size: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _isLoading ? null : _pickImage,
                child: const Text(
                  'Change Photo',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textHint,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPersonalInfoSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PERSONAL INFORMATION',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppTheme.textHint,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoField(
              'Full Name', _nameController, Icons.person_outline),
          const SizedBox(height: 16),
          _buildInfoField(
              'Email Address', _emailController, Icons.email_outlined,
              enabled: false),
          const SizedBox(height: 16),
          _buildInfoField(
              'Phone Number', _phoneController, Icons.phone_outlined),
          const SizedBox(height: 16),
          _buildInfoField('Department', _deptController, Icons.badge_outlined),
        ],
      ),
    );
  }

  Widget _buildInfoField(
      String label, TextEditingController controller, IconData icon,
      {bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: enabled ? Colors.white : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            border: Border.all(color: AppTheme.divider),
          ),
          child: TextFormField(
            controller: controller,
            enabled: enabled,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: enabled ? AppTheme.textPrimary : AppTheme.textMuted,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: AppTheme.textHint, size: 20),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
