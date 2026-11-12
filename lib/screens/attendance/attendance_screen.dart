import 'package:flutter/material.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'attendance_overview_tab.dart';
import 'attendance_summary_tab.dart';
import 'attendance_requests_tab.dart';
import 'attendance_analytics_tab.dart';

/// Universal Attendance Screen — shared across Employee, Manager, and Admin.
///
/// The screen adapts its data and interactions based on [AppSession().role].
/// It shows four top-level tabs: Overview, Summary, Requests, and Analytics.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Tab Bar ─────────────────────────────────────────────
            Container(
              color: Colors.white,
              height: 60,
              child: AnimatedBuilder(
                animation: _tabController.animation!,
                builder: (context, _) {
                  final current = _tabController.animation!.value.round();
                  const labels = ['Overview', 'Summary', 'Requests', 'Analytics'];
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: labels.length,
                    itemBuilder: (context, i) {
                      final active = current == i;
                      return GestureDetector(
                        onTap: () => _tabController.animateTo(i),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: active ? const Color(0xFF5C5CFF) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                              color: active ? Colors.white : const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // ─── Tab Content ─────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  AttendanceOverviewTab(),
                  AttendanceSummaryTab(),
                  AttendanceRequestsTab(),
                  AttendanceAnalyticsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
