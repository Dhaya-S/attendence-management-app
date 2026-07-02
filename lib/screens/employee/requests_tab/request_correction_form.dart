import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:attendance_app/utils/firestore_service.dart';

/// Screen 3 — Attendance Correction form (matches right panel in mockup)
/// Also used as edit form when editItem is provided.
class RequestCorrectionForm extends StatefulWidget {
  final Map<String, dynamic>? editItem;
  const RequestCorrectionForm({super.key, this.editItem});

  @override
  State<RequestCorrectionForm> createState() => _RequestCorrectionFormState();
}

class _RequestCorrectionFormState extends State<RequestCorrectionForm> {
  final _reasonController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _checkInTime;
  TimeOfDay? _checkOutTime;

  bool _isSubmitting = false;
  bool _isSubmitted = false;
  bool _reasonError = false;

  @override
  void initState() {
    super.initState();
    if (widget.editItem != null) {
      final item = widget.editItem!;
      _reasonController.text = item['reason'] ?? '';
      final dateTs = item['requestedDate'] as Timestamp?;
      if (dateTs != null) _selectedDate = dateTs.toDate();
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF5C5CFF))),
        child: child!,
      ),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _selectTime(bool isCheckIn) async {
    final time = await showTimePicker(
      context: context,
      initialTime: isCheckIn ? (_checkInTime ?? TimeOfDay.now()) : (_checkOutTime ?? TimeOfDay.now()),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF5C5CFF))),
        child: child!,
      ),
    );
    if (time != null) {
      setState(() {
        if (isCheckIn) _checkInTime = time;
        else _checkOutTime = time;
      });
    }
  }

  Future<void> _submitRequest() async {
    if (_reasonController.text.trim().isEmpty) {
      setState(() => _reasonError = true);
      return;
    }
    setState(() { _isSubmitting = true; _reasonError = false; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      String? formatTime(TimeOfDay? t) {
        if (t == null) return null;
        final now = DateTime.now();
        final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
        return DateFormat('HH:mm').format(dt);
      }

      final data = {
        'userId': user.email,
        'attendanceDate': Timestamp.fromDate(_selectedDate),
        'correctedCheckIn': formatTime(_checkInTime),
        'correctedCheckOut': formatTime(_checkOutTime),
        'reason': _reasonController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.editItem != null) {
        await FirebaseFirestore.instance
            .collection('approved_companies')
            .doc(FirestoreService.companyId)
            .collection('attendance_corrections')
            .doc(widget.editItem!['id'])
            .update({...data, 'createdAt': widget.editItem!['submittedAt']});
      } else {
        await FirebaseFirestore.instance
            .collection('approved_companies')
            .doc(FirestoreService.companyId)
            .collection('attendance_corrections')
            .add(data);
      }

      setState(() => _isSubmitted = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitted) return _buildSuccessScreen();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF3F4F6), height: 1),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF4B5563)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.editItem != null ? 'Edit Correction' : 'Attendance Correction',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.edit_outlined, color: Color(0xFF5C5CFF), size: 20),
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Attendance Date
              _buildLabel('Attendance Date'),
              GestureDetector(
                onTap: _selectDate,
                child: _buildInputBox(DateFormat('EEE, dd MMM yyyy').format(_selectedDate)),
              ),
              const SizedBox(height: 20),

              // Check-In
              _buildLabel('Correct Check-In Time'),
              GestureDetector(
                onTap: () => _selectTime(true),
                child: _buildInputBox(_checkInTime?.format(context) ?? '--:--'),
              ),
              const SizedBox(height: 20),

              // Check-Out
              _buildLabel('Correct Check-Out Time'),
              GestureDetector(
                onTap: () => _selectTime(false),
                child: _buildInputBox(_checkOutTime?.format(context) ?? '--:--'),
              ),
              const SizedBox(height: 20),

              // Reason
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 13, color: Color(0xFF4B5563), fontWeight: FontWeight.w600),
                  children: [
                    TextSpan(text: 'Reason '),
                    TextSpan(text: '*', style: TextStyle(color: Color(0xFFEF4444))),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _reasonError ? const Color(0xFFEF4444) : const Color(0xFFE5E7EB)),
                ),
                child: TextField(
                  controller: _reasonController,
                  maxLines: 4,
                  onChanged: (_) { if (_reasonError) setState(() => _reasonError = false); },
                  style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
                  decoration: const InputDecoration(
                    hintText: 'Describe the reason...',
                    hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
              if (_reasonError)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Reason is required', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
                ),
              const SizedBox(height: 20),

              // Attachment
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.upload_file_outlined, color: Color(0xFF9CA3AF), size: 20),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Attachment (Optional)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                        SizedBox(height: 2),
                        Text('Upload supporting document',
                            style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF4B5563))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _isSubmitting ? null : _submitRequest,
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5C5CFF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Submit Request',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildInputBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF111827))),
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              // Success icon
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(color: Color(0xFFECFDF5), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 40),
              ),
              const SizedBox(height: 24),
              const Text('Request Submitted',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
              const SizedBox(height: 12),
              const Text(
                'Your request has been submitted and sent to your manager for approval.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.6),
              ),
              const SizedBox(height: 32),
              // What happens next
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('What happens next?',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                    const SizedBox(height: 16),
                    _NextStep(number: '1', text: 'Manager reviews your request'),
                    const SizedBox(height: 12),
                    _NextStep(number: '2', text: 'You receive a notification'),
                    const SizedBox(height: 12),
                    _NextStep(number: '3', text: 'Attendance is updated'),
                  ],
                ),
              ),
              const Spacer(),
              // Back button
              GestureDetector(
                onTap: () => Navigator.of(context)
                    .popUntil((route) => route.isFirst || route.settings.name == '/attendance'),
                child: Container(
                  width: double.infinity,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5C5CFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Back to Requests',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextStep extends StatelessWidget {
  final String number;
  final String text;
  const _NextStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Color(0xFFEEF2FF), shape: BoxShape.circle),
          child: Text(number,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF5C5CFF))),
        ),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF374151), fontWeight: FontWeight.w500)),
      ],
    );
  }
}
