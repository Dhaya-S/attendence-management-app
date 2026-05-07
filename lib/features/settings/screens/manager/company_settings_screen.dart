import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/message_helper.dart';

class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TimeOfDay _startTime;
  late TextEditingController _gracePeriodController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize from session
    final session = AppSession();
    final parts = session.shiftStartTime.split(':');
    _startTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
    _gracePeriodController = TextEditingController(text: session.gracePeriod.toString());
  }

  @override
  void dispose() {
    _gracePeriodController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
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
    if (picked != null && picked != _startTime) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final hour = _startTime.hour.toString().padLeft(2, '0');
      final minute = _startTime.minute.toString().padLeft(2, '0');
      final shiftStartTime = "$hour:$minute";
      final gracePeriod = int.parse(_gracePeriodController.text);

      await FirestoreService.companyDoc().update({
        'shiftStartTime': shiftStartTime,
        'gracePeriod': gracePeriod,
      });

      // Update session in real-time
      AppSession().shiftStartTime = shiftStartTime;
      AppSession().gracePeriod = gracePeriod;

      if (mounted) {
        MessageHelper.showSuccess(context, "Settings updated successfully");
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        MessageHelper.showError(context, "Failed to update settings: $e");
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
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Company Settings', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Shift Timing'),
              const SizedBox(height: 16),
              _buildSettingCard(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Shift Start Time', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Employees checking in after this time will be flagged.'),
                      trailing: TextButton(
                        onPressed: () => _selectTime(context),
                        style: TextButton.styleFrom(
                          backgroundColor: AppTheme.primarySurface,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          _startTime.format(context),
                          style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const Divider(height: 32),
                    TextFormField(
                      controller: _gracePeriodController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Grace Period (Minutes)',
                        hintText: 'e.g. 15',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.timer_outlined),
                        filled: true,
                        fillColor: AppTheme.surface,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter a grace period';
                        if (int.tryParse(value) == null) return 'Please enter a valid number';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('SAVE SETTINGS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: AppTheme.textHint,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSettingCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: child,
    );
  }
}
