import 'package:attendance_app/screens/employee/employee_attendance_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/notification_helper.dart';
import 'package:attendance_app/utils/notification_service.dart';

class EmployeeAttendanceOverviewTab extends StatefulWidget {
  const EmployeeAttendanceOverviewTab({super.key});

  @override
  State<EmployeeAttendanceOverviewTab> createState() =>
      _EmployeeAttendanceOverviewTabState();
}

class _EmployeeAttendanceOverviewTabState
    extends State<EmployeeAttendanceOverviewTab> {
  final user = FirebaseAuth.instance.currentUser;
  late Stream<QuerySnapshot> _attendanceStream;
  Timer? _timer;
  bool _isCheckingInOut = false;

  @override
  void initState() {
    super.initState();
    _attendanceStream =
        FirestoreService.userAttendanceCol(user?.email ?? '').snapshots();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _getAttendanceDocId() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  Future<void> _handleCheckInOut(String status, bool isCheckIn) async {
    if (_isCheckingInOut) return;
    setState(() => _isCheckingInOut = true);
    try {
      final now = DateTime.now();
      final userEmail = user?.email ?? '';

      final data = {
        'companyId': FirestoreService.companyId,
        'userId': userEmail,
        'status': status,
        if (isCheckIn) 'workMode': 'office', // default
        if (isCheckIn) 'checkIn': Timestamp.fromDate(now),
        if (!isCheckIn) 'checkOut': Timestamp.fromDate(now),
        'date': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
        'recordDate': DateFormat('yyyy-MM-dd').format(now),
      };

      await FirestoreService.userAttendanceCol(userEmail)
          .doc(_getAttendanceDocId())
          .set(data, SetOptions(merge: true));

      await NotificationHelper.notifyEmployee(
        employeeEmail: userEmail,
        title: isCheckIn ? 'Check-In Successful âœ…' : 'Check-Out Successful ðŸ‘‹',
        body:
            'You have successfully ${isCheckIn ? 'checked in' : 'checked out'} at ${DateFormat('hh:mm a').format(now)}.',
        type: isCheckIn ? 'check_in' : 'check_out',
        extraData: {'userId': user?.uid},
      );

      if (isCheckIn) {
        final eParts = AppSession().shiftEndTime.split(':');
        final shiftEnd = DateTime(now.year, now.month, now.day,
            int.parse(eParts[0]), int.parse(eParts[1]));
        await NotificationService().scheduleCheckoutReminder(shiftEnd);
      } else {
        await NotificationService().cancelCheckoutReminder();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: AppTheme.danger));
      }
    } finally {
      if (mounted) setState(() => _isCheckingInOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _attendanceStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        final now = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(now);

        Map<String, dynamic>? todayData;
        try {
          final doc = docs.firstWhere((d) => d.id == todayStr);
          todayData = doc.data() as Map<String, dynamic>;
        } catch (_) {}

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTodayAttendanceCard(todayData),
              const SizedBox(height: 16),
              _buildThisWeekCard(docs),
              const SizedBox(height: 16),
              _buildMonthlyCard(docs),
              const SizedBox(height: 16),
              _buildShiftCard(),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTodayAttendanceCard(Map<String, dynamic>? todayData) {
    final now = DateTime.now();
    bool hasCheckedIn = todayData != null && todayData['checkIn'] != null;
    bool hasCheckedOut = todayData != null && todayData['checkOut'] != null;
    Timestamp? checkInTs = todayData?['checkIn'];
    Timestamp? checkOutTs = todayData?['checkOut'];

    String checkInStr = '--:--';
    String checkOutStr = 'Ongoing';
    String workingTimeStr = '0h 0m';
    String statusStr = 'Not Started';
    Color statusColor = const Color(0xFF6B7280);
    Color statusBgColor = const Color(0xFFF3F4F6);
    Color statusBorderColor = const Color(0xFFE5E7EB);

    int lateBufferMinutes = 0;
    try {
      if (checkInTs != null) {
        final sParts = AppSession().shiftStartTime.split(':');
        final expectedCheckIn = DateTime(now.year, now.month, now.day,
            int.parse(sParts[0]), int.parse(sParts[1]));
        if (checkInTs.toDate().isAfter(expectedCheckIn)) {
          lateBufferMinutes =
              checkInTs.toDate().difference(expectedCheckIn).inMinutes;
        }
      }
    } catch (_) {}

    if (hasCheckedIn) {
      checkInStr = DateFormat('hh:mm a').format(checkInTs!.toDate());
      if (hasCheckedOut) {
        statusStr = 'Completed';
        statusColor = const Color(0xFF059669);
        statusBgColor = const Color(0xFFECFDF5);
        statusBorderColor = const Color(0xFFA7F3D0);

        checkOutStr = DateFormat('hh:mm a').format(checkOutTs!.toDate());
        final diff = checkOutTs.toDate().difference(checkInTs.toDate());
        workingTimeStr = '${diff.inHours}h ${diff.inMinutes % 60}m';
      } else {
        statusStr = 'Present';
        statusColor = const Color(0xFF059669);
        statusBgColor = const Color(0xFFECFDF5);
        statusBorderColor = const Color(0xFFA7F3D0);

        final diff = now.difference(checkInTs.toDate());
        workingTimeStr = '${diff.inHours}h ${diff.inMinutes % 60}m';
      }
    } else {
      statusStr = 'Not Started';
      checkOutStr = '--:--';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "TODAY'S ATTENDANCE",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusBorderColor),
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
            ],
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEEE, d MMMM yyyy').format(now),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _buildStatBox(
                      checkInStr,
                      'Check In',
                      hasCheckedIn
                          ? const Color(0xFF059669)
                          : const Color(0xFF4B5563))),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildStatBox(
                      checkOutStr,
                      'Check Out',
                      hasCheckedIn && !hasCheckedOut
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF4B5563))),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildStatBox(
                      workingTimeStr,
                      'Working',
                      hasCheckedIn
                          ? const Color(0xFF5C5CFF)
                          : const Color(0xFF4B5563))),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildStatBox(
                      '$lateBufferMinutes min',
                      'Late Buffer',
                      lateBufferMinutes > 0
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF4B5563))),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 16, color: Color(0xFF5C5CFF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppSession().companyName != null ? '${AppSession().companyName} HQ' : 'Bengaluru HQ â€“ Prestige Tech Park',
                    style: const TextStyle(
                      color: Color(0xFF5C5CFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    Icon(Icons.wifi, size: 14, color: Color(0xFF10B981)),
                    SizedBox(height: 2),
                    Text(
                      'GPS Active',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: () {
                    if (hasCheckedIn && !hasCheckedOut) {
                      _handleCheckInOut('checked_out', false);
                    } else if (!hasCheckedIn) {
                      _handleCheckInOut('checked_in', true);
                    }
                  },
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (!hasCheckedIn || hasCheckedOut)
                          ? const Color(0xFFEEF2FF)
                          : const Color(0xFFFEF2F2),
                      border: Border.all(
                          color: (!hasCheckedIn || hasCheckedOut)
                              ? const Color(0xFFC7D2FE)
                              : const Color(0xFFFECACA)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _isCheckingInOut
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                  (!hasCheckedIn || hasCheckedOut)
                                      ? Icons.login_rounded
                                      : Icons.logout_rounded,
                                  size: 18,
                                  color: (!hasCheckedIn || hasCheckedOut)
                                      ? const Color(0xFF5C5CFF)
                                      : const Color(0xFFDC2626)),
                              const SizedBox(width: 8),
                              Text(
                                (!hasCheckedIn || hasCheckedOut)
                                    ? 'Check In'
                                    : 'Check Out',
                                style: TextStyle(
                                  color: (!hasCheckedIn || hasCheckedOut)
                                      ? const Color(0xFF5C5CFF)
                                      : const Color(0xFFDC2626),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EmployeeAttendanceDetailScreen(
                          date: now,
                          data: todayData ?? {},
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.info_outline_rounded,
                            size: 18, color: Color(0xFF4B5563)),
                        SizedBox(width: 8),
                        Text(
                          'Detail',
                          style: TextStyle(
                            color: Color(0xFF4B5563),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String val, String label, Color valColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Text(
            val,
            style: TextStyle(
              color: valColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThisWeekCard(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final currentDayOfWeek = now.weekday; // 1=Mon, 7=Sun
    final startOfWeek = now.subtract(Duration(days: currentDayOfWeek - 1));

    List<Widget> dayWidgets = [];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

    for (int i = 0; i < 5; i++) {
      final date = startOfWeek.add(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      Map<String, dynamic>? data;
      try {
        data = docs.firstWhere((d) => d.id == dateStr).data()
            as Map<String, dynamic>?;
      } catch (_) {}

      String status = 'A';
      Color color = const Color(0xFF9CA3AF);
      Color bg = const Color(0xFFF3F4F6);

      if (data != null && data['status'] != null) {
        final st = data['status'];
        if (st == 'checked_in' || st == 'checked_out') {
          status = 'P';
          color = const Color(0xFF10B981);
          bg = const Color(0xFFECFDF5);
        } else if (st == 'leave' || data['leaveType'] != null) {
          status = 'L';
          color = const Color(0xFF8B5CF6);
          bg = const Color(0xFFF5F3FF);
        }
        if (data['isLate'] == true) {
          status = 'L';
          color = const Color(0xFFF59E0B);
          bg = const Color(0xFFFFFBEB);
        }
        if (data['workMode'] == 'wfh') {
          status = 'W';
          color = const Color(0xFF5C5CFF);
          bg = const Color(0xFFEEF2FF);
        }
      } else {
        if (date.isBefore(DateTime(now.year, now.month, now.day))) {
          status = 'A';
          color = const Color(0xFFEF4444);
          bg = const Color(0xFFFEF2F2);
        } else if (date.isAfter(now)) {
          status = '-';
          color = const Color(0xFFD1D5DB);
          bg = Colors.transparent;
        }
      }

      dayWidgets.add(_buildDayDot(days[i], status, color, bg));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'THIS WEEK',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                children: const [
                  Text(
                    'View History',
                    style: TextStyle(
                      color: Color(0xFF5C5CFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded,
                      size: 14, color: Color(0xFF5C5CFF)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: dayWidgets,
          ),
        ],
      ),
    );
  }

  Widget _buildDayDot(String day, String initial, Color color, Color bg) {
    return Column(
      children: [
        Text(
          day,
          style: const TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: bg == Colors.transparent
                ? Border.all(color: const Color(0xFFE5E7EB))
                : null,
          ),
          child: Text(
            initial,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: initial != '-' ? color : Colors.transparent,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyCard(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final monthPrefix = DateFormat('yyyy-MM').format(now);
    final monthDocs = docs.where((d) => d.id.startsWith(monthPrefix)).toList();

    int present = 0;
    int lateCount = 0;
    int wfh = 0;
    int leave = 0;

    for (var doc in monthDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final st = data['status'];
      if (st == 'checked_in' || st == 'checked_out') {
        present++;
      }
      if (data['isLate'] == true) {
        lateCount++;
      }
      if (data['workMode'] == 'wfh') {
        wfh++;
      }
      if (st == 'leave' || data['leaveType'] != null) {
        leave++;
      }
    }

    // Rough attendance rate calculation based on working days so far
    int workingDaysPassed = 0;
    for (int i = 1; i <= now.day; i++) {
      final date = DateTime(now.year, now.month, i);
      if (date.weekday != DateTime.saturday &&
          date.weekday != DateTime.sunday) {
        workingDaysPassed++;
      }
    }
    double rate =
        workingDaysPassed > 0 ? (present / workingDaysPassed) * 100 : 100.0;
    if (rate > 100) rate = 100;

    final monthStr = DateFormat('MMMM yyyy').format(now).toUpperCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$monthStr â€“ MONTHLY',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _buildMonthStatBox('$present', 'Present',
                      const Color(0xFF10B981), const Color(0xFFECFDF5))),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildMonthStatBox('$lateCount', 'Late',
                      const Color(0xFFF59E0B), const Color(0xFFFFFBEB))),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildMonthStatBox('$wfh', 'WFH',
                      const Color(0xFF5C5CFF), const Color(0xFFEEF2FF))),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildMonthStatBox('$leave', 'Leave',
                      const Color(0xFF8B5CF6), const Color(0xFFF5F3FF))),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Attendance Rate',
                  style: TextStyle(
                    color: Color(0xFF5C5CFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${rate.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Color(0xFF5C5CFF),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthStatBox(
      String val, String label, Color valColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            val,
            style: TextStyle(
              color: valColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
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

  Widget _buildShiftCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "TODAY'S SHIFT",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
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
                child: const Icon(Icons.access_time_rounded,
                    color: Color(0xFF5C5CFF), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'General Shift',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${AppSession().shiftStartTime} â€“ ${AppSession().shiftEndTime} Â· Office',
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  Text(
                    'Manager',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Sarah M.',
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

