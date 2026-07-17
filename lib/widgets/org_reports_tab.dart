import 'package:flutter/material.dart';

class OrgReportsTab extends StatelessWidget {
  const OrgReportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4F6F9),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildReportCard(
            title: 'Employee Report',
            subtitle: 'Headcount, joiners, exits',
            icon: Icons.bar_chart_rounded,
            iconBgColor: const Color(0xFFEEF2FF),
            iconColor: const Color(0xFF5C5CFF),
          ),
          _buildReportCard(
            title: 'Department Report',
            subtitle: 'Per-department analytics',
            icon: Icons.bar_chart_rounded,
            iconBgColor: const Color(0xFFF3E8FF).withOpacity(0.5),
            iconColor: const Color(0xFFC084FC),
          ),
          _buildReportCard(
            title: 'Attendance Report',
            subtitle: 'Daily and monthly trends',
            icon: Icons.bar_chart_rounded,
            iconBgColor: const Color(0xFFECFDF5),
            iconColor: const Color(0xFF10B981),
          ),
          _buildReportCard(
            title: 'Leave Report',
            subtitle: 'Leave types and balances',
            icon: Icons.bar_chart_rounded,
            iconBgColor: const Color(0xFFF3E8FF).withOpacity(0.5),
            iconColor: const Color(0xFFC084FC),
          ),
          _buildReportCard(
            title: 'Announcement Report',
            subtitle: 'Reach and engagement',
            icon: Icons.bar_chart_rounded,
            iconBgColor: const Color(0xFFFFFBEB),
            iconColor: const Color(0xFFF59E0B),
          ),
          _buildReportCard(
            title: 'Custom Report',
            subtitle: 'Build your own report',
            icon: Icons.bar_chart_rounded,
            iconBgColor: const Color(0xFFEEF2FF),
            iconColor: const Color(0xFF60A5FA),
          ),
          _buildReportCard(
            title: 'Schedule Report',
            subtitle: 'Shift and schedule data',
            icon: Icons.bar_chart_rounded,
            iconBgColor: const Color(0xFFFEF2F2),
            iconColor: const Color(0xFFEF4444),
          ),
          _buildReportCard(
            title: 'Export Report',
            subtitle: 'Export as CSV / PDF',
            icon: Icons.bar_chart_rounded,
            iconBgColor: const Color(0xFFF3F4F6),
            iconColor: const Color(0xFF6B7280),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 16, color: Color(0xFFD1D5DB)),
        ],
      ),
    );
  }
}
