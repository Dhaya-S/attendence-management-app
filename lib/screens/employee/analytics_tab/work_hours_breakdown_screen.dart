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

/// Screen 3 â€” Work Hours Breakdown (matches right panel in mockup)
class WorkHoursBreakdownScreen extends StatefulWidget {
  const WorkHoursBreakdownScreen({super.key});

  @override
  State<WorkHoursBreakdownScreen> createState() => _WorkHoursBreakdownScreenState();
}

class _WorkHoursBreakdownScreenState extends State<WorkHoursBreakdownScreen> {
  final _user = FirebaseAuth.instance.currentUser;
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    // Start of current ISO week (Monday)
    final now = DateTime.now();
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
    _weekStart = DateTime(_weekStart.year, _weekStart.month, _weekStart.day);
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 4)); // Friday

  void _prevWeek() =>
      setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
  void _nextWeek() {
    final next = _weekStart.add(const Duration(days: 7));
    if (next.isBefore(DateTime.now().add(const Duration(days: 1)))) {
      setState(() => _weekStart = next);
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
        title: const Text('Work Hours Breakdown',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, size: 20, color: AppTheme.textSecondary),
            onPressed: () {},
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.userAttendanceCol(_user?.email ?? '').snapshots(),
        builder: (context, snapshot) {
          final allDocs = snapshot.data?.docs ?? [];
          final weekData = _buildWeekData(allDocs);
          final metrics = _computeMetrics(weekData);

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Week Navigator Header
                _buildWeekHeader(),
                const SizedBox(height: 16),

                // Bar Chart
                _buildBarChart(weekData),
                const SizedBox(height: 16),

                // Summary rows
                Row(children: [
                  Expanded(child: _buildSummaryBox(
                    metrics['totalHours'] as String,
                    'Total Hours',
                    AppTheme.primary,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSummaryBox(
                    metrics['overtime'] as String,
                    'Overtime',
                    const Color(0xFFF59E0B),
                    isHighlight: false,
                  )),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _buildSummaryBox(
                    '${metrics['totalDays']} days',
                    'Total Days',
                    AppTheme.success,
                    isHighlight: false,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSummaryBox(
                    '${metrics['wfhDays']}',
                    'WFH Days',
                    AppTheme.textHint,
                    isHighlight: false,
                  )),
                ]),
                const SizedBox(height: 20),

                // Day-by-Day Breakdown list
                _buildDayByDayList(weekData),
                const SizedBox(height: 20),

                // Download Report
                _buildDownloadButton(weekData),
              ],
            ),
          );
        },
      ),
    );
  }

  // â”€â”€â”€ Week Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildWeekHeader() {
    final endDate = _weekStart.add(const Duration(days: 4));
    final label =
        '${_weekStart.day}â€“${endDate.day} ${DateFormat('MMM yyyy').format(_weekStart)} Â· Daily Work Hours';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(
          onPressed: _prevWeek,
          icon: const Icon(Icons.chevron_left, color: AppTheme.textPrimary),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        Expanded(
          child: Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textHint)),
        ),
        IconButton(
          onPressed: _nextWeek,
          icon: const Icon(Icons.chevron_right, color: AppTheme.textPrimary),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    ]);
  }

  // â”€â”€â”€ Bar Chart â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildBarChart(List<_DayData> weekData) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    final maxHours = weekData.map((d) => d.hours).fold(0.0, (a, b) => a > b ? a : b);
    final chartMax = (maxHours + 1).clamp(5.0, 12.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Daily Work Hours â€” This Week',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: chartMax,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  tooltipRoundedRadius: 8,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${rod.toY.toStringAsFixed(1)}h',
                      const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (val, meta) {
                      final idx = val.toInt();
                      if (idx < 0 || idx >= days.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(days[idx],
                            style: const TextStyle(
                                color: AppTheme.textHint,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (val, meta) {
                      if (val % 2 != 0) return const SizedBox();
                      return Text(
                        val.toInt().toString(),
                        style: const TextStyle(
                            color: AppTheme.textHint, fontSize: 10, fontWeight: FontWeight.w500),
                      );
                    },
                    interval: 2,
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 2,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppTheme.divider.withValues(alpha: 0.5),
                  strokeWidth: 1,
                ),
              ),
              barGroups: weekData.asMap().entries.map((entry) {
                final idx = entry.key;
                final d = entry.value;
                final isToday = DateTime.now().weekday - 1 == idx &&
                    _weekStart.day <= DateTime.now().day &&
                    DateTime.now().day <= _weekEnd.day;
                return BarChartGroupData(
                  x: idx,
                  barRods: [
                    BarChartRodData(
                      toY: d.hours > 0 ? d.hours : 0,
                      color: isToday
                          ? AppTheme.primary
                          : AppTheme.primary.withValues(alpha: 0.65),
                      width: 32,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ]),
    );
  }

  // â”€â”€â”€ Summary Box â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildSummaryBox(String value, String label, Color color,
      {bool isHighlight = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: isHighlight ? AppTheme.primarySurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isHighlight ? AppTheme.primary : AppTheme.textPrimary)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: isHighlight ? AppTheme.primary.withValues(alpha: 0.7) : AppTheme.textHint,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // â”€â”€â”€ Day-by-Day List â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildDayByDayList(List<_DayData> weekData) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    final maxHours = weekData.map((d) => d.hours).fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Day-by-Day Breakdown',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 16),
        ...weekData.asMap().entries.map((entry) {
          final idx = entry.key;
          final d = entry.value;
          final label = idx < dayNames.length ? dayNames[idx] : 'Day';
          final fraction = maxHours > 0 ? (d.hours / maxHours).clamp(0.0, 1.0) : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              SizedBox(
                width: 36,
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary)),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(children: [
                    Container(
                      height: 8,
                      color: AppTheme.divider,
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      height: 8,
                      width: double.infinity,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: fraction,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 36,
                child: Text(
                  d.hours > 0 ? '${d.hours.toStringAsFixed(1)}h' : '--',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: d.hours > 0 ? AppTheme.textPrimary : AppTheme.textHint),
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  // â”€â”€â”€ Download Button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildDownloadButton(List<_DayData> weekData) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () => _downloadReport(weekData),
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

  // â”€â”€â”€ Data helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  List<_DayData> _buildWeekData(List<QueryDocumentSnapshot> allDocs) {
    final result = List.generate(5, (i) {
      final date = _weekStart.add(Duration(days: i));
      return _DayData(date: date, hours: 0, overtimeHours: 0, isWfh: false);
    });

    for (final doc in allDocs) {
      final date = DateTime.tryParse(doc.id);
      if (date == null) continue;
      final diff = date.difference(_weekStart).inDays;
      if (diff < 0 || diff > 4) continue;

      final data = doc.data() as Map<String, dynamic>;
      final checkIn = data['checkIn'] as Timestamp?;
      final checkOut = data['checkOut'] as Timestamp?;
      final workMode = data['workMode'] as String? ?? 'office';

      if (checkIn != null && checkOut != null) {
        final minutes = checkOut.toDate().difference(checkIn.toDate()).inMinutes;
        final hours = minutes / 60.0;
        final overtime = hours > 8.0 ? hours - 8.0 : 0.0;
        result[diff] = _DayData(
          date: date,
          hours: hours,
          overtimeHours: overtime,
          isWfh: workMode == 'wfh' || workMode == 'remote',
        );
      }
    }
    return result;
  }

  Map<String, dynamic> _computeMetrics(List<_DayData> weekData) {
    double totalHours = weekData.fold(0.0, (sum, d) => sum + d.hours);
    double totalOvertime = weekData.fold(0.0, (sum, d) => sum + d.overtimeHours);
    int totalDays = weekData.where((d) => d.hours > 0).length;
    int wfhDays = weekData.where((d) => d.isWfh).length;

    final totalH = totalHours.floor();
    final totalM = ((totalHours - totalH) * 60).round();
    final otH = totalOvertime.floor();
    final otM = ((totalOvertime - otH) * 60).round();

    return {
      'totalHours': totalH > 0 || totalM > 0
          ? '${totalH}h ${totalM.toString().padLeft(2, '0')}m'
          : '0h 00m',
      'overtime': otH > 0 || otM > 0
          ? '${otH}h ${otM.toString().padLeft(2, '0')}m'
          : '0h 00m',
      'totalDays': totalDays,
      'wfhDays': wfhDays,
    };
  }

  Future<void> _downloadReport(List<_DayData> weekData) async {
    try {
      const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
      final csvRows = <List<String>>[
        ['Day', 'Date', 'Hours Worked', 'Overtime', 'Work Mode'],
      ];
      for (int i = 0; i < weekData.length; i++) {
        final d = weekData[i];
        csvRows.add([
          dayNames[i],
          DateFormat('yyyy-MM-dd').format(d.date),
          d.hours > 0 ? '${d.hours.toStringAsFixed(2)}h' : '--',
          d.overtimeHours > 0 ? '${d.overtimeHours.toStringAsFixed(2)}h' : '0h',
          d.isWfh ? 'WFH' : 'Office',
        ]);
      }

      final csvData = '\uFEFF${csvRows.map((r) => r.map((c) => '"$c"').join(',')).join('\n')}';
      final dir = await getTemporaryDirectory();
      final weekEnd = _weekStart.add(const Duration(days: 4));
      final fileName =
          'work_hours_${DateFormat('dd-MMM').format(_weekStart)}_${DateFormat('dd-MMM-yyyy').format(weekEnd)}.csv';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(csvData);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Work Hours Report',
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

class _DayData {
  final DateTime date;
  final double hours;
  final double overtimeHours;
  final bool isWfh;

  const _DayData({
    required this.date,
    required this.hours,
    required this.overtimeHours,
    required this.isWfh,
  });
}
