import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/screens/employee/employee_attendance_detail_screen.dart';

/// Summary tab — Weekly list view and Monthly calendar view with toggle.
class AttendanceSummaryTab extends StatefulWidget {
  const AttendanceSummaryTab({super.key});

  @override
  State<AttendanceSummaryTab> createState() => _AttendanceSummaryTabState();
}

class _AttendanceSummaryTabState extends State<AttendanceSummaryTab> {
  String get _userEmail {
    final authEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    if (authEmail.isNotEmpty && authEmail.contains('@')) return authEmail;
    final sessionEmail = AppSession().email ?? '';
    if (sessionEmail.isNotEmpty && sessionEmail.contains('@')) return sessionEmail;
    return authEmail.isNotEmpty ? authEmail : sessionEmail;
  }
  bool _isWeekly = true;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

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

        return Column(
          children: [
            const SizedBox(height: 12),

            // ─── Toggle Bar ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _toggleChip('Weekly', _isWeekly, () => setState(() => _isWeekly = true)),
                  const SizedBox(width: 8),
                  _toggleChip('Monthly', !_isWeekly, () => setState(() => _isWeekly = false)),
                  const Spacer(),
                  _filterChip(),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ─── Content ─────────────────────────────────────────
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

  // ─── Toggle chip ─────────────────────────────────────────────────────
  Widget _toggleChip(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF5C5CFF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isActive ? const Color(0xFF5C5CFF) : const Color(0xFFE2E8F0)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : const Color(0xFF64748B))),
      ),
    );
  }

  // Month navigation is now done directly from the calendar header
  Widget _filterChip() {
    return PopupMenuButton<String>(
      onSelected: (choice) async {
        final now = DateTime.now();
        if (choice == 'This Month') {
          setState(() {
            _selectedMonth = DateTime(now.year, now.month);
          });
        } else if (choice == 'Last Month') {
          setState(() {
            _selectedMonth = DateTime(now.year, now.month - 1);
          });
        } else if (choice == 'Custom Month...') {
          final picked = await showDatePicker(
            context: context,
            initialDate: _selectedMonth,
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            initialDatePickerMode: DatePickerMode.year,
          );
          if (picked != null) {
            setState(() {
              _selectedMonth = DateTime(picked.year, picked.month);
            });
          }
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'This Month', child: Text('This Month')),
        const PopupMenuItem(value: 'Last Month', child: Text('Last Month')),
        const PopupMenuItem(value: 'Custom Month...', child: Text('Custom Month...')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_alt_outlined,
                size: 14, color: Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              DateFormat('yyyy-MM').format(_selectedMonth) == DateFormat('yyyy-MM').format(DateTime.now())
                  ? 'This Month'
                  : DateFormat('MMM yyyy').format(_selectedMonth),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  WEEKLY LIST VIEW
  // ══════════════════════════════════════════════════════════════════════
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
        final date = _parseDocDate(doc);
        return _weeklyCard(date, data);
      },
    );
  }

  DateTime _parseDocDate(QueryDocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data != null) {
        if (data['date'] is Timestamp) return (data['date'] as Timestamp).toDate();
        if (data['recordDate'] is String) {
          final parsed = DateTime.tryParse(data['recordDate']);
          if (parsed != null) return parsed;
        }
        if (data['checkIn'] is Timestamp) return (data['checkIn'] as Timestamp).toDate();
        if (data['createdAt'] is Timestamp) return (data['createdAt'] as Timestamp).toDate();
      }
      return DateFormat('yyyy-MM-dd').parse(doc.id);
    } catch (_) {
      final parsed = DateTime.tryParse(doc.id);
      return parsed ?? DateTime.now();
    }
  }

  Widget _weeklyCard(DateTime date, Map<String, dynamic> data) {
    final status = _getStatus(data);
    final statusInfo = _statusInfo(status);

    DateTime? parseTimeToDateTime(dynamic val, DateTime baseDate) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) {
        final iso = DateTime.tryParse(val);
        if (iso != null) return iso;
        final clean = val.trim();
        final isPm = clean.toUpperCase().contains('PM');
        final isAm = clean.toUpperCase().contains('AM');
        final digits = clean.replaceAll(RegExp(r'[^\d:]'), '');
        if (digits.contains(':')) {
          final parts = digits.split(':');
          int hour = int.tryParse(parts[0]) ?? 0;
          final min = int.tryParse(parts[1]) ?? 0;
          if (isPm && hour < 12) hour += 12;
          if (isAm && hour == 12) hour = 0;
          return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, min);
        }
      }
      return null;
    }

    String workingHrs = '';
    String timeRange = '';

    final checkInDt = parseTimeToDateTime(data['checkIn'] ?? data['checkInTime'] ?? data['lastCheckIn'], date);
    final checkOutDt = parseTimeToDateTime(data['checkOut'] ?? data['checkOutTime'] ?? data['lastCheckout'], date);

    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

    if (checkInDt != null) {
      timeRange = DateFormat('hh:mm a').format(checkInDt);
      if (checkOutDt != null) {
        timeRange += ' – ${DateFormat('hh:mm a').format(checkOutDt)}';
        final diff = checkOutDt.difference(checkInDt);
        final mins = diff.inMinutes.abs();
        workingHrs = '${mins ~/ 60}h ${(mins % 60).toString().padLeft(2, '0')}m';
      } else if (isToday) {
        timeRange += ' – Ongoing';
        final diff = now.difference(checkInDt);
        final mins = diff.inMinutes.abs();
        workingHrs = '${mins ~/ 60}h ${(mins % 60).toString().padLeft(2, '0')}m';
      } else {
        timeRange += ' – Completed';
        workingHrs = '8h 00m';
      }
    } else if (data['lastCheckIn'] != null) {
      timeRange = '${data['lastCheckIn']}${data['lastCheckout'] != null ? ' – ${data['lastCheckout']}' : ''}';
      workingHrs = '8h 00m';
    } else if (status == 'leave') {
      timeRange = 'On Leave';
    } else if (status == 'present') {
      timeRange = AppSession().shiftTimeRange;
      workingHrs = '';
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
          borderRadius: BorderRadius.circular(20),
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

  // ══════════════════════════════════════════════════════════════════════
  //  MONTHLY CALENDAR VIEW
  // ══════════════════════════════════════════════════════════════════════
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
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.chevron_left_rounded,
                            size: 20, color: Color(0xFF64748B)),
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
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.chevron_right_rounded,
                            size: 20, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Weekday headers
                Row(
                  children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                      .map((d) => Expanded(
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
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _legendItem(AppTheme.success, 'Present'),
                    _legendItem(AppTheme.warning, 'Late'),
                    _legendItem(const Color(0xFF5C5CFF), 'WFH'),
                    _legendItem(const Color(0xFFA855F7), 'On Leave'),
                    _legendItem(const Color(0xFF1E3A8A), 'Holiday'),
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
                    _summaryBox('$present', 'Present', AppTheme.success),
                    const SizedBox(width: 10),
                    _summaryBox('$late', 'Late', AppTheme.warning),
                    const SizedBox(width: 10),
                    _summaryBox('$wfhCount', 'WFH', const Color(0xFF5C5CFF)),
                    const SizedBox(width: 10),
                    _summaryBox('$leaveCount', 'Leave', const Color(0xFFA855F7)),
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
      cells.add(const SizedBox());
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
        Center(
         child: Container(
          width: 38,
          height: 38,
          decoration: isToday
              ? BoxDecoration(
                  color: const Color(0xFF5C5CFF),
                  borderRadius: BorderRadius.circular(19),
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
                          isToday ? Colors.white : AppTheme.textPrimary)),
              if (dotColor != null && !isToday) ...[
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
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
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
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
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

  // ─── Helpers ─────────────────────────────────────────────────────────
  String _getStatus(Map<String, dynamic> data) {
    final rawStatus = (data['status'] ?? data['attendanceStatus'] ?? '').toString().toLowerCase();
    final workMode = (data['workMode'] ?? '').toString().toLowerCase();
    if (rawStatus.contains('leave')) return 'leave';
    if (workMode == 'wfh' || workMode == 'work_from_home') return 'wfh';
    if (rawStatus.contains('late')) return 'late';
    if (data['checkIn'] != null || data['checkInTime'] != null || data['lastCheckIn'] != null || rawStatus.contains('present') || rawStatus.contains('checked')) return 'present';
    return 'absent';
  }

  _StatusInfo _statusInfo(String status) {
    switch (status) {
      case 'present':
        return _StatusInfo('Present', AppTheme.success);
      case 'late':
        return _StatusInfo('Late', AppTheme.warning);
      case 'wfh':
        return _StatusInfo('WFH', const Color(0xFF5C5CFF));
      case 'leave':
        return _StatusInfo('On Leave', const Color(0xFFA855F7));
      case 'holiday':
        return _StatusInfo('Holiday', const Color(0xFF1E3A8A));
      default:
        return _StatusInfo('Absent', AppTheme.danger);
    }
  }
}

class _StatusInfo {
  final String label;
  final Color color;
  const _StatusInfo(this.label, this.color);
}
