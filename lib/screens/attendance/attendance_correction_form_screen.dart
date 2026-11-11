import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AttendanceCorrectionFormScreen extends StatefulWidget {
  final DocumentReference? existingRef;
  final Map<String, dynamic>? existingData;
  final String requestType; // 'Attendance Correction', 'Work From Home', or a Leave Type

  const AttendanceCorrectionFormScreen({
    super.key,
    this.existingRef,
    this.existingData,
    this.requestType = 'Attendance Correction',
  });

  @override
  State<AttendanceCorrectionFormScreen> createState() => _AttendanceCorrectionFormScreenState();
}

class _AttendanceCorrectionFormScreenState extends State<AttendanceCorrectionFormScreen> {
  final _reasonController = TextEditingController();
  
  // For Attendance Correction
  DateTime _attendanceDate = DateTime.now();
  TimeOfDay _checkInTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _checkOutTime = const TimeOfDay(hour: 18, minute: 0);
  
  // For Leave / WFH
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  String _leaveType = 'Sick Leave';
  
  bool _isLoading = false;

  bool get isCorrection => widget.requestType == 'Attendance Correction';
  bool get isWfh => widget.requestType == 'Work From Home';
  bool get isLeave => !isCorrection && !isWfh;

  final List<String> leaveTypes = ['Sick Leave', 'Casual Leave', 'Paid Leave', 'Unpaid Leave'];

  @override
  void initState() {
    super.initState();
    _leaveType = (isLeave ? widget.requestType : 'Sick Leave');

    if (widget.existingData != null) {
      final data = widget.existingData!;
      _reasonController.text = data['reason'] ?? '';
      
      // Load Correction data
      if (isCorrection) {
        final date = FirestoreService.parseAnyDate(
            data['date'] ?? data['attendanceDate'] ?? data['requestedDate']);
        if (date != null) _attendanceDate = date;

        final ci = FirestoreService.parseTimeOnDay(
            data['requestedCheckIn'] ?? data['correctedCheckIn'] ?? data['checkInTime'],
            _attendanceDate);
        if (ci != null) _checkInTime = TimeOfDay.fromDateTime(ci);

        final co = FirestoreService.parseTimeOnDay(
            data['requestedCheckOut'] ?? data['correctedCheckOut'] ?? data['checkOutTime'],
            _attendanceDate);
        if (co != null) _checkOutTime = TimeOfDay.fromDateTime(co);
      } else {
        // Load Leave/WFH data
        final fDate = FirestoreService.parseAnyDate(
            data['fromDate'] ?? data['from'] ?? data['requestedDate']);
        if (fDate != null) _fromDate = fDate;

        final tDate = FirestoreService.parseAnyDate(data['toDate'] ?? data['to']);
        if (tDate != null) {
          _toDate = tDate;
        } else {
          _toDate = _fromDate; // fallback
        }

        if (data['leaveType'] != null) {
          _leaveType = data['leaveType'];
        }
      }
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isCorrection ? _attendanceDate : (isFrom ? _fromDate : _toDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
        if (isCorrection) {
          _attendanceDate = picked;
        } else {
          if (isFrom) {
            _fromDate = picked;
            if (_toDate.isBefore(_fromDate)) _toDate = _fromDate;
          } else {
            _toDate = picked;
            if (_toDate.isBefore(_fromDate)) _fromDate = _toDate;
          }
        }
      });
    }
  }

  Future<void> _selectTime(bool isCheckIn) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isCheckIn ? _checkInTime : _checkOutTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isCheckIn) {
          _checkInTime = picked;
        } else {
          _checkOutTime = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email ?? '';
      
      final fmt12 = DateFormat('hh:mm a'); // web format: "09:00 AM"
      DateTime onDay(DateTime d, TimeOfDay t) =>
          DateTime(d.year, d.month, d.day, t.hour, t.minute);
      final reasonText = _reasonController.text.trim();

      if (isCorrection) {
        // Attendance corrections live in organizations/{cid}/attendance_issues (web shape)
        final inStr = fmt12.format(onDay(_attendanceDate, _checkInTime));
        final outStr = fmt12.format(onDay(_attendanceDate, _checkOutTime));
        if (widget.existingRef != null) {
          // status / createdBy are never changed when editing
          await widget.existingRef!.update({
            'date': DateFormat('yyyy-MM-dd').format(_attendanceDate),
            'requestedCheckIn': inStr,
            'requestedCheckOut': outStr,
            'reason': reasonText,
            'updatedAt': DateTime.now().toIso8601String(),
          });
        } else {
          await FirestoreService.submitAttendanceIssue(
            date: _attendanceDate,
            requestedCheckIn: inStr,
            requestedCheckOut: outStr,
            reason: reasonText,
          );
        }
      } else {
        final diff = _toDate.difference(_fromDate).inDays + 1;
        final typeName = isWfh ? 'Work From Home' : _leaveType;
        if (widget.existingRef != null) {
          final edit = <String, dynamic>{
            'type': typeName,
            'leaveType': typeName,
            'from': DateFormat('yyyy-MM-dd').format(_fromDate),
            'to': DateFormat('yyyy-MM-dd').format(_toDate),
            'fromDate': Timestamp.fromDate(_fromDate),
            'toDate': Timestamp.fromDate(_toDate),
            'days': diff,
            'durationInDays': diff,
            'reason': reasonText,
            'updatedAt': DateTime.now().toIso8601String(),
          };
          await widget.existingRef!.update(edit);
          // keep the company-queue copy in sync
          try {
            await FirestoreService.leaveRequestsCol
                .doc(widget.existingRef!.id)
                .set(edit, SetOptions(merge: true));
          } catch (_) {}
        } else {
          // Leave / WFH → same dual write as the web Leave page
          await FirestoreService.submitLeaveRequest(data: {
            'type': typeName,
            'leaveType': typeName,
            'fromDate': _fromDate,
            'toDate': _toDate,
            'days': diff,
            'reason': reasonText,
          });
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request submitted successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, color: AppTheme.textPrimary, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.requestType,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppTheme.primary),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isLeave) ...[
                    _buildLabel('Leave Type'),
                    _buildLeaveTypeDropdown(),
                    const SizedBox(height: 20),
                  ],
                  if (isCorrection) ...[
                    _buildLabel('Attendance Date'),
                    _buildDateField(true),
                    const SizedBox(height: 20),
                    _buildLabel('Correct Check-In Time'),
                    _buildTimeField(true),
                    const SizedBox(height: 20),
                    _buildLabel('Correct Check-Out Time'),
                    _buildTimeField(false),
                    const SizedBox(height: 20),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('From Date'),
                              _buildDateField(true),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('To Date'),
                              _buildDateField(false),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  _buildLabel('Reason *'),
                  _buildReasonField(),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    child: Text('Reason is required',
                        style: TextStyle(fontSize: 11, color: AppTheme.danger.withOpacity(0.8))),
                  ),
                  _buildAttachmentField(),
                  const SizedBox(height: 40),
                  _buildBottomActions(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary)),
    );
  }

  Widget _buildLeaveTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: leaveTypes.contains(_leaveType) ? _leaveType : leaveTypes.first,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted),
          items: leaveTypes.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _leaveType = val);
          },
        ),
      ),
    );
  }

  Widget _buildDateField(bool isFrom) {
    final date = isCorrection ? _attendanceDate : (isFrom ? _fromDate : _toDate);
    return InkWell(
      onTap: () => _selectDate(isFrom),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(DateFormat('dd MMM yyyy').format(date),
                style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
            const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField(bool isCheckIn) {
    final time = isCheckIn ? _checkInTime : _checkOutTime;
    return InkWell(
      onTap: () => _selectTime(isCheckIn),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(time.format(context),
                style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
            const Icon(Icons.access_time_rounded, size: 18, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonField() {
    return TextField(
      controller: _reasonController,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: 'Describe the reason...',
        hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary),
        ),
      ),
    );
  }

  Widget _buildAttachmentField() {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Attachment functionality coming soon!')));
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            const Icon(Icons.file_upload_outlined, color: AppTheme.textMuted, size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Attachment (Optional)',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text('Upload supporting document',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textHint)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFF3F4F6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Cancel',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(widget.existingRef != null ? 'Update Request' : 'Submit Request',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ),
      ],
    );
  }
}
