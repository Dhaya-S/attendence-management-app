import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animate_do/animate_do.dart';
import '../../theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';

class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final user = FirebaseAuth.instance.currentUser;
  
  bool _isLoading = true;
  bool _isSaving = false;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _aadhaarCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _bloodGrpCtrl = TextEditingController();
  final TextEditingController _personalEmailCtrl = TextEditingController();
  final TextEditingController _joiningDateCtrl = TextEditingController();
  DateTime? _selectedJoiningDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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
        _nameCtrl.text = data['name'] ?? '';
        _phoneCtrl.text = data['phone'] ?? '';
        _aadhaarCtrl.text = data['aadhaar'] ?? '';
        _addressCtrl.text = data['address'] ?? '';
        _bloodGrpCtrl.text = data['bloodGroup'] ?? '';
        _personalEmailCtrl.text = data['personalEmail'] ?? '';
        final jd = data['joiningDate'];
        if (jd is String) {
          _joiningDateCtrl.text = jd;
          _selectedJoiningDate = DateTime.tryParse(jd);
        } else if (jd is Timestamp) {
          _selectedJoiningDate = jd.toDate();
          _joiningDateCtrl.text = "${_selectedJoiningDate!.year}-${_selectedJoiningDate!.month.toString().padLeft(2, '0')}-${_selectedJoiningDate!.day.toString().padLeft(2, '0')}";
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e'), backgroundColor: AppTheme.danger));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
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
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'aadhaar': _aadhaarCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'bloodGroup': _bloodGrpCtrl.text.trim(),
        'personalEmail': _personalEmailCtrl.text.trim(),
        'joiningDate': _joiningDateCtrl.text.trim(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Details saved successfully!'), backgroundColor: AppTheme.success));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving data: $e'), backgroundColor: AppTheme.danger));
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
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Personal Details', style: AppTheme.h1.copyWith(fontSize: 18)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeInUp(
              duration: const Duration(milliseconds: 600),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Update your personal details', style: AppTheme.bodyMedium.copyWith(color: AppTheme.textHint)),
                    const SizedBox(height: 32),
                    
                    _buildTextField('Full Name', _nameCtrl, Icons.person_outline),
                    const SizedBox(height: 20),
                    _buildTextField('Phone Number', _phoneCtrl, Icons.phone_outlined, keyboardType: TextInputType.phone),
                    const SizedBox(height: 20),
                    _buildTextField('Aadhaar Number', _aadhaarCtrl, Icons.badge_outlined, keyboardType: TextInputType.number),
                    const SizedBox(height: 20),
                    _buildTextField('Address', _addressCtrl, Icons.location_on_outlined, maxLines: 3),
                    const SizedBox(height: 20),
                    _buildTextField('Blood Group', _bloodGrpCtrl, Icons.bloodtype_outlined),
                    const SizedBox(height: 20),
                    _buildTextField('Personal Email', _personalEmailCtrl, Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 20),
                    _buildDateField('Joining Date', _joiningDateCtrl, Icons.calendar_today_outlined),
                    
                    const SizedBox(height: 48),
                    _isSaving
                      ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                      : ElevatedButton(
                          onPressed: _saveData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: const Text('Save Details', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildDateField(String label, TextEditingController controller, IconData icon) {
    return InkWell(
      onTap: () => _selectJoiningDate(context),
      borderRadius: BorderRadius.circular(16),
      child: IgnorePointer(
        child: _buildTextField(label, controller, icon),
      ),
    );
  }

  Future<void> _selectJoiningDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedJoiningDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedJoiningDate = picked;
        _joiningDateCtrl.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: AppTheme.bodyMedium,
      validator: (value) => value == null || value.isEmpty ? '$label cannot be empty' : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTheme.label.copyWith(color: AppTheme.textHint),
        prefixIcon: Icon(icon, color: AppTheme.textHint, size: 22),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
