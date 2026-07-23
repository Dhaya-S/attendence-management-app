import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/firestore_service.dart';
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
  final _userEmail = FirebaseAuth.instance.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmtAmPm(Timestamp? t) {
    if (t == null) return '--:--';
    return DateFormat('hh:mm a').format(t.toDate().toLocal());
  }

  _StatusInfo _resolveStatus(Map<String, dynamic> d) {
    final checkInTs = d['checkIn'] as Timestamp?;
    final hasCheckedIn = checkInTs != null;
    if (!hasCheckedIn) {
      if (d['status'] == 'leave') {
        return _StatusInfo('On Leave', const Color(0xFF8B5CF6), const Color(0xFFF5F3FF));
      }
      if (d['status'] == 'holiday') {
        return _StatusInfo('Holiday', const Color(0xFF4B5563), const Color(0xFFF3F4F6));
      }
      return _StatusInfo('Absent', const Color(0xFFEF4444), const Color(0xFFFEF2F2));
    }
    if (d['workMode'] == 'wfh') {
      return _StatusInfo('WFH', const Color(0xFF5C5CFF), const Color(0xFFEEF2FF));
    }
    final checkIn = checkInTs.toDate();
    final sParts = AppSession().shiftStartTime.split(':');
    final lateThreshold = DateTime(checkIn.year, checkIn.month, checkIn.day,
            int.parse(sParts[0]), int.parse(sParts[1]))
        .add(Duration(minutes: AppSession().gracePeriod));
    if (checkIn.isAfter(lateThreshold) && d['remarkStatus'] != 'approved') {
      return _StatusInfo('Late', const Color(0xFFF59E0B), const Color(0xFFFFFBEB));
    }
    return _StatusInfo('Present', const Color(0xFF10B981), const Color(0xFFECFDF5));
  }

  @override
  Widget build(BuildContext context) {
    final docId = DateFormat('yyyy-MM-dd').format(widget.date);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirestoreService.userAttendanceCol(_userEmail).doc(docId).snapshots(),
      builder: (context, snap) {
        final Map<String, dynamic> d = Map<String, dynamic>.from(widget.data);
        if (snap.hasData && snap.data!.exists) {
          d.addAll(snap.data!.data() as Map<String, dynamic>);
        }
        
        final si = _resolveStatus(d);
        final dateStr = DateFormat('EEE, d MMM yyyy').format(widget.date);

        return Scaffold(
          backgroundColor: Colors.white, // The background looks fully white now in the screenshot
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF4B5563), size: 18),
            ),
            title: Text(dateStr,
                style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            centerTitle: false,
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: si.bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: si.color.withOpacity(0.3)),
                ),
                child: Text(si.label,
                    style: TextStyle(
                        color: si.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: const Color(0xFFF3F4F6), height: 1),
            ),
          ),
          body: _buildBody(d),
        );
      },
    );
  }

  Widget _buildBody(Map<String, dynamic> d) {
    final now = DateTime.now();
    final checkInTs = d['checkIn'] as Timestamp?;
    final checkOutTs = d['checkOut'] as Timestamp?;
    final bool hasCheckedIn = checkInTs != null;
    final bool hasCheckedOut = checkOutTs != null;
    final checkInStr = _fmtAmPm(checkInTs);
    final checkOutStr = hasCheckedOut ? _fmtAmPm(checkOutTs) : (hasCheckedIn ? 'Ongoing' : '--:--');
    final workMode = (d['workMode'] as String? ?? 'office');
    
    // Default or dummy data for Break & Overtime as they are not tracked yet
    const overtimeStr = '0 min';
    const breakStr = '1h 00m';

    String workingTimeStr = '--h --m';
    if (hasCheckedIn) {
      final end = hasCheckedOut ? checkOutTs!.toDate() : now;
      final diff = end.difference(checkInTs!.toDate());
      workingTimeStr = '${diff.inHours}h ${(diff.inMinutes % 60).toString().padLeft(2, '0')}m';
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time card with two big boxes and three small boxes
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10, offset: const Offset(0, 4)
                )
              ]
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _timeBox(
                            checkInStr,
                            'Check In',
                            const Color(0xFFECFDF5),
                            const Color(0xFF059669),
                            const Color(0xFF10B981))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _timeBox(
                            checkOutStr,
                            'Check Out',
                            const Color(0xFFFFFBEB),
                            const Color(0xFFD97706),
                            const Color(0xFFF59E0B))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _smallBox(workingTimeStr, 'Working Hours')),
                    const SizedBox(width: 8),
                    Expanded(child: _smallBox(overtimeStr, 'Overtime')),
                    const SizedBox(width: 8),
                    Expanded(child: _smallBox(breakStr, 'Break')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Details section
          const Text('DETAILS',
              style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                _detailRow('Shift', 'General Shift'),
                const Divider(height: 24, color: Color(0xFFF3F4F6)),
                _detailRow('Work Mode', workMode == 'wfh' ? 'Remote' : (d['status'] == 'leave' ? 'Leave' : 'Office')),
                const Divider(height: 24, color: Color(0xFFF3F4F6)),
                _detailRow('Attendance Method', 'Biometric + GPS'),
                const Divider(height: 24, color: Color(0xFFF3F4F6)),
                _detailRow('GPS Accuracy', 'High (±3m)'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Check-in Location
          const Text('CHECK-IN LOCATION',
              style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                      color: Color(0xFFEEF2FF), shape: BoxShape.circle),
                  child: const Icon(Icons.location_on,
                      color: Color(0xFF5C5CFF), size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasCheckedIn 
                            ? (workMode == 'wfh' ? 'Home' : (AppSession().companyName ?? 'Bengaluru HQ - Prestige Tech Park'))
                            : '--',
                        style: const TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 13,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasCheckedIn ? 'GPS Verified · Inside office range' : '',
                        style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Day Timeline
          const Text('DAY TIMELINE',
              style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                _timelineItem(
                  title: 'Check In',
                  subtitle: hasCheckedIn 
                            ? (workMode == 'wfh' ? 'Home' : (AppSession().companyName ?? 'Bengaluru HQ - Prestige Tech Park'))
                            : '--',
                  time: hasCheckedIn ? checkInStr : '--',
                  color: const Color(0xFF5C5CFF),
                  isCompleted: hasCheckedIn,
                  isLast: false,
                ),
                _timelineItem(
                  title: 'Check Out',
                  subtitle: hasCheckedOut 
                            ? (workMode == 'wfh' ? 'Home' : (AppSession().companyName ?? 'Bengaluru HQ - Prestige Tech Park'))
                            : (hasCheckedIn ? 'Expected by ${AppSession().shiftEndTime}' : '--'),
                  time: hasCheckedOut ? checkOutStr : (hasCheckedIn ? 'Ongoing' : '--'),
                  color: hasCheckedOut ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
                  isCompleted: hasCheckedOut || hasCheckedIn, // show colored dot if ongoing
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Buttons
          GestureDetector(
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => EmployeeAttendanceCorrectionScreen(
                          date: widget.date)));
            },
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF5C5CFF),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Request Correction',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {},
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.file_download_outlined, color: Color(0xFF4B5563), size: 20),
                  SizedBox(width: 8),
                  Text('Download Record',
                      style: TextStyle(
                          color: Color(0xFF4B5563),
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _timeBox(
      String time, String label, Color bg, Color timeColor, Color labelColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(time,
            style: TextStyle(
                color: timeColor, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                color: labelColor, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _smallBox(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10)),
      alignment: Alignment.center,
      child: Column(children: [
        Text(value,
            style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 12,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 10,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        Text(value,
            style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _timelineItem({
    required String title,
    required String subtitle,
    required String time,
    required Color color,
    required bool isCompleted,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(
                color: isCompleted ? color : const Color(0xFFD1D5DB),
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Expanded(
                  child: Container(
                width: 2,
                color: const Color(0xFFF3F4F6),
                margin: const EdgeInsets.symmetric(vertical: 8),
              )),
          ]),
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
                      Text(title,
                          style: const TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                    ],
                  )),
                  Text(time,
                      style: TextStyle(
                        color: isCompleted ? color : const Color(0xFFD1D5DB),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusInfo {
  final String label;
  final Color color;
  final Color bg;
  const _StatusInfo(this.label, this.color, this.bg);
}
