import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/screens/employee/employee_attendance_correction_screen.dart';

class EmployeeAttendanceDetailScreen extends StatefulWidget {
  final DateTime date;
  final Map<String, dynamic> data;

  const EmployeeAttendanceDetailScreen({
    super.key,
    required this.date,
    required this.data,
  });

  @override
  State<EmployeeAttendanceDetailScreen> createState() =>
      _EmployeeAttendanceDetailScreenState();
}

class _EmployeeAttendanceDetailScreenState
    extends State<EmployeeAttendanceDetailScreen> {
  Timer? _timer;
  late Map<String, dynamic> _attendanceData;

  @override
  void initState() {
    super.initState();
    _attendanceData = Map<String, dynamic>.from(widget.data);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final checkInTs = _attendanceData['checkIn'] as Timestamp?;
    final checkOutTs = _attendanceData['checkOut'] as Timestamp?;
    final dateStr = DateFormat('EEE, d MMM yyyy').format(widget.date);

    bool hasCheckedIn = checkInTs != null;
    bool hasCheckedOut = checkOutTs != null;

    String checkInStr = hasCheckedIn
        ? DateFormat('hh:mm a').format(checkInTs!.toDate())
        : '--:--';
    String checkOutStr = hasCheckedOut
        ? DateFormat('hh:mm a').format(checkOutTs!.toDate())
        : (hasCheckedIn ? 'Ongoing' : '--:--');

    String workingTimeStr = '0h 0m';
    if (hasCheckedIn) {
      if (hasCheckedOut) {
        final diff = checkOutTs!.toDate().difference(checkInTs!.toDate());
        workingTimeStr = '${diff.inHours}h ${diff.inMinutes % 60}m';
      } else {
        final diff = DateTime.now().difference(checkInTs!.toDate());
        workingTimeStr = '${diff.inHours}h ${diff.inMinutes % 60}m';
      }
    }

    String statusStr = 'Absent';
    Color statusColor = const Color(0xFFEF4444);
    Color statusBg = const Color(0xFFFEF2F2);
    if (hasCheckedIn) {
      statusStr = 'Present';
      statusColor = const Color(0xFF10B981);
      statusBg = const Color(0xFFECFDF5);
    }
    if (_attendanceData['status'] == 'late' ||
        _attendanceData['isLate'] == true) {
      statusStr = 'Late';
      statusColor = const Color(0xFFF59E0B);
      statusBg = const Color(0xFFFFFBEB);
    }
    if (_attendanceData['workMode'] == 'wfh') {
      statusStr = 'WFH';
      statusColor = const Color(0xFF5C5CFF);
      statusBg = const Color(0xFFEEF2FF);
    }

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
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF4B5563), size: 18),
        ),
        title: Text(
          dateStr,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(
                statusStr,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Detail content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Time Cards
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        checkInStr,
                                        style: const TextStyle(
                                          color: Color(0xFF059669),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Check In',
                                        style: TextStyle(
                                          color: Color(0xFF10B981),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        checkOutStr,
                                        style: const TextStyle(
                                          color: Color(0xFFD97706),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Check Out',
                                        style: TextStyle(
                                          color: Color(0xFFF59E0B),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSmallTimeBox(
                                    workingTimeStr, 'Working Hours'),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildSmallTimeBox('0 min', 'Overtime'),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildSmallTimeBox('1h 00m', 'Break'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Details Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DETAILS',
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildDetailRow('Shift', 'General Shift'),
                          const Divider(height: 32, color: Color(0xFFF3F4F6)),
                          _buildDetailRow('Work Mode', 'Office'),
                          const Divider(height: 32, color: Color(0xFFF3F4F6)),
                          _buildDetailRow(
                              'Attendance Method', 'Biometric + GPS'),
                          const Divider(height: 32, color: Color(0xFFF3F4F6)),
                          _buildDetailRow('GPS Accuracy', 'High (±3m)'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Check-in Location Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CHECK-IN LOCATION',
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEEF2FF),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.location_on_rounded,
                                    color: Color(0xFF5C5CFF), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppSession().companyName != null
                                          ? '${AppSession().companyName} HQ – Prestige Tech Park'
                                          : 'Bengaluru HQ – Prestige Tech Park',
                                      style: const TextStyle(
                                        color: Color(0xFF111827),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'GPS Verified · Inside office range',
                                      style: TextStyle(
                                        color: Color(0xFF9CA3AF),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Day Timeline Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DAY TIMELINE',
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildTimelineItem(
                            isFirst: true,
                            isLast: false,
                            title: 'Check In',
                            subtitle: AppSession().companyName != null
                                ? '${AppSession().companyName} HQ – Prestige Tech Park'
                                : 'Bengaluru HQ – Prestige Tech Park',
                            time: checkInStr,
                            color: const Color(0xFF5C5CFF),
                            isCompleted: hasCheckedIn,
                          ),
                          _buildTimelineItem(
                            isFirst: false,
                            isLast: true,
                            title: 'Check Out',
                            subtitle:
                                'Expected by ${AppSession().shiftEndTime}',
                            time: checkOutStr,
                            color: const Color(0xFFF59E0B),
                            isCompleted: hasCheckedOut,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Actions
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                EmployeeAttendanceCorrectionScreen(
                                    date: widget.date),
                          ),
                        );
                      },
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5C5CFF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.edit_outlined,
                                color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Request Correction',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.download_rounded,
                              color: Color(0xFF4B5563), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Download Record',
                            style: TextStyle(
                              color: Color(0xFF4B5563),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildSmallTimeBox(String top, String bottom) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Column(
        children: [
          Text(
            top,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            bottom,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem({
    required bool isFirst,
    required bool isLast,
    required String title,
    required String subtitle,
    required String time,
    required Color color,
    required bool isCompleted,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: isCompleted ? color : const Color(0xFFD1D5DB),
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: const Color(0xFFE5E7EB),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 32),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    time,
                    style: TextStyle(
                      color: isCompleted ? color : const Color(0xFFF59E0B),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
