import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/screens/employee/employee_attendance_detail_screen.dart';

/// Summary tab â€” Weekly list view and Monthly calendar view with toggle.
class AttendanceSummaryTab extends StatefulWidget {
  const AttendanceSummaryTab({super.key});

  @override
  State<AttendanceSummaryTab> createState() => _AttendanceSummaryTabState();
}

class _AttendanceSummaryTabState extends State<AttendanceSummaryTab> {
  final _user = FirebaseAuth.instance.currentUser;
  bool _isWeekly = true;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  late Stream<QuerySnapshot> _stream;

  @override
  void initState() {
    super.initState();
    _stream =
        FirestoreService.userAttendanceCol(_user?.email ?? '').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary));
        }

        final docs = snapshot.data!.docs;

        return Column(
          children: [
            const SizedBox(height: 12),

            // â”€â”€â”€ Toggle Bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _toggleChip('Weekly', _isWeekly, () => setState(() => _isWeekly = true)),
                  const SizedBox(width: 8),
                  _toggleChip('Monthly', !_isWeekly, () => setState(() => _isWeekly = false)),
                  const Spacer(),
                  _monthDropdown(),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // â”€â”€â”€ Content â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Expanded(
              child: _isWeekly
                  ? _buildWeeklyList(docs)
                  : _buildMonthlyCalendar(docs),
            ),
          ],
        );
      },
    );
  }

  // â”€â”€â”€ Toggle chip â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _toggleChip(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: isActive ? AppTheme.primary : AppTheme.divider),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : AppTheme.textMuted)),
      ),
    );
  }

  Widget _monthDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 14, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          Text(DateFormat('MMM yyyy').format(_selectedMonth),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  WEEKLY LIST VIEW
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _buildWeeklyList(List<QueryDocumentSnapshot> docs) {
    // Filter docs for selected month and sort descending
    final filtered = docs.where((d) {
      return d.id.startsWith(DateFormat('yyyy-MM').format(_selectedMonth));
    }).toList()
      ..sort((a, b) => b.id.compareTo(a.id));

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_rounded, size: 56, color: AppTheme.textHint),
            const SizedBox(height: 12),
            Text('No records for this period',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final doc = filtered[index];
        final data = doc.data() as Map<String, dynamic>;
        final date = _parseDate(doc.id);
        return _weeklyCard(date, data);
      },
    );
  }

  DateTime _parseDate(String id) {
    try {
      return DateFormat('yyyy-MM-dd').parse(id);
    } catch (_) {
      return DateTime.now();
    }
  }

  Widget _weeklyCard(DateTime date, Map<String, dynamic> data) {
    final status = _getStatus(data);
    final statusInfo = _statusInfo(status);

    // Compute working hours
    String workingHrs = '';
    final checkIn = data['checkIn'] as Timestamp?;
    final checkOut = data['checkOut'] as Timestamp?;
    String timeRange = '';

    if (checkIn != null) {
      timeRange = DateFormat('hh:mm a').format(checkIn.toDate());
      if (checkOut != null) {
        timeRange += ' â€“ ${DateFormat('hh:mm a').format(checkOut.toDate())}';
        final diff = checkOut.toDate().difference(checkIn.toDate());
        workingHrs =
            '${diff.inHours}h ${(diff.inMinutes % 60).toString().padLeft(2, '0')}m';
      } else {
        timeRange += ' â€“ Ongoing';
        final diff = DateTime.now().difference(checkIn.toDate());
        workingHrs =
            '${diff.inHours}h ${(diff.inMinutes % 60).toString().padLeft(2, '0')}m';
      }
    } else if (status == 'leave') {
      timeRange = 'No attendance record';
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EmployeeAttendanceDetailScreen(
              date: date,
              data: data,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider.withOpacity(0.6)),
        ),
        child: Row(
          children: [
            // Date block
            Column(
              children: [
                Text(DateFormat('E').format(date).substring(0, 3),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textMuted)),
                Text('${date.day}',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
              ],
            ),
            const SizedBox(width: 16),
            Container(
                width: 1,
                height: 40,
                color: AppTheme.divider.withOpacity(0.5)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusInfo.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(statusInfo.label,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusInfo.color)),
                  ),
                  const SizedBox(height: 6),
                  Text(timeRange,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textMuted)),
                ],
              ),
            ),
            if (workingHrs.isNotEmpty) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(workingHrs,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          fontFeatures: [FontFeature.tabularFigures()])),
                  const SizedBox(height: 2),
                  Text('Working hrs',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: AppTheme.textHint, size: 18),
          ],
        ),
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  MONTHLY CALENDAR VIEW
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _buildMonthlyCalendar(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();

    // Build a map of date -> status for the selected month
    final Map<int, String> dayStatusMap = {};
    for (final doc in docs) {
      if (!doc.id.startsWith(DateFormat('yyyy-MM').format(_selectedMonth))) continue;
      final data = doc.data() as Map<String, dynamic>;
      final day = int.tryParse(doc.id.substring(8)) ?? 0;
      dayStatusMap[day] = _getStatus(data);
    }

    final firstDayOfMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final daysInMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final startWeekday = firstDayOfMonth.weekday; // Mon=1

    // Count stats
    int present = 0, late = 0, wfhCount = 0, leaveCount = 0;
    dayStatusMap.forEach((_, s) {
      if (s == 'present') present++;
      if (s == 'late') late++;
      if (s == 'wfh') wfhCount++;
      if (s == 'leave') leaveCount++;
    });

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      child: Column(
        children: [
          // Month navigation
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.divider.withOpacity(0.6)),
            ),
            child: Column(
              children: [
                // Month header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => _changeMonth(-1),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.chevron_left_rounded,
                            size: 20, color: AppTheme.primary),
                      ),
                    ),
                    Text(
                      DateFormat('MMMM yyyy').format(_selectedMonth),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary),
                    ),
                    GestureDetector(
                      onTap: () => _changeMonth(1),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.chevron_right_rounded,
                            size: 20, color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Weekday headers
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                      .map((d) => SizedBox(
                            width: 36,
                            child: Center(
                              child: Text(d,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textMuted)),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 8),

                // Calendar grid
                _buildCalendarGrid(
                    daysInMonth, startWeekday, dayStatusMap, now),
                const SizedBox(height: 16),

                // Legend
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _legendItem(AppTheme.success, 'Present'),
                    _legendItem(AppTheme.warning, 'Late'),
                    _legendItem(const Color(0xFF8B5CF6), 'WFH'),
                    _legendItem(AppTheme.info, 'On Leave'),
                    _legendItem(const Color(0xFFE5E7EB), 'Holiday'),
                    _legendItem(AppTheme.danger, 'Absent'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Monthly Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.divider.withOpacity(0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${DateFormat('MMMM').format(_selectedMonth).toUpperCase()} SUMMARY',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMuted,
                        letterSpacing: 0.5)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _summaryBox('$present', 'Present', AppTheme.primary),
                    const SizedBox(width: 10),
                    _summaryBox('$late', 'Late', AppTheme.warning),
                    const SizedBox(width: 10),
                    _summaryBox('$wfhCount', 'WFH', const Color(0xFF8B5CF6)),
                    const SizedBox(width: 10),
                    _summaryBox('$leaveCount', 'Leave', AppTheme.danger),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
          _selectedMonth.year, _selectedMonth.month + delta);
    });
  }

  Widget _buildCalendarGrid(
      int daysInMonth, int startWeekday, Map<int, String> statusMap, DateTime now) {
    // Convert Monday-based weekday to Sunday-based for grid
    final offset = startWeekday % 7; // Sun=0, Mon=1, ...

    final cells = <Widget>[];
    // Leading empty cells
    for (int i = 0; i < offset; i++) {
      cells.add(const SizedBox(width: 36, height: 36));
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final status = statusMap[day];
      final isToday = _selectedMonth.year == now.year &&
          _selectedMonth.month == now.month &&
          day == now.day;

      Color? dotColor;
      if (status != null) {
        final info = _statusInfo(status);
        dotColor = info.color;
      }

      cells.add(
        Container(
          width: 36,
          height: 36,
          decoration: isToday
              ? BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primary, width: 1.5),
                )
              : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$day',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      color:
                          isToday ? AppTheme.primary : AppTheme.textPrimary)),
              if (dotColor != null) ...[
                const SizedBox(height: 2),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                      color: dotColor, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: (MediaQuery.of(context).size.width - 32 - 40 - 7 * 36) / 6,
      runSpacing: 4,
      children: cells,
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMuted)),
      ],
    );
  }

  Widget _summaryBox(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
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
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String _getStatus(Map<String, dynamic> data) {
    final rawStatus = (data['status'] ?? '').toString().toLowerCase();
    final workMode = (data['workMode'] ?? '').toString().toLowerCase();
    if (rawStatus.contains('leave')) return 'leave';
    if (workMode == 'wfh' || workMode == 'work_from_home') return 'wfh';
    if (rawStatus.contains('late')) return 'late';
    if (data['checkIn'] != null) return 'present';
    return 'absent';
  }

  _StatusInfo _statusInfo(String status) {
    switch (status) {
      case 'present':
        return _StatusInfo('Present', AppTheme.success);
      case 'late':
        return _StatusInfo('Late', AppTheme.warning);
      case 'wfh':
        return _StatusInfo('WFH', const Color(0xFF8B5CF6));
      case 'leave':
        return _StatusInfo('On Leave', AppTheme.info);
      default:
        return _StatusInfo('Absent', AppTheme.textHint);
    }
  }
}

class _StatusInfo {
  final String label;
  final Color color;
  const _StatusInfo(this.label, this.color);
}
