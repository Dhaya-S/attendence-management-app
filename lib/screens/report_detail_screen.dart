import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/report_exporter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry Point
// ─────────────────────────────────────────────────────────────────────────────

class ReportDetailScreen extends StatelessWidget {
  final String reportType;
  const ReportDetailScreen({super.key, required this.reportType});

  /// Top-bar Export: pick CSV / Excel / PDF, then build the file from live data.
  void _chooseFormat(BuildContext context) {
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
                  child: Text('Export $reportType Report',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
                ),
              ),
              for (final f in const [
                [ReportFormat.csv, 'CSV', 'Opens in Excel, Google Sheets and more', Icons.table_chart_outlined],
                [ReportFormat.excel, 'Excel (.xlsx)', 'Summary and one sheet per table', Icons.grid_on_rounded],
                [ReportFormat.pdf, 'PDF', 'Print-ready report', Icons.picture_as_pdf_outlined],
              ])
                ListTile(
                  leading: Icon(f[3] as IconData, color: const Color(0xFF5C5CFF)),
                  title: Text(f[1] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(f[2] as String, style: const TextStyle(fontSize: 12)),
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

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (reportType) {
      case 'Employee':
        body = const _EmployeeReportBody();
        break;
      case 'Department':
        body = const _DepartmentReportBody();
        break;
      case 'Attendance':
        body = const _AttendanceReportBody();
        break;
      case 'Leave':
        body = const _LeaveReportBody();
        break;
      case 'Announcement':
        body = const _AnnouncementReportBody();
        break;
      default:
        body = const Center(child: Text('Coming Soon'));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF1F2937)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '$reportType Report',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: TextButton.icon(
              onPressed: () => _chooseFormat(context),
              icon: const Icon(Icons.download_rounded, size: 14, color: Color(0xFF5C5CFF)),
              label: const Text('Export',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5C5CFF))),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFEEF2FF),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: body,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;
  final Color bgColor;

  const _StatCard({
    required this.value,
    required this.label,
    required this.valueColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: valueColor, height: 1.1)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6B7280),
                  letterSpacing: 0.8)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
        ],
      ),
    );
  }
}

class _ExportButtons extends StatefulWidget {
  final String reportType;
  const _ExportButtons({required this.reportType});

  @override
  State<_ExportButtons> createState() => _ExportButtonsState();
}

class _ExportButtonsState extends State<_ExportButtons> {
  bool _busy = false;

  Future<void> _export(ReportFormat format) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ReportExporter.run(context, widget.reportType, format);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final outlined = OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF5C5CFF),
      side: const BorderSide(color: Color(0xFFE5E7EB)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(vertical: 12),
    );
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Export Report',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF5C5CFF))),
              ),
              if (_busy)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Uses the latest live data when you tap a format.',
              style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _export(ReportFormat.csv),
                  style: outlined,
                  child: const Text('CSV', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _export(ReportFormat.excel),
                  style: outlined,
                  child: const Text('Excel', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : () => _export(ReportFormat.pdf),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5C5CFF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('PDF', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bar Chart
// ─────────────────────────────────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Color barColor;

  const _BarChart(
      {required this.values, required this.labels, required this.barColor});

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty || values.every((v) => v == 0)) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No data available',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
        ),
      );
    }

    final maxVal = values.reduce(math.max);
    final ySteps = maxVal > 0 ? [maxVal.ceil(), (maxVal / 2).ceil(), 0] : [0, 0, 0];

    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 28,
            height: 140,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: ySteps
                  .map((v) => Text(v.toString(),
                      style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))))
                  .toList(),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(values.length, (i) {
                      final pct = maxVal > 0 ? values[i] / maxVal : 0.0;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                child: FractionallySizedBox(
                                  heightFactor: pct.clamp(0.02, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: barColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(
                    labels.length,
                    (i) => Expanded(
                      child: Text(labels[i],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF9CA3AF))),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Donut Chart
// ─────────────────────────────────────────────────────────────────────────────

class _DonutChart extends StatelessWidget {
  final List<double> values;
  final List<Color> colors;
  final List<String> labels;

  const _DonutChart(
      {required this.values, required this.colors, required this.labels});

  @override
  Widget build(BuildContext context) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total == 0) {
      return const Center(
          child: Text('No data',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)));
    }

    return Row(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: CustomPaint(
              painter: _DonutPainter(values: values, colors: colors)),
        ),
        const SizedBox(width: 24),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(labels.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: colors[i], shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text('${labels[i]}  ',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF4B5563))),
                  Text('${values[i].toInt()}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937))),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  _DonutPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final strokeW = radius * 0.38;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeW / 2);
    double startAngle = -math.pi / 2;
    for (int i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * 2 * math.pi;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

List<String> _last6MonthLabels() {
  final now = DateTime.now();
  return List.generate(6, (i) {
    final m = DateTime(now.year, now.month - 5 + i);
    return DateFormat('MMM').format(m);
  });
}

DateTime _monthStart(int offset) {
  final now = DateTime.now();
  final m = DateTime(now.year, now.month - 5 + offset);
  return DateTime(m.year, m.month, 1);
}

DateTime _monthEnd(int offset) {
  final now = DateTime.now();
  final m = DateTime(now.year, now.month - 5 + offset);
  return DateTime(m.year, m.month + 1, 0, 23, 59, 59);
}

Timestamp? _parseTs(dynamic v) {
  if (v is Timestamp) return v;
  if (v is String) {
    final dt = DateTime.tryParse(v);
    if (dt != null) return Timestamp.fromDate(dt);
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Employee Report
// ─────────────────────────────────────────────────────────────────────────────

class _EmployeeReportBody extends StatelessWidget {
  const _EmployeeReportBody();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.employeesCol.snapshots(),
      builder: (context, empSnap) {
        final allEmpDocs = (empSnap.data?.docs ?? [])
            .where((d) => FirestoreService.isDocInCurrentCompany(d))
            .toList();
        final empDocs = allEmpDocs
            .where((d) => FirestoreService.isActiveUserDoc(d.data() as Map<String, dynamic>))
            .toList();
        final now = DateTime.now();

        final monthLabels = _last6MonthLabels();
        final monthlyHeadcount = List.generate(6, (i) {
          final end = _monthEnd(i);
          return empDocs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final ts = _parseTs(data['createdAt'] ?? data['joinedAt'] ?? data['joiningDate']);
            if (ts == null) return true;
            return ts.toDate().isBefore(end);
          }).length.toDouble();
        });

        final totalEmp = empDocs.length;
        final thisMonthStart = DateTime(now.year, now.month, 1);
        int newJoiners = empDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final ts = _parseTs(data['joinDate'] ?? data['joiningDate'] ?? data['createdAt'] ?? data['joinedAt']);
          if (ts == null) return false;
          return ts.toDate().isAfter(thisMonthStart);
        }).length;

        final Map<String, int> deptCount = {};
        for (final d in empDocs) {
          final data = d.data() as Map<String, dynamic>;
          final dept = (data['dept'] ?? data['department'] ?? 'Unknown').toString();
          deptCount[dept] = (deptCount[dept] ?? 0) + 1;
        }

        final period = 'Q${((now.month - 1) ~/ 3) + 1} ${now.year}';

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              _StatCard(
                  value: '$totalEmp',
                  label: 'Total Employees',
                  valueColor: const Color(0xFF5C5CFF),
                  bgColor: const Color(0xFFEEF2FF)),
              const SizedBox(width: 10),
              _StatCard(
                  value: '$newJoiners',
                  label: 'Joiners This Month',
                  valueColor: const Color(0xFF10B981),
                  bgColor: const Color(0xFFECFDF5)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _StatCard(
                  value: '${deptCount.length}',
                  label: 'Departments',
                  valueColor: const Color(0xFFF59E0B),
                  bgColor: const Color(0xFFFFFBEB)),
              const SizedBox(width: 10),
              _StatCard(
                  value: '${allEmpDocs.length - empDocs.length}',
                  label: 'Inactive Employees',
                  valueColor: const Color(0xFFEF4444),
                  bgColor: const Color(0xFFFEF2F2)),
            ]),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Trend',
              child: _BarChart(
                  values: monthlyHeadcount,
                  labels: monthLabels,
                  barColor: const Color(0xFF5C5CFF)),
            ),
            _SectionCard(
              title: 'Summary',
              child: Column(children: [
                _SummaryRow(label: 'Period', value: period),
                _SummaryRow(
                    label: 'Generated',
                    value: DateFormat('MMM d, yyyy').format(now)),
                const _SummaryRow(label: 'Scope', value: 'All Departments'),
                const _SummaryRow(label: 'Format', value: 'Summary + Detail'),
              ]),
            ),
            const _ExportButtons(reportType: 'Employee'),
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Department Report
// ─────────────────────────────────────────────────────────────────────────────

class _DepartmentReportBody extends StatelessWidget {
  const _DepartmentReportBody();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.employeesCol.snapshots(),
      builder: (context, empSnap) {
        final allEmpDocs = (empSnap.data?.docs ?? [])
            .where((d) => FirestoreService.isDocInCurrentCompany(d))
            .toList();
        final empDocs = allEmpDocs
            .where((d) => FirestoreService.isActiveUserDoc(d.data() as Map<String, dynamic>))
            .toList();
        final now = DateTime.now();

        final Map<String, int> deptCount = {};
        for (final d in empDocs) {
          final data = d.data() as Map<String, dynamic>;
          final dept = (data['dept'] ?? data['department'] ?? 'Unknown').toString();
          deptCount[dept] = (deptCount[dept] ?? 0) + 1;
        }

        final depts = deptCount.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final totalEmp = empDocs.length.toDouble();
        final monthLabels = _last6MonthLabels();
        final monthlyVals = List.generate(6, (i) => totalEmp);
        final period = 'Q${((now.month - 1) ~/ 3) + 1} ${now.year}';

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              _StatCard(
                  value: '${depts.length}',
                  label: 'Total Departments',
                  valueColor: const Color(0xFF5C5CFF),
                  bgColor: const Color(0xFFEEF2FF)),
              const SizedBox(width: 10),
              _StatCard(
                  value: '${empDocs.length}',
                  label: 'Total Employees',
                  valueColor: const Color(0xFFA855F7),
                  bgColor: const Color(0xFFFAF5FF)),
            ]),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Trend',
              child: _BarChart(
                  values: monthlyVals,
                  labels: monthLabels,
                  barColor: const Color(0xFF5C5CFF)),
            ),
            if (depts.isNotEmpty)
              _SectionCard(
                title: 'Department Breakdown',
                child: Column(
                  children: depts.take(8).map((e) {
                    final pct = totalEmp > 0
                        ? (e.value / totalEmp * 100).toStringAsFixed(1)
                        : '0';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(e.key,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1F2937))),
                              Text('${e.value} emp · $pct%',
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFF6B7280))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: totalEmp > 0 ? e.value / totalEmp : 0,
                              backgroundColor: const Color(0xFFE5E7EB),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF5C5CFF)),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            _SectionCard(
              title: 'Report Summary',
              child: Column(children: [
                _SummaryRow(label: 'Period', value: period),
                _SummaryRow(
                    label: 'Generated',
                    value: DateFormat('MMM d, yyyy').format(now)),
                const _SummaryRow(label: 'Scope', value: 'All Departments'),
                const _SummaryRow(label: 'Format', value: 'Summary + Detail'),
              ]),
            ),
            const _ExportButtons(reportType: 'Department'),
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Attendance Report
// ─────────────────────────────────────────────────────────────────────────────

class _AttendanceReportBody extends StatelessWidget {
  const _AttendanceReportBody();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.allAttendanceRecordsCol.snapshots(),
      builder: (context, attSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirestoreService.employeesCol.snapshots(),
          builder: (context, empSnap) {
            final attDocs = attSnap.data?.docs.where((d) => FirestoreService.isDocInCurrentCompany(d)).toList() ?? [];
            final empDocs = empSnap.data?.docs
                    .where((d) =>
                        FirestoreService.isDocInCurrentCompany(d) &&
                        FirestoreService.isActiveUserDoc(d.data() as Map<String, dynamic>))
                    .toList() ??
                [];
            final now = DateTime.now();
            final totalEmp = empDocs.length;

            final thisMonthStart = DateTime(now.year, now.month, 1);
            final thisMonthEnd = DateTime(now.year, now.month + 1, 0);

            int presentCount = 0, lateCount = 0, wfhCount = 0;

            for (final doc in attDocs) {
              final data = doc.data() as Map<String, dynamic>;
              final ts = _parseTs(data['checkIn'] ??
                  data['lastCheckIn'] ??
                  data['checkInTime']);
              if (ts == null) continue;
              final date = ts.toDate();
              if (date.isBefore(thisMonthStart) ||
                  date.isAfter(thisMonthEnd)) continue;

              final status =
                  (data['status'] ?? data['attendanceStatus'] ?? '')
                      .toString()
                      .toLowerCase();
              final mode =
                  (data['workMode'] ?? '').toString().toLowerCase();

              if (mode == 'wfh' || mode == 'work_from_home') {
                wfhCount++;
              } else if (status.contains('late')) {
                lateCount++;
              } else {
                presentCount++;
              }
            }

            final totalRecords = presentCount + lateCount + wfhCount;
            final avgAttPct = totalEmp > 0 && totalRecords > 0
                ? '${((totalRecords / (totalEmp * 22)) * 100).clamp(0, 100).toStringAsFixed(0)}%'
                : '—';
            final lateRate = totalRecords > 0
                ? '${((lateCount / totalRecords) * 100).toStringAsFixed(1)}%'
                : '0%';

            final monthLabels = _last6MonthLabels();
            final monthlyPresent = List.generate(6, (i) {
              final start = _monthStart(i);
              final end = _monthEnd(i);
              return attDocs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final ts = _parseTs(data['checkIn'] ??
                    data['lastCheckIn'] ??
                    data['checkInTime']);
                if (ts == null) return false;
                final dt = ts.toDate();
                return !dt.isBefore(start) && !dt.isAfter(end);
              }).length.toDouble();
            });

            final period =
                'Q${((now.month - 1) ~/ 3) + 1} ${now.year}';

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  _StatCard(
                      value: avgAttPct,
                      label: 'Avg Attendance',
                      valueColor: const Color(0xFF10B981),
                      bgColor: const Color(0xFFECFDF5)),
                  const SizedBox(width: 10),
                  _StatCard(
                      value: lateRate,
                      label: 'Avg Late Rate',
                      valueColor: const Color(0xFFF59E0B),
                      bgColor: const Color(0xFFFFFBEB)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _StatCard(
                      value: '0',
                      label: 'Absent Days',
                      valueColor: const Color(0xFFEF4444),
                      bgColor: const Color(0xFFFEF2F2)),
                  const SizedBox(width: 10),
                  _StatCard(
                      value: '$wfhCount',
                      label: 'WFH Days',
                      valueColor: const Color(0xFF3B82F6),
                      bgColor: const Color(0xFFEFF6FF)),
                ]),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Monthly Attendance Trend',
                  child: _BarChart(
                      values: monthlyPresent,
                      labels: monthLabels,
                      barColor: const Color(0xFFEF4444)),
                ),
                _SectionCard(
                  title:
                      'Status Distribution (${DateFormat('MMM').format(now)})',
                  child: _DonutChart(
                    values: [
                      presentCount.toDouble(),
                      lateCount.toDouble(),
                      wfhCount.toDouble(),
                    ],
                    colors: const [
                      Color(0xFF10B981),
                      Color(0xFFF59E0B),
                      Color(0xFF3B82F6)
                    ],
                    labels: const ['Present', 'Late', 'WFH'],
                  ),
                ),
                _SectionCard(
                  title: 'Report Summary',
                  child: Column(children: [
                    _SummaryRow(label: 'Period', value: period),
                    _SummaryRow(
                        label: 'Generated',
                        value: DateFormat('MMM d, yyyy').format(now)),
                    _SummaryRow(
                        label: 'Employees Covered', value: '$totalEmp'),
                    _SummaryRow(
                        label: 'Working Days', value: '${thisMonthEnd.day}'),
                  ]),
                ),
                const _ExportButtons(reportType: 'Attendance'),
                const SizedBox(height: 40),
              ],
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Leave Report
// ─────────────────────────────────────────────────────────────────────────────

class _LeaveReportBody extends StatelessWidget {
  const _LeaveReportBody();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.allLeaveRequestsQuery.snapshots(),
      builder: (context, leaveSnap) {
        final leaveDocs = leaveSnap.data?.docs ?? [];
        final now = DateTime.now();

        int totalDays = 0, pendingCount = 0, approvedCount = 0, rejectedCount = 0;
        final Map<String, int> typeCount = {
          'Annual': 0,
          'Casual': 0,
          'Sick': 0,
          'LOP': 0
        };
        final Set<String> empWithLeave = {};
        final monthlyLeave = List.generate(6, (_) => 0.0);

        for (final doc in leaveDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString().toLowerCase();
          final days =
              ((data['durationInDays'] ?? data['days'] ?? 1) as num).toInt();
          final leaveType =
              (data['leaveType'] ?? data['type'] ?? '').toString().toLowerCase();
          final fromTs = _parseTs(data['fromDate'] ?? data['from']);
          final pathEmail = doc.reference.parent.parent?.id ?? '';
          final email = (data['applicantEmail'] ??
                  data['employeeEmail'] ??
                  data['email'] ??
                  (pathEmail.contains('@') ? pathEmail : null) ??
                  '')
              .toString();

          if (status == 'pending') pendingCount++;
          if (status == 'rejected') rejectedCount++;
          if (status == 'approved') {
            approvedCount++;
            totalDays += days;
            if (email.isNotEmpty) empWithLeave.add(email);

            if (leaveType.contains('annual')) {
              typeCount['Annual'] = (typeCount['Annual'] ?? 0) + days;
            } else if (leaveType.contains('casual')) {
              typeCount['Casual'] = (typeCount['Casual'] ?? 0) + days;
            } else if (leaveType.contains('sick')) {
              typeCount['Sick'] = (typeCount['Sick'] ?? 0) + days;
            } else {
              typeCount['LOP'] = (typeCount['LOP'] ?? 0) + days;
            }

            if (fromTs != null) {
              for (int i = 0; i < 6; i++) {
                final dt = fromTs.toDate();
                if (!dt.isBefore(_monthStart(i)) && !dt.isAfter(_monthEnd(i))) {
                  monthlyLeave[i] += days;
                }
              }
            }
          }
        }

        final avgPerEmp = empWithLeave.isNotEmpty
            ? (totalDays / empWithLeave.length).toStringAsFixed(1)
            : '0';
        final monthLabels = _last6MonthLabels();
        final period = 'Q${((now.month - 1) ~/ 3) + 1} ${now.year}';

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              _StatCard(
                  value: '$totalDays',
                  label: 'Total Leave Days',
                  valueColor: const Color(0xFF5C5CFF),
                  bgColor: const Color(0xFFEEF2FF)),
              const SizedBox(width: 10),
              _StatCard(
                  value: '$pendingCount',
                  label: 'Pending Approval',
                  valueColor: const Color(0xFFF59E0B),
                  bgColor: const Color(0xFFFFFBEB)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _StatCard(
                  value: '$approvedCount',
                  label: 'Approved',
                  valueColor: const Color(0xFF10B981),
                  bgColor: const Color(0xFFECFDF5)),
              const SizedBox(width: 10),
              _StatCard(
                  value: '$rejectedCount',
                  label: 'Rejected',
                  valueColor: const Color(0xFFEF4444),
                  bgColor: const Color(0xFFFEF2F2)),
            ]),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Leave Trends by Type',
              child: _BarChart(
                  values: monthlyLeave,
                  labels: monthLabels,
                  barColor: const Color(0xFFEF4444)),
            ),
            _SectionCard(
              title: 'Leave Type Distribution',
              child: _DonutChart(
                values:
                    typeCount.values.map((v) => v.toDouble()).toList(),
                colors: const [
                  Color(0xFF5C5CFF),
                  Color(0xFF8B5CF6),
                  Color(0xFFEF4444),
                  Color(0xFF9CA3AF)
                ],
                labels: typeCount.keys.toList(),
              ),
            ),
            _SectionCard(
              title: 'Report Summary',
              child: Column(children: [
                _SummaryRow(label: 'Period', value: period),
                _SummaryRow(
                    label: 'Generated',
                    value: DateFormat('MMM d, yyyy').format(now)),
                _SummaryRow(
                    label: 'Employees with Leave',
                    value: '${empWithLeave.length}'),
                _SummaryRow(
                    label: 'Avg per Employee', value: '$avgPerEmp days'),
              ]),
            ),
            const _ExportButtons(reportType: 'Leave'),
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Announcement Report
// ─────────────────────────────────────────────────────────────────────────────

class _AnnouncementReportBody extends StatelessWidget {
  const _AnnouncementReportBody();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.announcementsCol.snapshots(),
      builder: (context, annSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirestoreService.employeesCol.snapshots(),
          builder: (context, empSnap) {
            final annDocs = annSnap.data?.docs ?? [];
            final totalEmp = empSnap.data?.docs.length ?? 0;
            final now = DateTime.now();

            int totalSent = annDocs.length;
            int thisMonth = 0, urgent = 0;
            double totalReadRate = 0;
            int rateCount = 0;
            final thisMonthStart = DateTime(now.year, now.month, 1);
            final monthlyCounts = List.generate(6, (_) => 0.0);

            for (final doc in annDocs) {
              final data = doc.data() as Map<String, dynamic>;
              final ts = _parseTs(
                  data['createdAt'] ?? data['publishedAt'] ?? data['date']);
              final isUrgent =
                  (data['priority'] ?? data['type'] ?? '')
                          .toString()
                          .toLowerCase() ==
                      'urgent' ||
                  (data['urgent'] == true);
              if (isUrgent) urgent++;

              final readCount = data['readCount'] ?? data['readBy'] ?? 0;
              final reads = readCount is List
                  ? readCount.length
                  : (readCount as num? ?? 0).toInt();
              final targets =
                  (data['targetCount'] ?? data['totalTarget'] ?? totalEmp)
                      as num? ??
                  totalEmp;
              if (targets > 0) {
                totalReadRate += reads / targets;
                rateCount++;
              }

              if (ts != null) {
                final dt = ts.toDate();
                if (!dt.isBefore(thisMonthStart)) thisMonth++;
                for (int i = 0; i < 6; i++) {
                  if (!dt.isBefore(_monthStart(i)) &&
                      !dt.isAfter(_monthEnd(i))) {
                    monthlyCounts[i]++;
                  }
                }
              }
            }

            final avgReadRate = rateCount > 0
                ? '${(totalReadRate / rateCount * 100).toStringAsFixed(0)}%'
                : '—';

            // Recent 4 sorted by date
            final sorted = [...annDocs]..sort((a, b) {
                final aTs = _parseTs((a.data() as Map)['createdAt'] ??
                    (a.data() as Map)['publishedAt']);
                final bTs = _parseTs((b.data() as Map)['createdAt'] ??
                    (b.data() as Map)['publishedAt']);
                if (aTs == null) return 1;
                if (bTs == null) return -1;
                return bTs.compareTo(aTs);
              });

            final recent = sorted.take(4).map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final title =
                  (data['title'] ?? data['subject'] ?? 'Announcement')
                      .toString();
              final ts = _parseTs(
                  data['createdAt'] ?? data['publishedAt'] ?? data['date']);
              final targets =
                  ((data['targetCount'] ?? data['totalTarget'] ?? totalEmp)
                          as num? ??
                      totalEmp)
                      .toInt();
              final readCount = data['readCount'] ?? data['readBy'] ?? 0;
              final reads = readCount is List
                  ? readCount.length
                  : (readCount as num? ?? 0).toInt();
              final rate = targets > 0
                  ? '${(reads / targets * 100).toStringAsFixed(1)}%'
                  : '—';
              return {'title': title, 'ts': ts, 'rate': rate, 'targets': targets};
            }).toList();

            final monthLabels = _last6MonthLabels();
            final period =
                'Q${((now.month - 1) ~/ 3) + 1} ${now.year}';

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  _StatCard(
                      value: '$totalSent',
                      label: 'Total Sent',
                      valueColor: const Color(0xFF5C5CFF),
                      bgColor: const Color(0xFFEEF2FF)),
                  const SizedBox(width: 10),
                  _StatCard(
                      value: avgReadRate,
                      label: 'Avg Read Rate',
                      valueColor: const Color(0xFF10B981),
                      bgColor: const Color(0xFFECFDF5)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _StatCard(
                      value: '$thisMonth',
                      label: 'This Month',
                      valueColor: const Color(0xFFF59E0B),
                      bgColor: const Color(0xFFFFFBEB)),
                  const SizedBox(width: 10),
                  _StatCard(
                      value: '$urgent',
                      label: 'Urgent',
                      valueColor: const Color(0xFFEF4444),
                      bgColor: const Color(0xFFFEF2F2)),
                ]),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Announcements Sent vs Read',
                  child: _BarChart(
                      values: monthlyCounts,
                      labels: monthLabels,
                      barColor: const Color(0xFF10B981)),
                ),
                if (recent.isNotEmpty)
                  _SectionCard(
                    title: 'Recent Announcements',
                    child: Column(
                      children: recent.map((a) {
                        final ts = a['ts'] as Timestamp?;
                        final dateStr = ts != null
                            ? DateFormat('MMM d').format(ts.toDate())
                            : '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(a['title'] as String,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1F2937))),
                                    const SizedBox(height: 2),
                                    Text('$dateStr · ${a['targets']} reached',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF9CA3AF))),
                                  ],
                                ),
                              ),
                              Text(a['rate'] as String,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF10B981))),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                _SectionCard(
                  title: 'Report Summary',
                  child: Column(children: [
                    _SummaryRow(label: 'Period', value: period),
                    _SummaryRow(
                        label: 'Generated',
                        value: DateFormat('MMM d, yyyy').format(now)),
                    _SummaryRow(label: 'Avg Reach', value: avgReadRate),
                    const _SummaryRow(label: 'Channels', value: 'App + Email'),
                  ]),
                ),
                const _ExportButtons(reportType: 'Announcement'),
                const SizedBox(height: 40),
              ],
            );
          },
        );
      },
    );
  }
}
