import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/notification_helper.dart';
import 'package:attendance_app/utils/firestore_service.dart';

class EmployeeAttendanceCorrectionScreen extends StatefulWidget {
  final DateTime? date;

  const EmployeeAttendanceCorrectionScreen({super.key, this.date});

  @override
  State<EmployeeAttendanceCorrectionScreen> createState() =>
      _EmployeeAttendanceCorrectionScreenState();
}

class _EmployeeAttendanceCorrectionScreenState
    extends State<EmployeeAttendanceCorrectionScreen> {
  final _reasonController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _checkInTime;
  TimeOfDay? _checkOutTime;

  bool _isSubmitting = false;
  bool _isSubmitted = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    if (widget.date != null) {
      _selectedDate = widget.date!;
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
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF5C5CFF)),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _selectTime(bool isCheckIn) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF5C5CFF)),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() {
        if (isCheckIn) {
          _checkInTime = time;
        } else {
          _checkOutTime = time;
        }
      });
    }
  }

  Future<void> _submitRequest() async {
    if (_checkInTime == null && _checkOutTime == null) {
      setState(
          () => _errorMessage = 'Please provide at least one correct time.');
      return;
    }
    if (_reasonController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Reason is required.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      String? formatTime(TimeOfDay? t) {
        if (t == null) return null;
        final now = DateTime.now();
        final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
        return DateFormat('HH:mm').format(dt);
      }

      final senderRole = (AppSession().role ?? 'employee').toLowerCase();
      
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(FirestoreService.companyId)
          .collection('attendance_corrections')
          .add({
        'userId': user.email,
        'attendanceDate': Timestamp.fromDate(_selectedDate),
        'correctedCheckIn': formatTime(_checkInTime),
        'correctedCheckOut': formatTime(_checkOutTime),
        'reason': _reasonController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'senderRole': senderRole,
      });

      // Send notifications based on senderRole
      final title = 'Attendance Correction Request';
      final body = '${AppSession().userName ?? "Employee"} requested attendance correction for ${DateFormat('MMM dd').format(_selectedDate)}.';
      final extraData = {'employeeEmail': user.email};

      if (senderRole == 'admin') {
        await NotificationHelper.notifyAdmin(title: title, body: body, type: 'attendance_correction', extraData: extraData);
      } else if (senderRole == 'manager') {
        await NotificationHelper.notifyAdmin(title: title, body: body, type: 'attendance_correction', extraData: extraData);
      } else {
        await NotificationHelper.notifyManager(title: title, body: body, type: 'attendance_correction', extraData: extraData);
        await NotificationHelper.notifyAdmin(title: title, body: body, type: 'attendance_correction', extraData: extraData);
      }

      setState(() => _isSubmitted = true);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitted) return _buildSuccessScreen();

    final now = DateTime.now();

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
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF4B5563), size: 18),
        ),
        title: const Text(
          'Request Correction',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.edit_outlined, color: Color(0xFF5C5CFF), size: 20),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Form content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Attendance Date
                    _buildLabel('Attendance Date'),
                    GestureDetector(
                      onTap: _selectDate,
                      child: _buildInputBox(
                          DateFormat('EEE, dd MMM yyyy').format(_selectedDate)),
                    ),
                    const SizedBox(height: 20),

                    // Correct Check-In Time
                    _buildLabel('Correct Check-In Time'),
                    GestureDetector(
                      onTap: () => _selectTime(true),
                      child: _buildInputBox(
                          _checkInTime?.format(context) ?? '--:--'),
                    ),
                    const SizedBox(height: 20),

                    // Correct Check-Out Time
                    _buildLabel('Correct Check-Out Time'),
                    GestureDetector(
                      onTap: () => _selectTime(false),
                      child: _buildInputBox(
                          _checkOutTime?.format(context) ?? '--:--'),
                    ),
                    const SizedBox(height: 20),

                    // Reason
                    _buildLabel('Reason'),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: TextField(
                        controller: _reasonController,
                        maxLines: 4,
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF111827)),
                        decoration: const InputDecoration(
                          hintText: 'Describe the reason for correction...',
                          hintStyle:
                              TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Attachment
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.download_rounded,
                              color: Color(0xFF9CA3AF), size: 20),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Attachment (Optional)',
                                style: TextStyle(
                                  color: Color(0xFF111827),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Upload supporting document',
                                style: TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_errorMessage.isNotEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ),

                    // Action Buttons
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
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Color(0xFF4B5563),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
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
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Text(
                                      'Submit Request',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF4B5563),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
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
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF111827),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSuccessScreen() {
    final now = DateTime.now();
    final dateStr = DateFormat('EEE, d MMM yyyy').format(_selectedDate);

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
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF4B5563), size: 18),
        ),
        title: const Text(
          'Request Submitted',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                color: Colors.white,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: Color(0xFFECFDF5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_outline_rounded,
                          color: Color(0xFF10B981), size: 40),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Request Submitted',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your correction request for $dateStr has been submitted. Your manager will review it shortly.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5C5CFF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Back to Attendance',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
