import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:ui';

import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/notification_helper.dart';
import 'package:attendance_app/utils/notification_service.dart';
import 'package:attendance_app/screens/employee/employee_attendance_detail_screen.dart';
import 'package:attendance_app/screens/employee/attendance_history_screen.dart';

/// Overview tab â€” shows today's attendance card, this week progress,
/// monthly summary, today's shift, and quick actions.
/// Real-time via Firestore streams + a 1-second timer for the live clock.
class AttendanceOverviewTab extends StatefulWidget {
  const AttendanceOverviewTab({super.key});

  @override
  State<AttendanceOverviewTab> createState() => _AttendanceOverviewTabState();
}

class _AttendanceOverviewTabState extends State<AttendanceOverviewTab> {
  final _user = FirebaseAuth.instance.currentUser;
  late Stream<QuerySnapshot> _attendanceStream;
  Timer? _timer;
  bool _isCheckingInOut = false;

  String get _role => AppSession().role?.toLowerCase() ?? 'employee';

  @override
  void initState() {
    super.initState();
    _attendanceStream =
        FirestoreService.userAttendanceCol(_user?.email ?? '').snapshots();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Check-In / Check-Out â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String _getDocId() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> _handleCheckInOut(String status, bool isCheckIn) async {
    if (_isCheckingInOut) return;
    setState(() => _isCheckingInOut = true);
    try {
      final now = DateTime.now();
      final email = _user?.email ?? '';
      final data = {
        'companyId': FirestoreService.companyId,
        'userId': email,
        'status': status,
        if (isCheckIn) 'workMode': 'office',
        if (isCheckIn) 'checkIn': Timestamp.fromDate(now),
        if (!isCheckIn) 'checkOut': Timestamp.fromDate(now),
        'date': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
        'recordDate': DateFormat('yyyy-MM-dd').format(now),
      };

      await FirestoreService.userAttendanceCol(email)
          .doc(_getDocId())
          .set(data, SetOptions(merge: true));

      await NotificationHelper.notifyEmployee(
        employeeEmail: email,
        title:
            isCheckIn ? 'Check-In Successful âœ…' : 'Check-Out Successful ðŸ‘‹',
        body:
            'You have successfully ${isCheckIn ? 'checked in' : 'checked out'} at ${DateFormat('hh:mm a').format(now)}.',
        type: isCheckIn ? 'check_in' : 'check_out',
        extraData: {'userId': _user?.uid},
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
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger));
      }
    } finally {
      if (mounted) setState(() => _isCheckingInOut = false);
    }
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _attendanceStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary));
        }

        final docs = snapshot.data!.docs;
        final now = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(now);

        Map<String, dynamic>? todayData;
        try {
          final doc = docs.firstWhere((d) => d.id == todayStr);
          todayData = doc.data() as Map<String, dynamic>;
        } catch (_) {}

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTodayCard(todayData, now),
              const SizedBox(height: 20),
              _buildThisWeek(docs, now),
              const SizedBox(height: 20),
              _buildMonthlySummary(docs, now),
              const SizedBox(height: 20),
              _buildTodayShift(),
              const SizedBox(height: 20),
              _buildQuickActions(),
            ],
          ),
        );
      },
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  TODAY'S ATTENDANCE CARD
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _buildTodayCard(Map<String, dynamic>? data, DateTime now) {
    final hasCheckIn = data != null && data['checkIn'] != null;
    final hasCheckOut = data != null && data['checkOut'] != null;
    final Timestamp? checkInTs = data?['checkIn'];
    final Timestamp? checkOutTs = data?['checkOut'];

    // â”€â”€â”€ Compute times â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    String checkInStr = '--:--';
    if (checkInTs != null) {
      checkInStr = DateFormat('hh:mm a').format(checkInTs.toDate());
    }

    String workingHrs = '0h 0m';
    if (hasCheckIn && checkInTs != null) {
      final end = hasCheckOut ? checkOutTs!.toDate() : DateTime.now();
      final diff = end.difference(checkInTs.toDate());
      workingHrs = '${diff.inHours}h ${(diff.inMinutes % 60).toString().padLeft(2, '0')}m';
    }

    // Late buffer â€” compare check-in time against shift start
    String lateBuffer = '0 min';
    bool isLate = false;
    if (hasCheckIn && checkInTs != null) {
      final parts = AppSession().shiftStartTime.split(':');
      final shiftStart = DateTime(now.year, now.month, now.day,
          int.parse(parts[0]), int.parse(parts[1]));
      final grace = AppSession().gracePeriod;
      final diff = checkInTs.toDate().difference(shiftStart);
      if (diff.inMinutes > grace) {
        lateBuffer = '${diff.inMinutes - grace} min';
        isLate = true;
      }
    }

    // Status badge
    String statusBadge = 'Not Started';
    Color statusColor = AppTheme.textMuted;
    if (hasCheckIn && !hasCheckOut) {
      statusBadge = 'Present';
      statusColor = AppTheme.success;
    } else if (hasCheckOut) {
      statusBadge = 'Present';
      statusColor = AppTheme.success;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("TODAY'S ATTENDANCE",
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, d MMMM yyyy').format(now),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(statusBadge,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stat chips
          Row(
            children: [
              _statChip(checkInStr, 'Check In', AppTheme.primary),
              const SizedBox(width: 8),
              _statChip(
                  hasCheckIn && !hasCheckOut ? 'Ongoing' : (hasCheckOut ? DateFormat('hh:mm a').format(checkOutTs!.toDate()) : '--:--'),
                  'Check Out',
                  hasCheckIn && !hasCheckOut
                      ? AppTheme.warning
                      : AppTheme.success),
              const SizedBox(width: 8),
              _statChip(workingHrs, 'Working', AppTheme.info),
              const SizedBox(width: 8),
              _statChip(lateBuffer, 'Late Buffer',
                  isLate ? AppTheme.danger : AppTheme.success),
            ],
          ),
          const SizedBox(height: 20),

          // Location row
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 16, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  AppSession().companyName ?? 'Office',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                          color: AppTheme.success, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text('GPS Active',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.success)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: _isCheckingInOut
                      ? null
                      : () async {
                          if (!hasCheckIn) {
                            await _handleCheckInOut('checked_in', true);
                          } else if (!hasCheckOut) {
                            await _handleCheckInOut('checked_out', false);
                          }
                        },
                  icon: _isCheckingInOut
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Icon(
                          !hasCheckIn
                              ? Icons.login_rounded
                              : (!hasCheckOut
                                  ? Icons.logout_rounded
                                  : Icons.check_circle_outline),
                          size: 18),
                  label: Text(
                    !hasCheckIn
                        ? 'Check In'
                        : (!hasCheckOut ? 'Check Out' : 'Done'),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (data != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EmployeeAttendanceDetailScreen(
                            date: DateTime.now(),
                            data: data,
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.info_outline_rounded, size: 16),
                  label: const Text('Detail',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: AppTheme.divider),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  THIS WEEK
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _buildThisWeek(List<QueryDocumentSnapshot> docs, DateTime now) {
    // Find Monday of this week
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider.withOpacity(0.6)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('THIS WEEK',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                      letterSpacing: 0.5)),
              GestureDetector(
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen()));
                },
                child: Row(
                  children: [
                    Text('View History',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary)),
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_forward_ios,
                        size: 10, color: AppTheme.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(5, (i) {
              final day = monday.add(Duration(days: i));
              final dayStr = DateFormat('yyyy-MM-dd').format(day);
              final isToday = dayStr == DateFormat('yyyy-MM-dd').format(now);
              final isFuture = day.isAfter(now);

              // Find attendance for this day
              String status = 'absent';
              try {
                final doc = docs.firstWhere((d) => d.id == dayStr);
                final d = doc.data() as Map<String, dynamic>;
                final rawStatus = (d['status'] ?? '').toString().toLowerCase();
                final workMode = (d['workMode'] ?? '').toString().toLowerCase();
                if (rawStatus.contains('leave')) {
                  status = 'leave';
                } else if (workMode == 'wfh' || workMode == 'work_from_home') {
                  status = 'wfh';
                } else if (rawStatus.contains('late')) {
                  status = 'late';
                } else if (d['checkIn'] != null) {
                  status = 'present';
                }
              } catch (_) {}

              if (isFuture) status = 'future';

              return _weekDayChip(weekDays[i], status, isToday);
            }),
          ),
        ],
      ),
    );
  }

  Widget _weekDayChip(String label, String status, bool isToday) {
    Color bgColor;
    Color textColor;
    String statusLetter;
    Color dotColor;

    switch (status) {
      case 'present':
        bgColor = AppTheme.primary;
        textColor = Colors.white;
        statusLetter = 'P';
        dotColor = AppTheme.success;
        break;
      case 'late':
        bgColor = AppTheme.warning;
        textColor = Colors.white;
        statusLetter = 'L';
        dotColor = AppTheme.warning;
        break;
      case 'wfh':
        bgColor = const Color(0xFF8B5CF6);
        textColor = Colors.white;
        statusLetter = 'W';
        dotColor = const Color(0xFF8B5CF6);
        break;
      case 'leave':
        bgColor = AppTheme.danger;
        textColor = Colors.white;
        statusLetter = 'A';
        dotColor = AppTheme.danger;
        break;
      case 'future':
        bgColor = const Color(0xFFF3F4F6);
        textColor = AppTheme.textMuted;
        statusLetter = '-';
        dotColor = Colors.transparent;
        break;
      default: // absent
        bgColor = const Color(0xFFF3F4F6);
        textColor = AppTheme.textMuted;
        statusLetter = '-';
        dotColor = AppTheme.textHint;
        break;
    }

    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMuted)),
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: isToday
                ? Border.all(color: AppTheme.primary, width: 2.5)
                : null,
          ),
          alignment: Alignment.center,
          child: Text(statusLetter,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textColor)),
        ),
        const SizedBox(height: 6),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  MONTHLY SUMMARY
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _buildMonthlySummary(List<QueryDocumentSnapshot> docs, DateTime now) {
    final monthStr = DateFormat('MMMM yyyy').format(now).toUpperCase();

    int present = 0, late = 0, wfh = 0, leave = 0;
    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      final date = doc.id; // yyyy-MM-dd
      if (!date.startsWith(DateFormat('yyyy-MM').format(now))) continue;

      final rawStatus = (d['status'] ?? '').toString().toLowerCase();
      final workMode = (d['workMode'] ?? '').toString().toLowerCase();

      if (rawStatus.contains('leave')) {
        leave++;
      } else if (workMode == 'wfh' || workMode == 'work_from_home') {
        wfh++;
      } else if (rawStatus.contains('late')) {
        late++;
      } else if (d['checkIn'] != null) {
        present++;
      }
    }

    final totalWorkingDays = present + late + wfh;
    final total = totalWorkingDays + leave;
    final attendanceRate =
        total > 0 ? ((totalWorkingDays / total) * 100).toStringAsFixed(1) : '0.0';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$monthStr â€“ MONTHLY',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              _monthStatCircle('$present', 'Present', AppTheme.primary),
              const SizedBox(width: 12),
              _monthStatCircle('$late', 'Late', AppTheme.warning),
              const SizedBox(width: 12),
              _monthStatCircle('$wfh', 'WFH', const Color(0xFF8B5CF6)),
              const SizedBox(width: 12),
              _monthStatCircle('$leave', 'Leave', AppTheme.danger),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Attendance Rate',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$attendanceRate%',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.success)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _monthStatCircle(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  TODAY'S SHIFT
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _buildTodayShift() {
    final shiftStart = AppSession().shiftStartTime;
    final shiftEnd = AppSession().shiftEndTime;
    final managerName = AppSession().userName ?? 'N/A';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("TODAY'S SHIFT",
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.schedule_rounded,
                    color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('General Shift',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text('$shiftStart AM â€“ $shiftEnd PM Â· Office',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textMuted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_role == 'employee' ? 'Manager' : 'Role',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textHint)),
                  const SizedBox(height: 2),
                  Text(
                      _role == 'employee'
                          ? managerName
                          : _role[0].toUpperCase() + _role.substring(1),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  QUICK ACTIONS
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('QUICK ACTIONS',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.5)),
          const SizedBox(height: 12),
          _actionTile(
            icon: Icons.history_rounded,
            color: AppTheme.primary,
            title: 'View Attendance History',
            subtitle: 'View complete attendance log',
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen()));
            },
          ),
          Divider(height: 1, color: AppTheme.divider.withOpacity(0.5)),
          _actionTile(
            icon: Icons.edit_note_rounded,
            color: AppTheme.warning,
            title: 'Request Regularization',
            subtitle: 'Correct missed attendance',
            onTap: () {
              // Navigate to correction screen
            },
          ),
          Divider(height: 1, color: AppTheme.divider.withOpacity(0.5)),
          _actionTile(
            icon: Icons.calendar_month_rounded,
            color: AppTheme.info,
            title: 'View Attendance Calendar',
            subtitle: 'Monthly attendance overview',
            onTap: () {
              // Navigate to calendar
            },
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.textMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppTheme.textHint, size: 20),
          ],
        ),
      ),
    );
  }
}
