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
  late TimeOfDay _endTime;
  late TextEditingController _gracePeriodController;
  late TextEditingController _paidLeavesController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final session = AppSession();

    // Shift timing
    final parts = session.shiftStartTime.split(':');
    _startTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
    final eParts = session.shiftEndTime.split(':');
    _endTime = TimeOfDay(
      hour: int.parse(eParts[0]),
      minute: int.parse(eParts[1]),
    );
    _gracePeriodController =
        TextEditingController(text: session.gracePeriod.toString());

    // Leave policy
    _paidLeavesController =
        TextEditingController(text: session.paidLeavesPerYear.toString());

    // Fetch latest from Firestore (in case session is stale)
    _loadFromFirestore();
  }

  Future<void> _loadFromFirestore() async {
    try {
      final doc = await FirestoreService.companyDoc().get();
      if (!mounted) return;
      if (doc.exists && doc.data() != null) {
        final d = doc.data()!;
        // Paid leaves
        final pl = (d['paidLeavesPerYear'] as num?)?.toInt();
        if (pl != null) {
          setState(() {
            _paidLeavesController.text = pl.toString();
          });
        }
        // Shift timing (keep in sync too)
        final sst = d['shiftStartTime'] as String?;
        if (sst != null) {
          final p = sst.split(':');
          if (p.length == 2) {
            final h = int.tryParse(p[0]);
            final m = int.tryParse(p[1]);
            if (h != null && m != null) {
              setState(() {
                _startTime = TimeOfDay(hour: h, minute: m);
              });
            }
          }
        }
        final set_ = d['shiftEndTime'] as String?;
        if (set_ != null) {
          final p = set_.split(':');
          if (p.length == 2) {
            final h = int.tryParse(p[0]);
            final m = int.tryParse(p[1]);
            if (h != null && m != null) {
              setState(() {
                _endTime = TimeOfDay(hour: h, minute: m);
              });
            }
          }
        }
        final gp = (d['gracePeriod'] as num?)?.toInt();
        if (gp != null) {
          _gracePeriodController.text = gp.toString();
        }
      }
    } catch (_) {
      // Non-fatal; fall back to session values
    }
  }

  @override
  void dispose() {
    _gracePeriodController.dispose();
    _paidLeavesController.dispose();
    super.dispose();
  }

  Future<void> _selectStartTime(BuildContext context) async {
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
      setState(() => _startTime = picked);
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
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
    if (picked != null && picked != _endTime) {
      setState(() => _endTime = picked);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final hour = _startTime.hour.toString().padLeft(2, '0');
      final minute = _startTime.minute.toString().padLeft(2, '0');
      final shiftStartTime = "$hour:$minute";
      final eHour = _endTime.hour.toString().padLeft(2, '0');
      final eMinute = _endTime.minute.toString().padLeft(2, '0');
      final shiftEndTime = "$eHour:$eMinute";
      final gracePeriod = int.parse(_gracePeriodController.text);
      final paidLeavesPerYear = int.parse(_paidLeavesController.text);

      await FirestoreService.companyDoc().update({
        'shiftStartTime': shiftStartTime,
        'shiftEndTime': shiftEndTime,
        'gracePeriod': gracePeriod,
        'paidLeavesPerYear': paidLeavesPerYear,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update in-memory session immediately
      AppSession().shiftStartTime = shiftStartTime;
      AppSession().shiftEndTime = shiftEndTime;
      AppSession().gracePeriod = gracePeriod;
      AppSession().paidLeavesPerYear = paidLeavesPerYear;

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
        title: const Text(
          'Company Settings',
          style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary, size: 18),
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
              // ── Shift Timing ─────────────────────────────────────────
              _buildSectionHeader('Shift Timing'),
              const SizedBox(height: 16),
              _buildSettingCard(
                child: Column(
                  children: [
                    // Shift Start Time
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.login_rounded,
                            color: AppTheme.primary, size: 20),
                      ),
                      title: const Text('Shift Start Time',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text(
                          'Check-ins after this time are flagged late.',
                          style: TextStyle(fontSize: 12)),
                      trailing: TextButton(
                        onPressed: () => _selectStartTime(context),
                        style: TextButton.styleFrom(
                          backgroundColor: AppTheme.primarySurface,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          _startTime.format(context),
                          style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const Divider(height: 24),
                    // Shift End Time
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEDE8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.logout_rounded,
                            color: Color(0xFFE85D04), size: 20),
                      ),
                      title: const Text('Shift End Time',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text(
                          'Expected checkout time for employees.',
                          style: TextStyle(fontSize: 12)),
                      trailing: TextButton(
                        onPressed: () => _selectEndTime(context),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFFFEDE8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          _endTime.format(context),
                          style: const TextStyle(
                              color: Color(0xFFE85D04),
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const Divider(height: 24),
                    TextFormField(
                      controller: _gracePeriodController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Grace Period (Minutes)',
                        hintText: 'e.g. 15',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.timer_outlined),
                        filled: true,
                        fillColor: AppTheme.surface,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Please enter a grace period';
                        if (int.tryParse(value) == null)
                          return 'Please enter a valid number';
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Leave Policy ──────────────────────────────────────────
              _buildSectionHeader('Leave Policy'),
              const SizedBox(height: 16),
              _buildSettingCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: AppTheme.primary, size: 18),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Set how many paid leave days each employee is entitled to per year. This applies to all employees in your company.',
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Paid leaves per year field
                    TextFormField(
                      controller: _paidLeavesController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Paid Leaves Per Year (Days)',
                        hintText: 'e.g. 12',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.beach_access_outlined,
                            color: AppTheme.primary),
                        filled: true,
                        fillColor: AppTheme.surface,
                        suffixText: 'days',
                        suffixStyle: const TextStyle(
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w600),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Please enter paid leaves per year';
                        final v = int.tryParse(value);
                        if (v == null) return 'Please enter a valid number';
                        if (v < 0) return 'Cannot be negative';
                        if (v > 365) return 'Cannot exceed 365 days';
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Quick-select chips
                    const Text(
                      'QUICK SELECT',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textHint,
                          letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [6, 9, 12, 15, 18, 21, 24].map((days) {
                        final isSelected =
                            _paidLeavesController.text == days.toString();
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _paidLeavesController.text = days.toString();
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.divider,
                              ),
                            ),
                            child: Text(
                              '$days days',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // ── Save Button ───────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('SAVE SETTINGS',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),

              const SizedBox(height: 24),
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
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, 10)),
        ],
      ),
      child: child,
    );
  }
}
