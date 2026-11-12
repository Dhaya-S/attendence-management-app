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
import 'package:attendance_app/screens/employee/employee_attendance_correction_screen.dart';
import 'package:attendance_app/screens/employee/employee_calendar_tab.dart';

/// Overview tab — shows today's attendance card, this week progress,
/// monthly summary, today's shift, and quick actions.
/// Real-time via Firestore streams + a 1-second timer for the live clock.
class AttendanceOverviewTab extends StatefulWidget {
  const AttendanceOverviewTab({super.key});

  @override
  State<AttendanceOverviewTab> createState() => _AttendanceOverviewTabState();
}

class _AttendanceOverviewTabState extends State<AttendanceOverviewTab> {
  String get _userEmail {
    final authEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    if (authEmail.isNotEmpty && authEmail.contains('@')) return authEmail;
    final sessionEmail = AppSession().email ?? '';
    if (sessionEmail.isNotEmpty && sessionEmail.contains('@')) return sessionEmail;
    return authEmail.isNotEmpty ? authEmail : sessionEmail;
  }
  Timer? _timer;
  bool _isCheckingInOut = false;
  late final Stream<QuerySnapshot> _leaveStream = FirestoreService.leaveRequestsCol.snapshots();
  late final Stream<QuerySnapshot> _holidayStream =
      FirestoreService.orgHolidaysCol(FirestoreService.companyId).snapshots();

  /// Builds [builder] with this employee's approved-leave days, the company holidays and the
  /// working weekdays of their shift — all live from Firestore.
  Widget _withDayContext(
      Widget Function(Set<String> leaveDays, Set<String> holidayKeys, Set<int> workDays) builder) {
    return StreamBuilder<QuerySnapshot>(
      stream: _leaveStream,
      builder: (context, leaveSnap) => StreamBuilder<QuerySnapshot>(
        stream: _holidayStream,
        builder: (context, holSnap) {
          final me = _userEmail.toLowerCase();
          final fmt = DateFormat('yyyy-MM-dd');
          final leaveDays = <String>{};
          for (final d in leaveSnap.data?.docs ?? const <QueryDocumentSnapshot>[]) {
            final m = d.data() as Map<String, dynamic>;
            if (!FirestoreService.statusIs(m['status'], 'approved')) continue;
            if (FirestoreService.requesterEmail(m) != me) continue;
            final from = FirestoreService.parseAnyDate(m['fromDate'] ?? m['from']);
            final to = FirestoreService.parseAnyDate(m['toDate'] ?? m['to']) ?? from;
            if (from == null || to == null) continue;
            var c = DateTime(from.year, from.month, from.day);
            final end = DateTime(to.year, to.month, to.day);
            while (!c.isAfter(end)) {
              leaveDays.add(fmt.format(c));
              c = c.add(const Duration(days: 1));
            }
          }
          final holidayKeys = <String>{};
          for (final d in holSnap.data?.docs ?? const <QueryDocumentSnapshot>[]) {
            final dt = FirestoreService.holidayDate(d.data() as Map<String, dynamic>);
            if (dt != null) holidayKeys.add(fmt.format(dt));
          }
          return builder(leaveDays, holidayKeys, FirestoreService.workingWeekdays(AppSession().shiftDays));
        },
      ),
    );
  }

  String get _role => AppSession().role?.toLowerCase() ?? 'employee';

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

  // ──────────────────────────────── Check-In / Check-Out ─────────────────
  String _getDocId() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> _handleCheckInOut(String status, bool isCheckIn) async {
    if (_isCheckingInOut) return;
    setState(() => _isCheckingInOut = true);
    try {
      final now = DateTime.now();
      final email = _userEmail;
      await FirestoreService.recordAttendancePunch(
        email: email,
        isCheckIn: isCheckIn,
        // Late is worked out inside recordAttendancePunch; check-out keeps the day's status.
        status: 'Present',
        location: 'Work in Office',
        additionalData: {
          'workMode': 'office',
        },
      );

      await NotificationHelper.notifyEmployee(
        employeeEmail: email,
        title:
            isCheckIn ? 'Check-In Successful ✅' : 'Check-Out Successful 👋',
        body:
            'You have successfully ${isCheckIn ? 'checked in' : 'checked out'} at ${DateFormat('hh:mm a').format(now)}.',
        type: isCheckIn ? 'check_in' : 'check_out',
        extraData: {'userId': FirebaseAuth.instance.currentUser?.uid ?? AppSession().uid},
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

  // ──────────────────────────────── Build ────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.userAttendanceCol(_userEmail).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary));
        }

        final docs = snapshot.data!.docs;
        final now = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(now);

        final recs = <String, Map<String, dynamic>>{
          for (final d in docs) d.id: d.data() as Map<String, dynamic>,
        };

        return _withDayContext((leaveDays, holidayKeys, workDays) => SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThisWeek(recs, now, leaveDays, holidayKeys, workDays),
              const SizedBox(height: 20),
              _buildMonthlySummary(recs, now, leaveDays, holidayKeys, workDays),
              const SizedBox(height: 20),
              _buildTodayShift(),
              const SizedBox(height: 20),
              _buildQuickActions(),
            ],
          ),
        ));
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  TODAY'S ATTENDANCE CARD
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildTodayCard(Map<String, dynamic>? data, DateTime now) {
    final hasCheckIn = data != null && data['checkIn'] != null;
    final hasCheckOut = data != null && data['checkOut'] != null;
    final Timestamp? checkInTs = data?['checkIn'];
    final Timestamp? checkOutTs = data?['checkOut'];

    // ─── Compute times ──────────────────────────────────────────────
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

    // Late buffer — compare check-in time against shift start
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

  // ══════════════════════════════════════════════════════════════════════
  //  THIS WEEK
  // ══════════════════════════════════════════════════════════════════════
  // ─────────────────────────────────────────────────────────────────────────
  //  Day status (one rule for the week strip AND the monthly summary)
  //  present · late · wfh · leave · holiday · absent · pending (today, not yet in) ·
  //  weekend (not a working day) · future
  // ─────────────────────────────────────────────────────────────────────────
  String _dayStatus(
    DateTime day,
    DateTime now,
    Map<String, Map<String, dynamic>> recs,
    Set<String> leaveDays,
    Set<String> holidayKeys,
    Set<int> workDays,
  ) {
    final key = DateFormat('yyyy-MM-dd').format(day);
    final today = DateTime(now.year, now.month, now.day);
    final d0 = DateTime(day.year, day.month, day.day);

    final d = recs[key];
    if (d != null) {
      final rawStatus = (d['status'] ?? d['attendanceStatus'] ?? '').toString().toLowerCase();
      final workMode = (d['workMode'] ?? '').toString().toLowerCase();
      if (rawStatus.contains('leave')) return 'leave';
      if (workMode == 'wfh' || workMode == 'work_from_home' || rawStatus == 'wfh') return 'wfh';
      if (rawStatus.contains('late') || d['isLate'] == true) return 'late';
      if (d['checkIn'] != null ||
          d['checkInTime'] != null ||
          d['lastCheckIn'] != null ||
          rawStatus.contains('present') ||
          rawStatus.contains('checked') ||
          rawStatus.contains('completed')) {
        return 'present';
      }
    }
    if (d0.isAfter(today)) return 'future';
    if (leaveDays.contains(key)) return 'leave';
    if (holidayKeys.contains(key)) return 'holiday';
    if (!workDays.contains(day.weekday)) return 'weekend';
    if (d0 == today) return 'pending';
    return 'absent';
  }

  Widget _buildThisWeek(
    Map<String, Map<String, dynamic>> recs,
    DateTime now,
    Set<String> leaveDays,
    Set<String> holidayKeys,
    Set<int> workDays,
  ) {
    // Find Monday of this week
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
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
              final isToday = DateFormat('yyyy-MM-dd').format(day) ==
                  DateFormat('yyyy-MM-dd').format(now);
              final status = _dayStatus(day, now, recs, leaveDays, holidayKeys, workDays);
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
        bgColor = const Color(0xFF0EA5E9);
        textColor = Colors.white;
        statusLetter = 'LV';
        dotColor = const Color(0xFF0EA5E9);
        break;
      case 'holiday':
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFDC2626);
        statusLetter = 'H';
        dotColor = const Color(0xFFDC2626);
        break;
      case 'absent':
        bgColor = AppTheme.danger.withOpacity(0.12);
        textColor = AppTheme.danger;
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

  // ══════════════════════════════════════════════════════════════════════
  //  MONTHLY SUMMARY
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildMonthlySummary(
    Map<String, Map<String, dynamic>> recs,
    DateTime now,
    Set<String> leaveDays,
    Set<String> holidayKeys,
    Set<int> workDays,
  ) {
    final monthStr = DateFormat('MMMM yyyy').format(now).toUpperCase();

    // Every day of this month up to today is counted exactly once
    int present = 0, late = 0, wfh = 0, leave = 0, absent = 0;
    for (var d = DateTime(now.year, now.month, 1);
        !d.isAfter(DateTime(now.year, now.month, now.day));
        d = d.add(const Duration(days: 1))) {
      switch (_dayStatus(d, now, recs, leaveDays, holidayKeys, workDays)) {
        case 'present':
          present++;
          break;
        case 'late':
          late++;
          break;
        case 'wfh':
          wfh++;
          break;
        case 'leave':
          leave++;
          break;
        case 'absent':
          absent++;
          break;
      }
    }

    final worked = present + late + wfh;
    final expected = worked + absent;
    final attendanceRate =
        expected > 0 ? ((worked / expected) * 100).toStringAsFixed(1) : '0.0';

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
          Text('$monthStr – MONTHLY',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              _monthStatCircle('$present', 'Present', AppTheme.primary),
              const SizedBox(width: 8),
              _monthStatCircle('$late', 'Late', AppTheme.warning),
              const SizedBox(width: 8),
              _monthStatCircle('$wfh', 'WFH', const Color(0xFF8B5CF6)),
              const SizedBox(width: 8),
              _monthStatCircle('$leave', 'Leave', const Color(0xFF0EA5E9)),
              const SizedBox(width: 8),
              _monthStatCircle('$absent', 'Absent', AppTheme.danger),
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

  // ══════════════════════════════════════════════════════════════════════
  //  TODAY'S SHIFT
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildTodayShift() {
    final shiftStart = AppSession().shiftStartTime;
    final shiftEnd = AppSession().shiftEndTime;

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
                    Text(AppSession().shiftLabel,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text('${AppSession().shiftTimeRange} · Office',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Role',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textHint)),
                  const SizedBox(height: 2),
                  Text(AppSession().displayRole,
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

  // ══════════════════════════════════════════════════════════════════════
  //  QUICK ACTIONS
  // ══════════════════════════════════════════════════════════════════════
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
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const EmployeeAttendanceCorrectionScreen()));
            },
          ),
          Divider(height: 1, color: AppTheme.divider.withOpacity(0.5)),
          _actionTile(
            icon: Icons.calendar_month_rounded,
            color: AppTheme.info,
            title: 'View Attendance Calendar',
            subtitle: 'Monthly attendance overview',
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const EmployeeCalendarTab()));
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
