import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:fl_chart/fl_chart.dart';

class OrgOverviewTab extends StatelessWidget {
  const OrgOverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
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
            final dept = data['department'] ?? 'Unknown';
            departments.add(dept);
            deptCounts[dept] = (deptCounts[dept] ?? 0) + 1;
          }

          int activeShifts = 3; // Simulated
          int openAlerts = 3; // Simulated

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopGrid(totalEmployees, departments.length, activeShifts, openAlerts),
                const SizedBox(height: 16),
                _buildOrgHealthAndProfile(),
                const SizedBox(height: 16),
                _buildHeadcountGrowthCard(),
                const SizedBox(height: 16),
                _buildDepartmentDistributionCard(deptCounts),
                const SizedBox(height: 16),
                _buildRecentActivityCard(),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopGrid(int employees, int departments, int activeShifts, int openAlerts) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _buildMetricCard(employees.toString(), 'Total Employees', const Color(0xFFEEF2FF), const Color(0xFF5C5CFF)),
              const SizedBox(height: 16),
              _buildMetricCard(activeShifts.toString(), 'Active Shifts', const Color(0xFFECFDF5), const Color(0xFF10B981)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              _buildMetricCard(departments.toString(), 'Departments', const Color(0xFFF3E8FF), const Color(0xFF7C3AED)),
              const SizedBox(height: 16),
              _buildMetricCard(openAlerts.toString(), 'Open Alerts', const Color(0xFFFEF2F2), const Color(0xFFEF4444)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String value, String label, Color bgColor, Color textColor) {
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

  Widget _buildOrgHealthAndProfile() {
    return Row(
      children: [
        Expanded(
          child: Container(
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
                const Text('Org Profile', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))),
                const SizedBox(height: 8),
                const Text('Sunrise Tech', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF5C5CFF))),
                const SizedBox(height: 4),
                const Text('Est. 2013 Â· Bangalore', style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeadcountGrowthCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
              const Text('HEADCOUNT GROWTH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280), letterSpacing: 0.5)),
              const Icon(Icons.chevron_right, size: 16, color: Color(0xFFD1D5DB)),
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
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: const Color(0xFFF3F4F6), strokeWidth: 1);
                  },
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
                        Widget text;
                        switch (value.toInt()) {
                          case 0: text = const Text('Apr', style: style); break;
                          case 1: text = const Text('May', style: style); break;
                          case 2: text = const Text('Jun', style: style); break;
                          case 3: text = const Text('Jul', style: style); break;
                          default: text = const Text('', style: style); break;
                        }
                        return SideTitleWidget(axisSide: meta.axisSide, child: text);
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
                minY: 200,
                maxY: 270,
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 215),
                      FlSpot(1, 230),
                      FlSpot(2, 235),
                      FlSpot(3, 247),
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
      deptCounts = {
        'Eng': 54,
        'Design': 22,
        'Mkt': 31,
        'Sales': 45,
        'Others': 95,
      };
    }

    final colors = [
      const Color(0xFF5C5CFF), // Indigo
      const Color(0xFFF59E0B), // Orange
      const Color(0xFF10B981), // Green
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFEF4444), // Red
    ];

    List<PieChartSectionData> sections = [];
    List<Widget> legendItems = [];
    
    int i = 0;
    deptCounts.forEach((key, value) {
      final color = colors[i % colors.length];
      sections.add(
        PieChartSectionData(
          color: color,
          value: value.toDouble(),
          title: '',
          radius: 16,
        ),
      );
      
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
              const Text('DEPARTMENT DISTRIBUTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280), letterSpacing: 0.5)),
              const Icon(Icons.chevron_right, size: 16, color: Color(0xFFD1D5DB)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                    sections: sections,
                  ),
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  children: legendItems,
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
              const Text('RECENT ACTIVITY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280), letterSpacing: 0.5)),
              const Icon(Icons.chevron_right, size: 16, color: Color(0xFFD1D5DB)),
            ],
          ),
          const SizedBox(height: 20),
          _buildActivityItem('Leave approved for Priya Sharma', '2m ago'),
          const Divider(height: 24, color: Color(0xFFF3F4F6)),
          _buildActivityItem('New hire Kavya Reddy onboarded', '1h ago'),
          const Divider(height: 24, color: Color(0xFFF3F4F6)),
          _buildActivityItem('Policy update published', '3h ago'),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String text, String time) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)))),
        const SizedBox(width: 8),
        Text(time, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
      ],
    );
  }
}
