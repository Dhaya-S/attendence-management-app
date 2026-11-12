import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:attendance_app/screens/org_employees_screen.dart';
import 'package:attendance_app/screens/org_departments_screen.dart';
import 'package:attendance_app/features/settings/screens/manager/company_settings_screen.dart';
import 'package:attendance_app/features/attendance/screens/manager/employee_workspace_screen.dart';
import 'package:attendance_app/widgets/announcements_tab_view.dart';
import 'package:attendance_app/widgets/team_tasks_view.dart';

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
            Icon(Icons.lock_outline_rounded,
                size: 48, color: Color(0xFF9CA3AF)),
            SizedBox(height: 16),
            Text('Permission Denied',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937))),
            SizedBox(height: 8),
            Text('You do not have permission to access Organization data.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
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

          final docs = (snapshot.data?.docs ?? [])
              .where((d) =>
                  FirestoreService.isDocInCurrentCompany(d) &&
                  FirestoreService.isActiveUserDoc(d.data() as Map<String, dynamic>))
              .toList();

          int totalEmployees = docs.length;
          Set<String> departments = {};
          Map<String, int> deptCounts = {};

          for (var doc in docs) {
            final dept = FirestoreService.deptOf(doc.data() as Map<String, dynamic>);
            departments.add(dept);
            deptCounts[dept] = (deptCounts[dept] ?? 0) + 1;
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirestoreService.tasksCol.snapshots(),
            builder: (context, tasksSnap) {
              final tasks = (tasksSnap.data?.docs ?? [])
                  .where((t) => FirestoreService.isDocInCurrentCompany(t))
                  .toList();
              int openTasks = 0, doneTasks = 0;
              for (final t in tasks) {
                final b = FirestoreService.taskBucket(t.data() as Map<String, dynamic>);
                if (b == 'Archived') continue;
                if (b == 'Completed') {
                  doneTasks++;
                } else {
                  openTasks++;
                }
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirestoreService.announcementsCol.snapshots(),
                builder: (context, annSnap) => StreamBuilder<QuerySnapshot>(
                stream: FirestoreService.allAttendanceRecordsCol.snapshots(),
                builder: (context, attSnap) {
                  final announcements = (annSnap.data?.docs ?? [])
                      .where((a) => FirestoreService.isDocInCurrentCompany(a))
                      .toList();
                  final health = _computeHealth(docs, attSnap.data?.docs ?? const [], openTasks, doneTasks);
                  final growth = _headcountByMonth(docs);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopGrid(
                            context,
                            totalEmployees,
                            departments.length,
                            announcements.length,
                            openTasks),
                        const SizedBox(height: 16),
                        _buildOrgInfoCard(context, health),
                        const SizedBox(height: 16),
                        _buildHeadcountGrowthCard(context, growth),
                        const SizedBox(height: 16),
                        _buildDepartmentDistributionCard(context, deptCounts),
                        const SizedBox(height: 16),
                        _buildRecentActivityCard(context, docs),
                        const SizedBox(height: 32),
                      ],
                    ),
                  );
                },
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── Real numbers (no placeholders) ────────────────────────────────────────

  /// Org health from live data: today's attendance, on-time arrivals and task completion.
  /// Entries are null when there is nothing to measure yet.
  static Map<String, double?> _computeHealth(List<QueryDocumentSnapshot> people,
      List<QueryDocumentSnapshot> attendance, int openTasks, int doneTasks) {
    final emails = people.map((p) => p.id.toLowerCase()).toSet();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final checkedIn = <String>{};
    int late = 0;
    for (final doc in attendance) {
      if (!FirestoreService.isDocInCurrentCompany(doc)) continue;
      final d = doc.data() as Map<String, dynamic>;
      final isToday = doc.id == today ||
          doc.id.endsWith('_$today') ||
          d['recordDate'] == today ||
          d['date'] == today ||
          (FirestoreService.parseAnyDate(d['date']) != null &&
              DateFormat('yyyy-MM-dd').format(FirestoreService.parseAnyDate(d['date'])!) == today);
      if (!isToday) continue;
      final who = FirestoreService.requesterEmail(d).isNotEmpty
          ? FirestoreService.requesterEmail(d)
          : doc.id.split('_').first.toLowerCase();
      if (!emails.contains(who)) continue;
      final hasIn = d['checkIn'] != null || d['checkInTime'] != null || d['lastCheckIn'] != null;
      if (!hasIn) continue;
      if (checkedIn.add(who)) {
        final st = (d['status'] ?? d['attendanceStatus'] ?? '').toString().toLowerCase();
        if (st.contains('late') || d['isLate'] == true) late++;
      }
    }
    final attendanceRate = emails.isEmpty ? null : checkedIn.length / emails.length;
    final onTime = checkedIn.isEmpty ? null : (checkedIn.length - late) / checkedIn.length;
    final totalTasks = openTasks + doneTasks;
    final taskRate = totalTasks == 0 ? null : doneTasks / totalTasks;
    final parts = [attendanceRate, onTime, taskRate].whereType<double>().toList();
    final overall = parts.isEmpty ? null : parts.reduce((a, b) => a + b) / parts.length;
    return {'overall': overall, 'attendance': attendanceRate, 'ontime': onTime, 'tasks': taskRate};
  }

  /// Headcount at the end of each of the last 4 months, from real joining dates.
  static List<int> _headcountByMonth(List<QueryDocumentSnapshot> people) {
    final now = DateTime.now();
    final out = <int>[];
    for (var back = 3; back >= 0; back--) {
      final end = DateTime(now.year, now.month - back + 1, 0, 23, 59, 59);
      var n = 0;
      for (final p in people) {
        final m = p.data() as Map<String, dynamic>;
        final j = FirestoreService.parseAnyDate(m['joinDate'] ?? m['joiningDate'] ?? m['createdAt']);
        if (j == null || !j.isAfter(end)) n++;
      }
      out.add(n);
    }
    return out;
  }

  static String _pct(double? v) => v == null ? '—' : '${(v * 100).round()}%';

  Widget _buildTopGrid(BuildContext context, int employees, int departments,
      int announcements, int openTasks) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _buildMetricCard(
                value: employees.toString(),
                label: 'Total Employees',
                bgColor: const Color(0xFFEEF2FF),
                textColor: const Color(0xFF5C5CFF),
                icon: Icons.people_alt_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const OrgEmployeesScreen()),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildMetricCard(
                value: announcements.toString(),
                label: 'Announcements',
                bgColor: const Color(0xFFECFDF5),
                textColor: const Color(0xFF10B981),
                icon: Icons.campaign_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        backgroundColor: const Color(0xFFF8FAFC),
                        appBar: AppBar(
                          backgroundColor: Colors.white,
                          elevation: 0,
                          scrolledUnderElevation: 0,
                          leading: IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Color(0xFF1F2937), size: 18),
                            onPressed: () => Navigator.maybePop(context),
                          ),
                          title: const Text(
                            'Announcements',
                            style: TextStyle(
                              color: Color(0xFF1F2937),
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        body: AnnouncementsTabView(
                          isAdmin: AppSession()
                              .hasPermission('announcement_creation'),
                          isTeamAnnouncements: false,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              _buildMetricCard(
                value: departments.toString(),
                label: 'Departments',
                bgColor: const Color(0xFFF3E8FF),
                textColor: const Color(0xFF7C3AED),
                icon: Icons.business_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const OrgDepartmentsScreen()),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildMetricCard(
                value: openTasks.toString(),
                label: 'Open Tasks',
                bgColor: const Color(0xFFFEF2F2),
                textColor: const Color(0xFFEF4444),
                icon: Icons.task_alt_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        backgroundColor: const Color(0xFFF8FAFC),
                        appBar: AppBar(
                          backgroundColor: Colors.white,
                          elevation: 0,
                          scrolledUnderElevation: 0,
                          leading: IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Color(0xFF1F2937), size: 18),
                            onPressed: () => Navigator.maybePop(context),
                          ),
                          title: const Text(
                            'Open Tasks',
                            style: TextStyle(
                              color: Color(0xFF1F2937),
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        body: const TeamTasksView(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String value,
    required String label,
    required Color bgColor,
    required Color textColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: textColor, size: 18),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFF94A3B8), size: 18),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  value,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: textColor),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrgInfoCard(BuildContext context, Map<String, double?> health) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirestoreService.companyDoc().snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final adminDetails =
            data['adminDetails'] as Map<String, dynamic>? ?? {};
        final companyName =
            data['companyName'] ?? data['name'] ?? 'Your Company';
        final industry =
            data['industry'] ?? adminDetails['industry'] ?? 'Technology';
        final city = data['city'] ?? adminDetails['city'] ?? '';

        return Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x05000000),
                        blurRadius: 10,
                        offset: Offset(0, 4))
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _showOrgHealthDialog(context, health),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Org Health',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF6B7280))),
                              Icon(Icons.chevron_right_rounded,
                                  color: Color(0xFF94A3B8), size: 16),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(_pct(health['overall']),
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: (health['overall'] ?? 0) >= 0.8
                                      ? const Color(0xFF10B981)
                                      : (health['overall'] ?? 0) >= 0.5
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFFEF4444))),
                          const SizedBox(height: 4),
                          Text(health['overall'] == null ? 'Not enough data yet' : 'Live from today',
                              style: const TextStyle(
                                  fontSize: 10, color: Color(0xFF9CA3AF))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x05000000),
                        blurRadius: 10,
                        offset: Offset(0, 4))
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CompanySettingsScreen(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Org Profile',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF6B7280))),
                              Icon(Icons.chevron_right_rounded,
                                  color: Color(0xFF94A3B8), size: 16),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(companyName,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF5C5CFF)),
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('$industry${city.isNotEmpty ? ' · $city' : ''}',
                              style: const TextStyle(
                                  fontSize: 10, color: Color(0xFF9CA3AF)),
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showOrgHealthDialog(BuildContext context, Map<String, double?> health) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.health_and_safety_rounded,
                      color: Color(0xFF10B981), size: 28),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Organization Health',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F2937)),
                    ),
                    Text(
                      'Calculated live from attendance and tasks',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildHealthItem("Today's Attendance", _pct(health['attendance']),
                health['attendance'] ?? 0, const Color(0xFF5C5CFF)),
            _buildHealthItem('On-Time Arrivals Today', _pct(health['ontime']),
                health['ontime'] ?? 0, const Color(0xFF10B981)),
            _buildHealthItem('Task Completion Rate', _pct(health['tasks']),
                health['tasks'] ?? 0, const Color(0xFFF59E0B)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C5CFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Close',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthItem(
      String title, String percent, double progress, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              Text(percent,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeadcountGrowthCard(BuildContext context, List<int> series) {
    final total = series.last;
    final double maxHeadcount = (total < 10) ? 10.0 : (total * 1.25).ceilToDouble();
    final double intervalVal = (maxHeadcount / 2).ceilToDouble();
    final double s0 = series[0].toDouble();
    final double s1 = series[1].toDouble();
    final double s2 = series[2].toDouble();
    final double s3 = series[3].toDouble();

    final now = DateTime.now();
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final labels = [
      monthNames[(now.month - 4 + 12) % 12],
      monthNames[(now.month - 3 + 12) % 12],
      monthNames[(now.month - 2 + 12) % 12],
      monthNames[(now.month - 1 + 12) % 12],
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OrgEmployeesScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('HEADCOUNT GROWTH',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B7280),
                            letterSpacing: 0.5)),
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: Color(0xFF94A3B8)),
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
                        horizontalInterval: intervalVal,
                        getDrawingHorizontalLine: (value) => FlLine(
                            color: const Color(0xFFF3F4F6), strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              const style = TextStyle(
                                  color: Color(0xFF9CA3AF), fontSize: 10);
                              final idx = value.toInt();
                              if (idx >= 0 && idx < labels.length) {
                                return SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    child: Text(labels[idx], style: style));
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: intervalVal,
                            getTitlesWidget: (value, meta) {
                              return Text(value.toInt().toString(),
                                  style: const TextStyle(
                                      color: Color(0xFF9CA3AF), fontSize: 10));
                            },
                            reservedSize: 28,
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: 3,
                      minY: 0,
                      maxY: maxHeadcount,
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            FlSpot(0, s0),
                            FlSpot(1, s1),
                            FlSpot(2, s2),
                            FlSpot(3, s3),
                          ],
                          isCurved: false,
                          color: const Color(0xFF5C5CFF),
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) =>
                                FlDotCirclePainter(
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
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentDistributionCard(
      BuildContext context, Map<String, int> deptCounts) {
    if (deptCounts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))
          ],
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('No department data yet',
                style: TextStyle(color: Color(0xFF9CA3AF))),
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
      sections.add(PieChartSectionData(
          color: color, value: value.toDouble(), title: '', radius: 16));
      legendItems.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(key,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF4B5563))),
                ],
              ),
              Text(value.toString(),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937))),
            ],
          ),
        ),
      );
      i++;
    });

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OrgDepartmentsScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('DEPARTMENT DISTRIBUTION',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B7280),
                            letterSpacing: 0.5)),
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: Color(0xFF94A3B8)),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: PieChart(PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 30,
                          sections: sections)),
                    ),
                    const SizedBox(width: 32),
                    Expanded(child: Column(children: legendItems)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard(
      BuildContext context, List<QueryDocumentSnapshot> employees) {
    final sorted = [...employees]..sort((a, b) {
        DateTime when(QueryDocumentSnapshot q) {
          final m = q.data() as Map<String, dynamic>;
          return FirestoreService.parseAnyDate(m['joinDate'] ?? m['joiningDate'] ?? m['createdAt']) ??
              DateTime(2000);
        }

        return when(b).compareTo(when(a));
      });
    final recent = sorted.take(4).toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OrgEmployeesScreen()),
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('RECENT MEMBERS',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B7280),
                          letterSpacing: 0.5)),
                  Row(
                    children: [
                      Text('View All',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF5C5CFF),
                              fontWeight: FontWeight.w600)),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded,
                          size: 16, color: Color(0xFF5C5CFF)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (recent.isEmpty)
              const Text('No members yet',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12))
            else
              ...recent.asMap().entries.map((entry) {
                final data = entry.value.data() as Map<String, dynamic>;
                String name =
                    (data['name'] ?? data['userName'] ?? '').toString().trim();
                if (name.isEmpty) {
                  final fn = (data['firstName'] ?? '').toString().trim();
                  final ln = (data['lastName'] ?? '').toString().trim();
                  name = '$fn $ln'.trim();
                }
                if (name.isEmpty) {
                  name = (data['email'] ?? 'Member').toString();
                }
                final role = data['designation'] ?? data['roleLabel'] ?? data['role'] ?? 'Employee';
                final dept = (data['dept'] ?? data['department'] ?? '').toString();

                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EmployeeWorkspaceScreen(
                          employeeData: {
                            ...data,
                            'name': name,
                            'email': (data['email'] ?? entry.value.id).toString().toLowerCase(),
                          },
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(dept.isEmpty ? role : dept,
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF64748B))),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right_rounded,
                                size: 16, color: Color(0xFF94A3B8)),
                          ],
                        ),
                        if (entry.key < recent.length - 1)
                          const Divider(height: 20, color: Color(0xFFF3F4F6)),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
