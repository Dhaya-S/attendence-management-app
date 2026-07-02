import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';

/// Screen 2 — Monthly Summary (matches center panel in mockup)
class MonthlySummaryScreen extends StatefulWidget {
  const MonthlySummaryScreen({super.key});

  @override
  State<MonthlySummaryScreen> createState() => _MonthlySummaryScreenState();
}

class _MonthlySummaryScreenState extends State<MonthlySummaryScreen> {
  final _user = FirebaseAuth.instance.currentUser;
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  void _prevMonth() => setState(
      () => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1));
  void _nextMonth() {
    final next = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    if (next.isBefore(DateTime.now().add(const Duration(days: 1)))) {
      setState(() => _focusedMonth = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Monthly Summary',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, size: 20, color: AppTheme.textSecondary),
            onPressed: _downloadReport,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.userAttendanceCol(_user?.email ?? '').snapshots(),
        builder: (context, attSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirestoreService.userLeaveRequestsCol(_user?.email ?? '').snapshots(),
            builder: (context, leaveSnap) {
              final attendanceDocs = attSnap.data?.docs ?? [];
              final leaveDocs = leaveSnap.data?.docs ?? [];

              // Filter to focused month
              final monthDocs = attendanceDocs.where((d) {
                final date = DateTime.tryParse(d.id);
                return date != null &&
                    date.year == _focusedMonth.year &&
                    date.month == _focusedMonth.month;
              }).toList();

              final metrics = _computeMonthMetrics(monthDocs, leaveDocs);
              final statusMap = _buildStatusMap(monthDocs);

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month Navigator
                    _buildMonthNavigator(),
                    const SizedBox(height: 16),

                    // Rate Card
                    _buildRateCard(metrics),
                    const SizedBox(height: 16),

                    // Stats Grid
                    _buildStatsGrid(metrics),
                    const SizedBox(height: 16),

                    // Day-by-Day Breakdown (calendar circles)
                    _buildDayByDayCalendar(statusMap),
                    const SizedBox(height: 16),

                    // Attendance Distribution pie
                    _buildDistributionCard(metrics),
                    const SizedBox(height: 20),

                    // Download Report button
                    _buildDownloadButton(),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ─── Month Navigator ──────────────────────────────────────────────────────

  Widget _buildMonthNavigator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: _prevMonth,
          icon: const Icon(Icons.chevron_left, color: AppTheme.textPrimary),
        ),
        Text(
          DateFormat('MMM yyyy').format(_focusedMonth),
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        IconButton(
          onPressed: _nextMonth,
          icon: const Icon(Icons.chevron_right, color: AppTheme.textPrimary),
        ),
      ],
    );
  }

  // ─── Rate Card ───────────────────────────────────────────────────────────

  Widget _buildRateCard(Map<String, dynamic> metrics) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A3E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Summary · ${DateFormat('MMM yyyy').format(_focusedMonth)}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
          ),
          const SizedBox(height: 10),
          Text(
            metrics['rate'] as String,
            style: const TextStyle(
                color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1),
          ),
          Text(
            'Attendance Rate · ${metrics['workingDays']} working days',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ─── Stats Grid ───────────────────────────────────────────────────────────

  Widget _buildStatsGrid(Map<String, dynamic> metrics) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: _buildStatItem(
              metrics['present'].toString(), 'Days Present',
              'of ${metrics['workingDays']} working days',
              const Color(0xFF22C55E),
            ),
          ),
          _verticalDivider(),
          Expanded(
            child: _buildStatItem(
              metrics['late'].toString(), 'Days Late',
              'avg 15 min late',
              const Color(0xFFF59E0B),
            ),
          ),
        ]),
        _horizontalDivider(),
        Row(children: [
          Expanded(
            child: _buildStatItem(
              metrics['leave'].toString(), 'Leave Taken',
              'Annual leave',
              AppTheme.primary,
            ),
          ),
          _verticalDivider(),
          Expanded(
            child: _buildStatItem(
              metrics['holidays'].toString(), 'Holidays',
              'Official holiday',
              AppTheme.primary,
            ),
          ),
        ]),
        _horizontalDivider(),
        Row(children: [
          Expanded(
            child: _buildStatItem(
              metrics['totalHours'] as String, 'Total Off Hours',
              'Eligible for OT pay',
              AppTheme.primary,
            ),
          ),
          _verticalDivider(),
          Expanded(
            child: _buildStatItem(
              metrics['absent'].toString(), 'Absent Days',
              'Perfect attendance',
              AppTheme.textHint,
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildStatItem(String value, String label, String sub, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: valueColor)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        Text(sub,
            style: const TextStyle(fontSize: 10, color: AppTheme.textHint)),
      ]),
    );
  }

  Widget _verticalDivider() => Container(width: 1, height: 64, color: AppTheme.divider);
  Widget _horizontalDivider() => Container(height: 1, color: AppTheme.divider);

  // ─── Day-by-Day Calendar ──────────────────────────────────────────────────

  Widget _buildDayByDayCalendar(Map<int, String> statusMap) {
    final daysInMonth = DateTimeUtils.daysInMonth(_focusedMonth);
    final firstWeekday = _focusedMonth.weekday % 7; // 0=Sun

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Day-by-Day Breakdown',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          // Legend
          Wrap(spacing: 12, runSpacing: 6, children: [
            _legend(const Color(0xFF22C55E), 'Present'),
            _legend(const Color(0xFFF59E0B), 'Late'),
            _legend(AppTheme.primary, 'Leave'),
            _legend(const Color(0xFF8B8BFF), 'Holiday'),
            _legend(AppTheme.textHint, 'Absent'),
          ]),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: daysInMonth + firstWeekday,
            itemBuilder: (context, i) {
              if (i < firstWeekday) return const SizedBox();
              final day = i - firstWeekday + 1;
              final status = statusMap[day];
              return _buildDayCircle(day, status);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayCircle(int day, String? status) {
    final now = DateTime.now();
    final isToday = _focusedMonth.year == now.year &&
        _focusedMonth.month == now.month &&
        day == now.day;
    final isFuture = DateTime(_focusedMonth.year, _focusedMonth.month, day)
        .isAfter(now);

    Color bgColor = Colors.transparent;
    Color textColor = AppTheme.textPrimary;

    if (isToday) {
      bgColor = AppTheme.primary;
      textColor = Colors.white;
    } else if (!isFuture && status != null) {
      switch (status) {
        case 'present':
          bgColor = const Color(0xFF22C55E);
          textColor = Colors.white;
          break;
        case 'late':
          bgColor = const Color(0xFFF59E0B);
          textColor = Colors.white;
          break;
        case 'leave':
          bgColor = AppTheme.primary;
          textColor = Colors.white;
          break;
        case 'holiday':
          bgColor = const Color(0xFF8B8BFF);
          textColor = Colors.white;
          break;
        case 'absent':
          bgColor = AppTheme.divider;
          textColor = AppTheme.textHint;
          break;
      }
    } else if (isFuture) {
      textColor = AppTheme.textHint;
    }

    return Container(
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      child: Center(
        child: Text('$day',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: textColor)),
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textHint, fontWeight: FontWeight.w600)),
    ]);
  }

  // ─── Distribution Pie Chart ───────────────────────────────────────────────

  Widget _buildDistributionCard(Map<String, dynamic> metrics) {
    final present = (metrics['present'] as int).toDouble();
    final late = (metrics['late'] as int).toDouble();
    final wfh = (metrics['wfh'] as int).toDouble();
    final leave = (metrics['leave'] as int).toDouble();
    final total = present + late + wfh + leave;

    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: const Center(
          child: Text('No attendance data yet',
              style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Attendance Distribution',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 16),
        Row(children: [
          SizedBox(
            width: 100,
            height: 100,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 30,
                sections: [
                  if (present > 0)
                    PieChartSectionData(
                      value: present,
                      color: const Color(0xFF22C55E),
                      radius: 20,
                      showTitle: false,
                    ),
                  if (late > 0)
                    PieChartSectionData(
                      value: late,
                      color: const Color(0xFFF59E0B),
                      radius: 20,
                      showTitle: false,
                    ),
                  if (wfh > 0)
                    PieChartSectionData(
                      value: wfh,
                      color: AppTheme.primary,
                      radius: 20,
                      showTitle: false,
                    ),
                  if (leave > 0)
                    PieChartSectionData(
                      value: leave,
                      color: const Color(0xFF8B8BFF),
                      radius: 20,
                      showTitle: false,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(children: [
              _distRow(const Color(0xFF22C55E), 'Present', present.toInt()),
              const SizedBox(height: 8),
              _distRow(const Color(0xFFF59E0B), 'Late', late.toInt()),
              const SizedBox(height: 8),
              _distRow(AppTheme.primary, 'WFH', wfh.toInt()),
              const SizedBox(height: 8),
              _distRow(const Color(0xFF8B8BFF), 'Leave', leave.toInt()),
            ]),
          ),
        ]),
      ]),
    );
  }

  Widget _distRow(Color color, String label, int count) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500))),
      Text('$count',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
    ]);
  }

  // ─── Download Button ──────────────────────────────────────────────────────

  Widget _buildDownloadButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _downloadReport,
        icon: const Icon(Icons.download_rounded, size: 18),
        label: const Text('Download Report',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }

  // ─── Data helpers ─────────────────────────────────────────────────────────

  Map<String, dynamic> _computeMonthMetrics(
      List<QueryDocumentSnapshot> monthDocs, List<QueryDocumentSnapshot> leaveDocs) {
    int present = 0, late = 0, leave = 0, holiday = 0, absent = 0, wfh = 0;
    int overtimeMinutes = 0;

    final daysInMonth = DateTimeUtils.daysInMonth(_focusedMonth);
    final workingDays = _countWorkingDaysInMonth(_focusedMonth);

    for (final doc in monthDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String? ?? '';
      final checkIn = data['checkIn'] as Timestamp?;
      final checkOut = data['checkOut'] as Timestamp?;
      final workMode = data['workMode'] as String? ?? 'office';

      if (status == 'holiday') {
        holiday++;
        continue;
      }
      if (status == 'leave') {
        leave++;
        continue;
      }

      if (checkIn != null) {
        if (workMode == 'wfh' || workMode == 'remote') wfh++;
        if (status == 'late') late++;
        present++;

        if (checkOut != null) {
          final diff = checkOut.toDate().difference(checkIn.toDate());
          if (diff.inMinutes > 480) overtimeMinutes += diff.inMinutes - 480;
        }
      }
    }

    // Count leave from leave_requests for this month
    for (final doc in leaveDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String? ?? '';
      if (status != 'approved') continue;
      final startTs = data['startDate'] as Timestamp?;
      if (startTs != null) {
        final d = startTs.toDate();
        if (d.year == _focusedMonth.year && d.month == _focusedMonth.month) {
          leave++;
        }
      }
    }

    final otH = overtimeMinutes ~/ 60;
    final otM = overtimeMinutes % 60;
    final rate = workingDays > 0 ? (present / workingDays * 100) : 0.0;

    return {
      'rate': '${rate.toStringAsFixed(1)}%',
      'present': present,
      'late': late,
      'leave': leave,
      'holidays': holiday,
      'absent': absent,
      'wfh': wfh,
      'workingDays': workingDays,
      'daysInMonth': daysInMonth,
      'totalHours': '${otH}h ${otM.toString().padLeft(2, '0')}m',
    };
  }

  Map<int, String> _buildStatusMap(List<QueryDocumentSnapshot> monthDocs) {
    final map = <int, String>{};
    for (final doc in monthDocs) {
      final date = DateTime.tryParse(doc.id);
      if (date == null) continue;
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String? ?? '';
      final checkIn = data['checkIn'] as Timestamp?;

      String s;
      if (status == 'holiday') {
        s = 'holiday';
      } else if (status == 'leave') {
        s = 'leave';
      } else if (checkIn != null) {
        s = status == 'late' ? 'late' : 'present';
      } else {
        s = 'absent';
      }
      map[date.day] = s;
    }
    return map;
  }

  int _countWorkingDaysInMonth(DateTime month) {
    final lastDay = DateTimeUtils.daysInMonth(month);
    int count = 0;
    for (int d = 1; d <= lastDay; d++) {
      final date = DateTime(month.year, month.month, d);
      if (date.weekday != DateTime.saturday && date.weekday != DateTime.sunday) count++;
    }
    return count;
  }

  Future<void> _downloadReport() async {
    try {
      final snap = await FirestoreService.userAttendanceCol(_user?.email ?? '').get();
      final monthDocs = snap.docs.where((d) {
        final date = DateTime.tryParse(d.id);
        return date != null &&
            date.year == _focusedMonth.year &&
            date.month == _focusedMonth.month;
      }).toList();

      final csvRows = <List<String>>[
        ['Date', 'Status', 'Check In', 'Check Out', 'Total Hours', 'Work Mode'],
      ];

      for (final doc in monthDocs) {
        final data = doc.data();
        final checkIn = data['checkIn'] as Timestamp?;
        final checkOut = data['checkOut'] as Timestamp?;
        String totalHours = '--';
        if (checkIn != null && checkOut != null) {
          final diff = checkOut.toDate().difference(checkIn.toDate());
          totalHours = '${diff.inHours}h ${diff.inMinutes % 60}m';
        }
        csvRows.add([
          doc.id,
          '${data['status'] ?? '--'}',
          checkIn != null ? DateFormat('hh:mm a').format(checkIn.toDate()) : '--',
          checkOut != null ? DateFormat('hh:mm a').format(checkOut.toDate()) : '--',
          totalHours,
          '${data['workMode'] ?? 'office'}',
        ]);
      }

      final csvData = '\uFEFF${csvRows.map((r) => r.map((c) => '"$c"').join(',')).join('\n')}';
      final dir = await getTemporaryDirectory();
      final fileName =
          'attendance_${DateFormat('MMMM_yyyy').format(_focusedMonth)}.csv';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(csvData);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Attendance Report - ${DateFormat('MMMM yyyy').format(_focusedMonth)}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }
}

/// Date utility helpers
class DateTimeUtils {
  static int daysInMonth(DateTime month) =>
      DateTime(month.year, month.month + 1, 0).day;
}
