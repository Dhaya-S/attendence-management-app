import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

import 'package:attendance_app/screens/employee/analytics_tab/monthly_summary_screen.dart';

import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';

/// Analytics tab â€” Attendance Rate, metrics grid with period toggle.
class AttendanceAnalyticsTab extends StatefulWidget {
  const AttendanceAnalyticsTab({super.key});

  @override
  State<AttendanceAnalyticsTab> createState() => _AttendanceAnalyticsTabState();
}

class _AttendanceAnalyticsTabState extends State<AttendanceAnalyticsTab> {
  final _user = FirebaseAuth.instance.currentUser;
  int _selectedPeriod = 0; // 0=This Month, 1=Last Month, 2=Quarterly, 3=Yearly
  final _periodLabels = ['This Month', 'Last Month', 'Quarterly', 'Yearly'];

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
        final stats = _computeStats(docs);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          child: Column(
            children: [
              // Period toggle
              _buildPeriodToggle(),
              const SizedBox(height: 16),

              // Main Attendance Rate card
              _buildRateCard(stats),
              const SizedBox(height: 16),

              // Metrics grid
              _buildMetricsGrid(stats),
              const SizedBox(height: 16),

              // Monthly Summary action
              _buildMonthlySummaryAction(),
            ],
          ),
        );
      },
    );
  }

  // â”€â”€â”€ Period Toggle â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildPeriodToggle() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(_periodLabels.length, (i) {
          final isActive = _selectedPeriod == i;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.primary : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: isActive ? AppTheme.primary : AppTheme.divider),
                ),
                child: Text(_periodLabels[i],
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            isActive ? Colors.white : AppTheme.textMuted)),
              ),
            ),
          );
        }),
      ),
    );
  }

  // â”€â”€â”€ Main Rate Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildRateCard(_AnalyticsStats stats) {
    final periodLabel = _getPeriodLabel();
    final changeStr = stats.rateChange >= 0
        ? '+${stats.rateChange.toStringAsFixed(1)}%'
        : '${stats.rateChange.toStringAsFixed(1)}%';
    final changeColor =
        stats.rateChange >= 0 ? AppTheme.success : AppTheme.danger;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5C5CFF), Color(0xFF4040E0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Attendance Rate Â· $periodLabel',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.7))),
                    const SizedBox(height: 8),
                    Text('${stats.attendanceRate.toStringAsFixed(1)}%',
                        style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1,
                            fontFeatures: [FontFeature.tabularFigures()])),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: changeColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$changeStr vs last period',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.9))),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Sub stats
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _rateSubStat('${stats.present}', 'Present'),
                  _verticalDivider(),
                  _rateSubStat('${stats.punctualPercent.round()}%', 'Punctual'),
                  _verticalDivider(),
                  _rateSubStat(stats.overtimeStr, 'Overtime'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rateSubStat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.6))),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withOpacity(0.15),
    );
  }

  // â”€â”€â”€ Metrics Grid â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildMetricsGrid(_AnalyticsStats stats) {
    return Column(
      children: [
        Row(
          children: [
            _metricCard(
              value: stats.avgDailyHours,
              label: 'Avg Daily Hours',
              change: '+${stats.avgHrsChange.toStringAsFixed(1)}%',
              changePositive: stats.avgHrsChange >= 0,
              color: AppTheme.primary,
            ),
            const SizedBox(width: 12),
            _metricCard(
              value: '${stats.punctualPercent.round()}%',
              label: 'Punctuality Score',
              change: '+${stats.punctualChange.toStringAsFixed(1)}%',
              changePositive: stats.punctualChange >= 0,
              color: AppTheme.success,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _metricCard(
              value: stats.overtimeStr,
              label: 'Total Overtime',
              change: stats.overtimeChange,
              changePositive: true,
              color: AppTheme.warning,
            ),
            const SizedBox(width: 12),
            _metricCard(
              value: stats.consistency,
              label: 'Consistency',
              change: stats.consistencyTrend,
              changePositive: stats.consistency == 'High' || stats.consistency == 'Stable',
              color: const Color(0xFF8B5CF6),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metricCard({
    required String value,
    required String label,
    required String change,
    required bool changePositive,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.divider.withOpacity(0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()])),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted)),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (changePositive ? AppTheme.success : AppTheme.danger)
                    .withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(change,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: changePositive
                          ? AppTheme.success
                          : AppTheme.danger)),
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€ Monthly Summary Action â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildMonthlySummaryAction() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.divider.withOpacity(0.6)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MonthlySummaryScreen(),
            ),
          );
        },
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bar_chart_rounded,
                  color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Monthly Summary',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  SizedBox(height: 2),
                  Text('Full month breakdown & report',
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

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Compute Stats â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  _AnalyticsStats _computeStats(List<QueryDocumentSnapshot> allDocs) {
    final now = DateTime.now();
    DateTime rangeStart;
    DateTime rangeEnd = now;
    DateTime prevStart;
    DateTime prevEnd;

    switch (_selectedPeriod) {
      case 0: // This Month
        rangeStart = DateTime(now.year, now.month, 1);
        prevStart = DateTime(now.year, now.month - 1, 1);
        prevEnd = DateTime(now.year, now.month, 0);
        break;
      case 1: // Last Month
        rangeStart = DateTime(now.year, now.month - 1, 1);
        rangeEnd = DateTime(now.year, now.month, 0);
        prevStart = DateTime(now.year, now.month - 2, 1);
        prevEnd = DateTime(now.year, now.month - 1, 0);
        break;
      case 2: // Quarterly
        final qStart = ((now.month - 1) ~/ 3) * 3 + 1;
        rangeStart = DateTime(now.year, qStart, 1);
        prevStart = DateTime(now.year, qStart - 3, 1);
        prevEnd = DateTime(now.year, qStart, 0);
        break;
      default: // Yearly
        rangeStart = DateTime(now.year, 1, 1);
        prevStart = DateTime(now.year - 1, 1, 1);
        prevEnd = DateTime(now.year - 1, 12, 31);
        break;
    }

    final currentDocs = _filterDocs(allDocs, rangeStart, rangeEnd);
    final prevDocs = _filterDocs(allDocs, prevStart, prevEnd);

    // Current stats
    int present = 0, late = 0, totalMinutes = 0, overtimeMinutes = 0;
    final shiftParts = AppSession().shiftEndTime.split(':');
    final shiftStartParts = AppSession().shiftStartTime.split(':');
    final shiftDurationMinutes = (int.tryParse(shiftParts[0]) ?? 18) * 60 +
        (int.tryParse(shiftParts[1]) ?? 0) -
        ((int.tryParse(shiftStartParts[0]) ?? 9) * 60 +
            (int.tryParse(shiftStartParts[1]) ?? 0));

    for (final doc in currentDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final checkIn = data['checkIn'] as Timestamp?;
      final checkOut = data['checkOut'] as Timestamp?;
      final rawStatus = (data['status'] ?? '').toString().toLowerCase();

      if (checkIn != null) {
        present++;
        if (rawStatus.contains('late')) late++;

        if (checkOut != null) {
          final diff = checkOut.toDate().difference(checkIn.toDate());
          totalMinutes += diff.inMinutes;
          final overtime = diff.inMinutes - shiftDurationMinutes;
          if (overtime > 0) overtimeMinutes += overtime;
        }
      }
    }

    final total = currentDocs.length > 0 ? currentDocs.length : 1;
    final attendanceRate = present > 0 ? (present / total * 100) : 0.0;
    final punctual = present > 0 ? ((present - late) / present * 100) : 0.0;
    final avgMinutes = present > 0 ? (totalMinutes / present) : 0;
    final avgHrs = '${(avgMinutes ~/ 60)}h ${(avgMinutes.round() % 60).toString().padLeft(2, '0')}m';

    // Previous period stats for comparison
    int prevPresent = 0, prevLate = 0, prevTotalMinutes = 0;
    for (final doc in prevDocs) {
      final data = doc.data() as Map<String, dynamic>;
      if ((data['checkIn'] as Timestamp?) != null) {
        prevPresent++;
        if ((data['status'] ?? '').toString().toLowerCase().contains('late')) prevLate++;
        final ci = data['checkIn'] as Timestamp?;
        final co = data['checkOut'] as Timestamp?;
        if (ci != null && co != null) {
          prevTotalMinutes += co.toDate().difference(ci.toDate()).inMinutes;
        }
      }
    }

    final prevTotal = prevDocs.length > 0 ? prevDocs.length : 1;
    final prevRate = prevPresent > 0 ? (prevPresent / prevTotal * 100) : 0.0;
    final prevPunctual =
        prevPresent > 0 ? ((prevPresent - prevLate) / prevPresent * 100) : 0.0;
    final prevAvg = prevPresent > 0 ? (prevTotalMinutes / prevPresent) : 0;

    final rateChange = attendanceRate - prevRate;
    final punctualChange = punctual - prevPunctual;
    final avgHrsChange =
        prevAvg > 0 ? ((avgMinutes - prevAvg) / prevAvg * 100) : 0.0;

    // Overtime string
    final otHrs = overtimeMinutes ~/ 60;
    final otMin = overtimeMinutes % 60;
    final overtimeStr = '${otHrs}h ${otMin.toString().padLeft(2, '0')}m';

    // Consistency
    String consistency;
    String consistencyTrend;
    if (punctual >= 90) {
      consistency = 'High';
      consistencyTrend = 'â†’Stable';
    } else if (punctual >= 70) {
      consistency = 'Medium';
      consistencyTrend = '+1 level';
    } else {
      consistency = 'Low';
      consistencyTrend = 'Needs improvement';
    }

    return _AnalyticsStats(
      attendanceRate: attendanceRate,
      rateChange: rateChange,
      present: present,
      punctualPercent: punctual,
      punctualChange: punctualChange,
      avgDailyHours: avgHrs,
      avgHrsChange: avgHrsChange,
      overtimeStr: overtimeStr,
      overtimeChange: '+${otHrs}h',
      consistency: consistency,
      consistencyTrend: consistencyTrend,
    );
  }

  List<QueryDocumentSnapshot> _filterDocs(
      List<QueryDocumentSnapshot> docs, DateTime start, DateTime end) {
    return docs.where((d) {
      try {
        final date = DateFormat('yyyy-MM-dd').parse(d.id);
        return !date.isBefore(start) && !date.isAfter(end);
      } catch (_) {
        return false;
      }
    }).toList();
  }

  String _getPeriodLabel() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 0:
        return DateFormat('MMM yyyy').format(now);
      case 1:
        return DateFormat('MMM yyyy')
            .format(DateTime(now.year, now.month - 1));
      case 2:
        final q = ((now.month - 1) ~/ 3) + 1;
        return 'Q$q ${now.year}';
      default:
        return 'FY ${now.year - 1}â€“${now.year.toString().substring(2)}';
    }
  }
}

class _AnalyticsStats {
  final double attendanceRate;
  final double rateChange;
  final int present;
  final double punctualPercent;
  final double punctualChange;
  final String avgDailyHours;
  final double avgHrsChange;
  final String overtimeStr;
  final String overtimeChange;
  final String consistency;
  final String consistencyTrend;

  const _AnalyticsStats({
    required this.attendanceRate,
    required this.rateChange,
    required this.present,
    required this.punctualPercent,
    required this.punctualChange,
    required this.avgDailyHours,
    required this.avgHrsChange,
    required this.overtimeStr,
    required this.overtimeChange,
    required this.consistency,
    required this.consistencyTrend,
  });
}
