import 'package:flutter/material.dart';
import 'package:attendance_app/screens/report_detail_screen.dart';
import 'package:attendance_app/utils/report_exporter.dart';

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
            context: context,
            title: 'Employee Report',
            subtitle: 'Headcount, joiners, exits',
            icon: Icons.people_alt_rounded,
            iconBgColor: const Color(0xFFEEF2FF),
            iconColor: const Color(0xFF5C5CFF),
            reportType: 'Employee',
          ),
          _buildReportCard(
            context: context,
            title: 'Department Report',
            subtitle: 'Per-department analytics',
            icon: Icons.business_rounded,
            iconBgColor: const Color(0xFFF3E8FF),
            iconColor: const Color(0xFFC084FC),
            reportType: 'Department',
          ),
          _buildReportCard(
            context: context,
            title: 'Attendance Report',
            subtitle: 'Daily and monthly trends',
            icon: Icons.check_circle_outline_rounded,
            iconBgColor: const Color(0xFFECFDF5),
            iconColor: const Color(0xFF10B981),
            reportType: 'Attendance',
          ),
          _buildReportCard(
            context: context,
            title: 'Leave Report',
            subtitle: 'Leave types and balances',
            icon: Icons.beach_access_rounded,
            iconBgColor: const Color(0xFFFFFBEB),
            iconColor: const Color(0xFFF59E0B),
            reportType: 'Leave',
          ),
          _buildReportCard(
            context: context,
            title: 'Announcement Report',
            subtitle: 'Reach and engagement',
            icon: Icons.campaign_rounded,
            iconBgColor: const Color(0xFFEFF6FF),
            iconColor: const Color(0xFF3B82F6),
            reportType: 'Announcement',
          ),
          _buildReportCard(
            context: context,
            title: 'Schedule Report',
            subtitle: 'Shifts and who works which shift',
            icon: Icons.schedule_rounded,
            iconBgColor: const Color(0xFFFEF2F2),
            iconColor: const Color(0xFFEF4444),
            reportType: null,
            exportOnly: 'Schedule',
          ),
          _buildReportCard(
            context: context,
            title: 'Export Report',
            subtitle: 'Download any report as CSV / Excel / PDF',
            icon: Icons.download_rounded,
            iconBgColor: const Color(0xFFF3F4F6),
            iconColor: const Color(0xFF6B7280),
            reportType: null,
            exportOnly: '*',
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildReportCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String? reportType,
    String? exportOnly,
  }) {
    return GestureDetector(
      onTap: reportType != null
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportDetailScreen(reportType: reportType),
                ),
              )
          : exportOnly == null
              ? null
              : () => exportOnly == '*'
                  ? _pickReportAndFormat(context)
                  : _pickFormat(context, exportOnly, '$exportOnly Report'),
      child: Container(
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
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937))),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
            Icon(
              reportType != null
                  ? Icons.chevron_right
                  : Icons.download_rounded,
              size: 16,
              color: const Color(0xFFD1D5DB),
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom sheet: CSV / Excel / PDF for one report, then build + save it from live data.
  void _pickFormat(BuildContext context, String reportType, String title) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Export $title',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
                ),
              ),
              for (final f in const [
                [ReportFormat.csv, 'CSV', Icons.table_chart_outlined],
                [ReportFormat.excel, 'Excel (.xlsx)', Icons.grid_on_rounded],
                [ReportFormat.pdf, 'PDF', Icons.picture_as_pdf_outlined],
              ])
                ListTile(
                  leading: Icon(f[2] as IconData, color: const Color(0xFF5C5CFF)),
                  title: Text(f[1] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () {
                    Navigator.pop(sheet);
                    ReportExporter.run(context, reportType, f[0] as ReportFormat);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Export Report": choose which report first.
  void _pickReportAndFormat(BuildContext context) {
    const reports = [
      ['Employee', 'Employee Report'],
      ['Department', 'Department Report'],
      ['Attendance', 'Attendance Report'],
      ['Leave', 'Leave Report'],
      ['Announcement', 'Announcement Report'],
      ['Schedule', 'Schedule Report'],
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Which report?',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
                ),
              ),
              for (final r in reports)
                ListTile(
                  title: Text(r[1], style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () {
                    Navigator.pop(sheet);
                    _pickFormat(context, r[0], r[1]);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
