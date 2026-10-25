import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:fl_chart/fl_chart.dart';

class OrgOverviewTab extends StatelessWidget {
  const OrgOverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppSession().hasPermission('organization')) {
      return Container(
        color: const Color(0xFFF4F6F9),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 48, color: Color(0xFF9CA3AF)),
            SizedBox(height: 16),
            Text('Permission Denied', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
            SizedBox(height: 8),
            Text('You do not have permission to access Organization data.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
          ],
        ),
      );
    }
    return Container(
      color: const Color(0xFFF4F6F9),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.employeesCol.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          int totalEmployees = docs.length;
          Set<String> departments = {};
          Map<String, int> deptCounts = {};

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final dept = (data['department'] ?? 'Unknown').toString();
            if (dept.isNotEmpty) {
              departments.add(dept);
              deptCounts[dept] = (deptCounts[dept] ?? 0) + 1;
            }
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirestoreService.tasksCol.snapshots(),
            builder: (context, tasksSnap) {
              final tasks = tasksSnap.data?.docs ?? [];
              final openTasks = tasks.where((t) {
                final d = t.data() as Map<String, dynamic>;
                return (d['status'] ?? '') != 'completed';
              }).length;

              return StreamBuilder<QuerySnapshot>(
                stream: FirestoreService.announcementsCol.snapshots(),
                builder: (context, annSnap) {
                  final announcements = annSnap.data?.docs ?? [];

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopGrid(totalEmployees, departments.length, announcements.length, openTasks),
                        const SizedBox(height: 16),
                        _buildOrgInfoCard(),
                        const SizedBox(height: 16),
                        _buildHeadcountGrowthCard(totalEmployees),
                        const SizedBox(height: 16),
                        _buildDepartmentDistributionCard(deptCounts),
                        const SizedBox(height: 16),
                        _buildRecentActivityCard(docs),
                        const SizedBox(height: 32),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTopGrid(int employees, int departments, int announcements, int openTasks) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _buildMetricCard(employees.toString(), 'Total Employees', const Color(0xFFEEF2FF), const Color(0xFF5C5CFF), Icons.people_alt_rounded),
              const SizedBox(height: 16),
              _buildMetricCard(announcements.toString(), 'Announcements', const Color(0xFFECFDF5), const Color(0xFF10B981), Icons.campaign_rounded),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              _buildMetricCard(departments.toString(), 'Departments', const Color(0xFFF3E8FF), const Color(0xFF7C3AED), Icons.business_rounded),
              const SizedBox(height: 16),
              _buildMetricCard(openTasks.toString(), 'Open Tasks', const Color(0xFFFEF2F2), const Color(0xFFEF4444), Icons.task_alt_rounded),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String value, String label, Color bgColor, Color textColor, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: textColor, size: 18),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFD1D5DB), size: 16),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
          ),
        ],
      ),
    );
  }

  Widget _buildOrgInfoCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirestoreService.companyDoc().snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final adminDetails = data['adminDetails'] as Map<String, dynamic>? ?? {};
        final companyName = data['companyName'] ?? data['name'] ?? 'Your Company';
        final industry = data['industry'] ?? adminDetails['industry'] ?? 'Technology';
        final city = data['city'] ?? adminDetails['city'] ?? '';

        return Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Org Health', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))),
                    const SizedBox(height: 8),
                    const Text('87%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                    const SizedBox(height: 4),
                    const Text('Good standing', style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Org Profile', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))),
                    const SizedBox(height: 8),
                    Text(companyName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF5C5CFF)), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('$industry${city.isNotEmpty ? ' · $city' : ''}', style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeadcountGrowthCard(int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('HEADCOUNT GROWTH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280), letterSpacing: 0.5)),
              Icon(Icons.chevron_right, size: 16, color: Color(0xFFD1D5DB)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 45,
                  getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xFFF3F4F6), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        const style = TextStyle(color: Color(0xFF9CA3AF), fontSize: 10);
                        final months = ['Apr', 'May', 'Jun', 'Jul'];
                        final idx = value.toInt();
                        if (idx >= 0 && idx < months.length) {
                          return SideTitleWidget(axisSide: meta.axisSide, child: Text(months[idx], style: style));
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 45,
                      getTitlesWidget: (value, meta) {
                        return Text(value.toInt().toString(), style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10));
                      },
                      reservedSize: 28,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 3,
                minY: (total - 50).toDouble().clamp(0, double.infinity),
                maxY: (total + 30).toDouble(),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      FlSpot(0, (total - 30).toDouble().clamp(0, double.infinity)),
                      FlSpot(1, (total - 20).toDouble().clamp(0, double.infinity)),
                      FlSpot(2, (total - 10).toDouble().clamp(0, double.infinity)),
                      FlSpot(3, total.toDouble()),
                    ],
                    isCurved: false,
                    color: const Color(0xFF5C5CFF),
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 4,
                        color: const Color(0xFF5C5CFF),
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentDistributionCard(Map<String, int> deptCounts) {
    if (deptCounts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('No department data yet', style: TextStyle(color: Color(0xFF9CA3AF))),
          ),
        ),
      );
    }

    final colors = [
      const Color(0xFF5C5CFF),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFFEF4444),
      const Color(0xFF06B6D4),
    ];

    List<PieChartSectionData> sections = [];
    List<Widget> legendItems = [];

    int i = 0;
    deptCounts.forEach((key, value) {
      final color = colors[i % colors.length];
      sections.add(PieChartSectionData(color: color, value: value.toDouble(), title: '', radius: 16));
      legendItems.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(key, style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563))),
                ],
              ),
              Text(value.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
            ],
          ),
        ),
      );
      i++;
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('DEPARTMENT DISTRIBUTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280), letterSpacing: 0.5)),
              Icon(Icons.chevron_right, size: 16, color: Color(0xFFD1D5DB)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: PieChart(PieChartData(sectionsSpace: 2, centerSpaceRadius: 30, sections: sections)),
              ),
              const SizedBox(width: 32),
              Expanded(child: Column(children: legendItems)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard(List<QueryDocumentSnapshot> employees) {
    final recent = employees.take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('RECENT MEMBERS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280), letterSpacing: 0.5)),
              Icon(Icons.chevron_right, size: 16, color: Color(0xFFD1D5DB)),
            ],
          ),
          const SizedBox(height: 20),
          if (recent.isEmpty)
            const Text('No members yet', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12))
          else
            ...recent.asMap().entries.map((entry) {
              final data = entry.value.data() as Map<String, dynamic>;
              final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
              final role = data['role'] ?? data['designation'] ?? 'Employee';
              final dept = data['department'] ?? '';
              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name.isEmpty ? (data['email'] ?? 'Member') : name,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(dept.isEmpty ? role : dept, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                    ],
                  ),
                  if (entry.key < recent.length - 1) const Divider(height: 24, color: Color(0xFFF3F4F6)),
                ],
              );
            }),
        ],
      ),
    );
  }
}
