import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/screens/employee/employee_attendance_detail_screen.dart';

class EmployeeAttendanceSummaryScreen extends StatefulWidget {
  const EmployeeAttendanceSummaryScreen({super.key});

  @override
  State<EmployeeAttendanceSummaryScreen> createState() =>
      _EmployeeAttendanceSummaryScreenState();
}

class _EmployeeAttendanceSummaryScreenState
    extends State<EmployeeAttendanceSummaryScreen> {
  final _userEmail = FirebaseAuth.instance.currentUser?.email ?? '';

  // ── helpers ──────────────────────────────────────────────────────────────

  /// Format a Firestore Timestamp as "HH:mm" (24-hour, no seconds).
  String _fmt24(Timestamp? t) {
    if (t == null) return '--:--';
    final dt = t.toDate().toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Returns the status string for a record, checking late-arrival logic.
  String _statusOf(Map<String, dynamic>? data) {
    if (data == null || data['checkIn'] == null) return 'Absent';
    final workMode = data['workMode'] as String?;
    if (workMode == 'wfh') return 'WFH';

    final checkInTs = data['checkIn'] as Timestamp?;
    if (checkInTs != null) {
      final checkIn = checkInTs.toDate();
      final sParts = AppSession().shiftStartTime.split(':');
      final lateThreshold = DateTime(
        checkIn.year, checkIn.month, checkIn.day,
        int.parse(sParts[0]), int.parse(sParts[1]),
      ).add(Duration(minutes: AppSession().gracePeriod));
      final remarkStatus = data['remarkStatus'] as String?;
      if (checkIn.isAfter(lateThreshold) && remarkStatus != 'approved') {
        return 'Late';
      }
    }
    return 'Present';
  }

  /// Returns Mon–today of the current week (excludes future days).
  List<DateTime> _thisWeekDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return List.generate(5, (i) => monday.add(Duration(days: i)))
        .where((d) => !d.isAfter(today))
        .toList();
  }

  void _navigateToDetail(DateTime date, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmployeeAttendanceDetailScreen(date: date, data: data),
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: Color(0xFF1F2937)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Attendance Summary',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.userAttendanceCol(_userEmail).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final Map<String, Map<String, dynamic>> recordsByDate = {};
          for (final doc in snapshot.data!.docs) {
            recordsByDate[doc.id] = doc.data() as Map<String, dynamic>;
          }

          return _buildBody(recordsByDate);
        },
      ),
    );
  }

  Widget _buildBody(Map<String, Map<String, dynamic>> records) {
    final now = DateTime.now();

    // ── Monthly stats ──────────────────────────────────────────────────────
    int presentCount = 0, lateCount = 0, onTimeCount = 0, wfhCount = 0;
    int totalWorkdays = 0;

    final firstOfMonth = DateTime(now.year, now.month, 1);
    for (int d = 0; d <= now.difference(firstOfMonth).inDays; d++) {
      final day = firstOfMonth.add(Duration(days: d));
      if (day.weekday >= 1 && day.weekday <= 5) totalWorkdays++;
    }
    if (totalWorkdays == 0) totalWorkdays = 1;

    records.forEach((dateStr, data) {
      DateTime? dt;
      try {
        dt = DateTime.parse(dateStr);
      } catch (_) {}
      if (dt == null) return;
      if (dt.month != now.month || dt.year != now.year) return;
      if (dt.weekday < 1 || dt.weekday > 5) return;

      final st = _statusOf(data);
      if (st == 'WFH') {
        wfhCount++;
        presentCount++;
      } else if (st == 'Late') {
        lateCount++;
        presentCount++;
      } else if (st == 'Present') {
        presentCount++;
        onTimeCount++;
      }
    });

    final absentCount = (totalWorkdays - presentCount).clamp(0, totalWorkdays);
    final rate = (presentCount / totalWorkdays) * 100.0;
    final weekDays = _thisWeekDays();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 6-stat grid ────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  value: '$presentCount',
                  label: 'Present',
                  valueColor: const Color(0xFF22C55E),
                  bg: const Color(0xFFECFDF5),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBox(
                  value: '$lateCount',
                  label: 'Late',
                  valueColor: const Color(0xFFF59E0B),
                  bg: const Color(0xFFFFFBEB),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBox(
                  value: '$absentCount',
                  label: 'Absent',
                  valueColor: const Color(0xFFEF4444),
                  bg: const Color(0xFFFEF2F2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  value: '${rate.toStringAsFixed(1)}%',
                  label: 'Rate',
                  valueColor: const Color(0xFF5C5CFF),
                  bg: const Color(0xFFF0F1FF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBox(
                  value: '$onTimeCount',
                  label: 'On Time',
                  valueColor: const Color(0xFF22C55E),
                  bg: const Color(0xFFECFDF5),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBox(
                  value: '$wfhCount',
                  label: 'WFH',
                  valueColor: const Color(0xFF5C5CFF),
                  bg: const Color(0xFFF0F1FF),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── This Week card ─────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF0F1F3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 16, 18, 8),
                  child: Text(
                    'THIS WEEK',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF9CA3AF),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF0F1F3)),
                ...weekDays.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final day = entry.value;
                  final dateStr = DateFormat('yyyy-MM-dd').format(day);
                  final data = records[dateStr];
                  return _WeekDayRow(
                    date: day,
                    data: data,
                    isLast: idx == weekDays.length - 1,
                    fmt24: _fmt24,
                    statusOf: _statusOf,
                    onTap: () => _navigateToDetail(day, data ?? {}),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat Box ──────────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final String value, label;
  final Color valueColor, bg;

  const _StatBox({
    required this.value,
    required this.label,
    required this.valueColor,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: valueColor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valueColor.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Week Day Row ───────────────────────────────────────────────────────────────

class _WeekDayRow extends StatelessWidget {
  final DateTime date;
  final Map<String, dynamic>? data;
  final bool isLast;
  final String Function(Timestamp?) fmt24;
  final String Function(Map<String, dynamic>?) statusOf;
  final VoidCallback onTap;

  const _WeekDayRow({
    required this.date,
    required this.data,
    required this.isLast,
    required this.fmt24,
    required this.statusOf,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    final isFuture = date.isAfter(DateTime(now.year, now.month, now.day));

    final String status =
        isFuture ? 'Upcoming' : statusOf(data);

    Color statusColor;
    Color statusBg;
    switch (status) {
      case 'Present':
        statusColor = const Color(0xFF22C55E);
        statusBg = const Color(0xFFECFDF5);
        break;
      case 'Late':
        statusColor = const Color(0xFFF59E0B);
        statusBg = const Color(0xFFFFFBEB);
        break;
      case 'WFH':
        statusColor = const Color(0xFF5C5CFF);
        statusBg = const Color(0xFFF0F1FF);
        break;
      case 'Absent':
        statusColor = const Color(0xFFEF4444);
        statusBg = const Color(0xFFFEF2F2);
        break;
      default: // Upcoming
        statusColor = const Color(0xFF9CA3AF);
        statusBg = const Color(0xFFF3F4F6);
    }

    // Build time range string e.g. "09:02–18:04"
    String timeStr = '';
    if (data != null && data!['checkIn'] != null) {
      final cin = fmt24(data!['checkIn'] as Timestamp?);
      final cout = data!['checkOut'] != null
          ? fmt24(data!['checkOut'] as Timestamp?)
          : 'ongoing';
      timeStr = '$cin–$cout';
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                // Day + Date label (e.g. "Mon Jul 22")
                SizedBox(
                  width: 90,
                  child: Text(
                    '${DateFormat('EEE').format(date)} ${DateFormat('MMM d').format(date)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isToday ? FontWeight.w700 : FontWeight.w500,
                      color: isToday
                          ? const Color(0xFF1F2937)
                          : const Color(0xFF4B5563),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withOpacity(0.25),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),

                const Spacer(),

                // Time range
                if (timeStr.isNotEmpty)
                  Text(
                    timeStr,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
              ],
            ),
          ),
          if (!isLast)
            const Divider(
              height: 1,
              indent: 18,
              endIndent: 18,
              color: Color(0xFFF0F1F3),
            ),
        ],
      ),
    );
  }
}
