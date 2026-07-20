import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'monthly_summary_screen.dart';
import 'work_hours_breakdown_screen.dart';

/// Screen 1 of the Analytics tab â€” matches the left panel in the mockup
class AnalyticsMainScreen extends StatefulWidget {
  const AnalyticsMainScreen({super.key});

  @override
  State<AnalyticsMainScreen> createState() => _AnalyticsMainScreenState();
}

class _AnalyticsMainScreenState extends State<AnalyticsMainScreen> {
  final _user = FirebaseAuth.instance.currentUser;
  int _selectedPeriod = 0; // 0=This Month, 1=Last Month, 2=Quarterly, 3=Yearly
  final List<String> _periods = ['This Month', 'Last Month', 'Quarterly', 'Yearly'];

  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 0: // This Month
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0),
        );
      case 1: // Last Month
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        return DateTimeRange(
          start: lastMonth,
          end: DateTime(now.year, now.month, 0),
        );
      case 2: // Quarterly
        final quarterStart = DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1, 1);
        return DateTimeRange(
          start: quarterStart,
          end: now,
        );
      case 3: // Yearly
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: now,
        );
      default:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.userAttendanceCol(_user?.email ?? '').snapshots(),
      builder: (context, snapshot) {
        final range = _getDateRange();
        final docs = snapshot.data?.docs ?? [];

        // Filter docs in range
        final filtered = docs.where((d) {
          final date = DateTime.tryParse(d.id);
          if (date == null) return false;
          return !date.isBefore(range.start) && !date.isAfter(range.end);
        }).toList();

        // Compute metrics
        final metrics = _computeMetrics(filtered, range);

        // Build monthly line chart data (last 3 months avg hours per month)
        final lineData = _buildMonthlyLineData(docs);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Period selector
              _buildPeriodSelector(),
              const SizedBox(height: 16),

              // Attendance Rate Card (gradient)
              _buildRateCard(metrics, range),
              const SizedBox(height: 16),

              // Stats grid
              Row(children: [
                Expanded(child: _buildStatCard('Avg Daily Hours', metrics['avgHours']!, null, isPositive: true)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Punctuality Score', metrics['punctuality']!, metrics['punctualityDelta']!, isPositive: true)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _buildStatCard('Total Overtime', metrics['overtime']!, metrics['overtimeDelta']!, isPositive: true)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Consistency', metrics['consistency']!, null, isPositive: true, isStable: true)),
              ]),
              const SizedBox(height: 20),

              // Weekly Working Hours chart
              _buildWeeklyChart(lineData),
              const SizedBox(height: 16),

              // Monthly Summary tile
              _buildActionTile(
                icon: Icons.bar_chart_rounded,
                color: AppTheme.primary,
                title: 'Monthly Summary',
                subtitle: 'Full month breakdown & report',
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const MonthlySummaryScreen(),
                )),
              ),
              const SizedBox(height: 12),

              // Work Hours Breakdown tile
              _buildActionTile(
                icon: Icons.access_time_rounded,
                color: AppTheme.success,
                title: 'Work Hours Breakdown',
                subtitle: 'Productive hours & overtime trends',
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const WorkHoursBreakdownScreen(),
                )),
              ),
            ],
          ),
        );
      },
    );
  }

  // â”€â”€â”€ Period Selector â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildPeriodSelector() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _periods.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final selected = _selectedPeriod == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedPeriod = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppTheme.primary : AppTheme.divider,
                ),
              ),
              child: Text(
                _periods[i],
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // â”€â”€â”€ Rate Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildRateCard(Map<String, String> metrics, DateTimeRange range) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attendance Rate Â· ${_periodLabel(range)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                metrics['rate']!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              Row(children: [
                const Icon(Icons.trending_up, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  '+2.1% vs last period',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: _buildRateSubBox(metrics['present']!, 'Present')),
            const SizedBox(width: 8),
            Expanded(child: _buildRateSubBox(metrics['punctual']!, 'Punctual')),
            const SizedBox(width: 8),
            Expanded(child: _buildRateSubBox(metrics['overtimeShort']!, 'Overtime')),
          ]),
        ],
      ),
    );
  }

  Widget _buildRateSubBox(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // â”€â”€â”€ Stat Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildStatCard(String title, String value, String? delta,
      {bool isPositive = true, bool isStable = false}) {
    final Color deltaColor = isStable
        ? AppTheme.success
        : (isPositive ? AppTheme.primary : AppTheme.danger);
    final IconData deltaIcon = isStable
        ? Icons.trending_flat
        : (isPositive ? Icons.trending_up : Icons.trending_down);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textHint, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                fontSize: 20, color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
        if (delta != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            Icon(deltaIcon, size: 14, color: deltaColor),
            const SizedBox(width: 4),
            Text(delta,
                style: TextStyle(fontSize: 11, color: deltaColor, fontWeight: FontWeight.w700)),
          ]),
        ],
      ]),
    );
  }

  // â”€â”€â”€ Weekly Chart â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildWeeklyChart(List<FlSpot> spots) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Weekly Working Hours',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          Icon(Icons.chevron_right, color: AppTheme.textHint, size: 20),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          height: 130,
          child: LineChart(
            LineChartData(
              minY: 6,
              maxY: 10,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppTheme.primary,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, bar, index) =>
                        FlDotCirclePainter(
                      radius: 4,
                      color: AppTheme.primary,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppTheme.primary.withValues(alpha: 0.08),
                  ),
                ),
              ],
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (val, meta) {
                      const labels = ['May', 'Jun', 'Jul'];
                      final idx = val.toInt();
                      if (idx < 0 || idx >= labels.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(labels[idx],
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
                    getTitlesWidget: (val, meta) => Text(
                      val.toInt().toString(),
                      style: const TextStyle(
                          color: AppTheme.textHint, fontSize: 10, fontWeight: FontWeight.w500),
                    ),
                    interval: 1,
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppTheme.divider.withValues(alpha: 0.5),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
      ]),
    );
  }

  // â”€â”€â”€ Action Tile â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildActionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: AppTheme.textHint, size: 20),
        ]),
      ),
    );
  }

  // â”€â”€â”€ Data helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Map<String, String> _computeMetrics(List<QueryDocumentSnapshot> docs, DateTimeRange range) {
    int present = 0;
    int late = 0;
    int totalMinutes = 0;
    int overtimeMinutes = 0;
    int workingDays = _countWorkingDays(range.start, range.end);

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final checkIn = data['checkIn'] as Timestamp?;
      final checkOut = data['checkOut'] as Timestamp?;

      if (checkIn != null) {
        final status = data['status'] as String? ?? 'present';
        if (status == 'late') {
          late++;
        }
        present++;

        if (checkOut != null) {
          final diff = checkOut.toDate().difference(checkIn.toDate());
          totalMinutes += diff.inMinutes;
          if (diff.inMinutes > 480) { // > 8 hours
            overtimeMinutes += diff.inMinutes - 480;
          }
        }
      }
    }

    final rate = workingDays > 0 ? (present / workingDays * 100) : 0.0;
    final punctuality = present > 0 ? ((present - late) / present * 100) : 0.0;
    final avgMin = present > 0 ? totalMinutes ~/ present : 0;
    final avgH = avgMin ~/ 60;
    final avgM = avgMin % 60;
    final otH = overtimeMinutes ~/ 60;
    final otM = overtimeMinutes % 60;

    String consistency = 'Low';
    if (rate >= 95) consistency = 'High';
    else if (rate >= 80) consistency = 'Medium';

    return {
      'rate': '${rate.toStringAsFixed(1)}%',
      'present': '$present',
      'punctual': '${punctuality.toStringAsFixed(0)}%',
      'overtimeShort': overtimeMinutes > 0 ? '${otH}h' : '0h',
      'avgHours': avgMin > 0 ? '${avgH}h ${avgM.toString().padLeft(2, '0')}m' : '--',
      'punctuality': '${punctuality.toStringAsFixed(0)}%',
      'punctualityDelta': late > 0 ? '-${late} late' : 'On time',
      'overtime': overtimeMinutes > 0 ? '${otH}h ${otM.toString().padLeft(2, '0')}m' : '0h 00m',
      'overtimeDelta': '+${otH}h',
      'consistency': consistency,
    };
  }

  int _countWorkingDays(DateTime start, DateTime end) {
    int count = 0;
    DateTime d = start;
    while (!d.isAfter(end)) {
      if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) count++;
      d = d.add(const Duration(days: 1));
    }
    return count;
  }

  List<FlSpot> _buildMonthlyLineData(List<QueryDocumentSnapshot> allDocs) {
    final now = DateTime.now();
    // Build avg hours for last 3 months (indices 0=2 months ago, 1=last, 2=this)
    final months = [
      DateTime(now.year, now.month - 2, 1),
      DateTime(now.year, now.month - 1, 1),
      DateTime(now.year, now.month, 1),
    ];
    final spots = <FlSpot>[];
    for (int i = 0; i < months.length; i++) {
      final m = months[i];
      final monthDocs = allDocs.where((d) {
        final date = DateTime.tryParse(d.id);
        return date != null && date.year == m.year && date.month == m.month;
      }).toList();

      double totalHours = 0;
      int count = 0;
      for (final doc in monthDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final checkIn = data['checkIn'] as Timestamp?;
        final checkOut = data['checkOut'] as Timestamp?;
        if (checkIn != null && checkOut != null) {
          totalHours += checkOut.toDate().difference(checkIn.toDate()).inMinutes / 60.0;
          count++;
        }
      }
      final avg = count > 0 ? totalHours / count : 8.0;
      spots.add(FlSpot(i.toDouble(), avg.clamp(6.0, 10.0)));
    }
    return spots.isEmpty
        ? [const FlSpot(0, 8), const FlSpot(1, 7.5), const FlSpot(2, 8.2)]
        : spots;
  }

  String _periodLabel(DateTimeRange range) {
    if (_selectedPeriod == 0 || _selectedPeriod == 1) {
      return DateFormat('MMMM yyyy').format(range.start);
    }
    if (_selectedPeriod == 2) {
      return 'Q${((range.start.month - 1) ~/ 3) + 1} ${range.start.year}';
    }
    return '${range.start.year}';
  }
}
