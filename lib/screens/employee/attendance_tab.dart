import 'package:attendance_app/screens/employee/employee_attendance_overview_tab.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:animate_do/animate_do.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/screens/employee/employee_attendance_detail_screen.dart';
import 'package:attendance_app/screens/employee/employee_attendance_correction_screen.dart';
import 'package:attendance_app/utils/notification_helper.dart';
import 'package:attendance_app/utils/notification_service.dart';
import 'package:attendance_app/screens/employee/analytics_tab/analytics_main_screen.dart';
import 'package:attendance_app/screens/employee/requests_tab/requests_main_screen.dart';
class EmployeeAttendanceTab extends StatefulWidget {
  const EmployeeAttendanceTab({super.key});

  @override
  State<EmployeeAttendanceTab> createState() => _EmployeeAttendanceTabState();
}

class _EmployeeAttendanceTabState extends State<EmployeeAttendanceTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final user = FirebaseAuth.instance.currentUser;
  late Stream<QuerySnapshot> _attendanceStream;
  Timer? _timer;
  bool _isCheckingInOut = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _attendanceStream =
        FirestoreService.userAttendanceCol(user?.email ?? '').snapshots();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String _getAttendanceDocId() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  Future<void> _handleCheckInOut(String status, bool isCheckIn) async {
    if (_isCheckingInOut) return;
    setState(() => _isCheckingInOut = true);
    try {
      final now = DateTime.now();
      final userEmail = user?.email ?? '';

      final data = {
        'companyId': FirestoreService.companyId,
        'userId': userEmail,
        'status': status,
        if (isCheckIn) 'workMode': 'office', // default
        if (isCheckIn) 'checkIn': Timestamp.fromDate(now),
        if (!isCheckIn) 'checkOut': Timestamp.fromDate(now),
        'date': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
        'recordDate': DateFormat('yyyy-MM-dd').format(now),
      };

      await FirestoreService.userAttendanceCol(userEmail)
          .doc(_getAttendanceDocId())
          .set(data, SetOptions(merge: true));

      await NotificationHelper.notifyEmployee(
        employeeEmail: userEmail,
        title:
            isCheckIn ? 'Check-In Successful Ã¢Å“â€¦' : 'Check-Out Successful Ã°Å¸â€˜â€¹',
        body:
            'You have successfully ${isCheckIn ? 'checked in' : 'checked out'} at ${DateFormat('hh:mm a').format(now)}.',
        type: isCheckIn ? 'check_in' : 'check_out',
        extraData: {'userId': user?.uid},
      );

      if (isCheckIn) {
        final eParts = AppSession().shiftEndTime.split(':');
        final shiftEnd = DateTime(now.year, now.month, now.day,
            int.parse(eParts[0]), int.parse(eParts[1]));
        await NotificationService().scheduleCheckoutReminder(shiftEnd);
      } else {
        await NotificationService().cancelCheckoutReminder();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: AppTheme.danger));
      }
    } finally {
      if (mounted) setState(() => _isCheckingInOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF5C5CFF),
                unselectedLabelColor: const Color(0xFF6B7280),
                indicatorColor: const Color(0xFF5C5CFF),
                indicatorWeight: 2,
                isScrollable: false,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Summary'),
                  Tab(text: 'Requests'),
                  Tab(text: 'Analytics'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  const EmployeeAttendanceOverviewTab(),
                  _buildSummaryTab(),
                  const RequestsMainScreen(),
                  const AnalyticsMainScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // OVERVIEW TAB
  // ==========================================

  Widget _buildOverviewTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.userAttendanceCol(user?.email ?? '').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        final now = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(now);

        Map<String, dynamic>? todayData;
        try {
          final doc = docs.firstWhere((d) => d.id == todayStr);
          todayData = doc.data() as Map<String, dynamic>;
        } catch (_) {}

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTodayCard(todayData),
              const SizedBox(height: 24),
              _buildThisWeekProgress(docs),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildHistoryShortcut()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildCorrectionShortcut()),
                ],
              ),
              const SizedBox(height: 24),
              _buildThisMonthSummary(docs),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTodayCard(Map<String, dynamic>? todayData) {
    bool hasCheckedIn = todayData != null && todayData['checkIn'] != null;
    bool hasCheckedOut = todayData != null && todayData['checkOut'] != null;
    Timestamp? checkInTs = todayData?['checkIn'];

    String statusText = 'Not Started';
    if (hasCheckedIn && !hasCheckedOut) statusText = 'Checked In';
    if (hasCheckedOut) statusText = 'Checked Out';

    String timeText = '0m 00s';
    String subText = 'Since --:--';

    if (hasCheckedIn && checkInTs != null) {
      subText = 'Since ${DateFormat('hh:mm a').format(checkInTs.toDate())}';

      if (!hasCheckedOut) {
        final diff = DateTime.now().difference(checkInTs.toDate());
        int h = diff.inHours;
        int m = diff.inMinutes % 60;
        int s = diff.inSeconds % 60;
        timeText = h > 0
            ? '${h}h ${m}m ${s}s'
            : '${m}m ${s.toString().padLeft(2, '0')}s';
      } else {
        final outTs = todayData['checkOut'] as Timestamp;
        final diff = outTs.toDate().difference(checkInTs.toDate());
        int h = diff.inHours;
        int m = diff.inMinutes % 60;
        timeText = '${h}h ${m}m';
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Today\'s Attendance',
                    style: TextStyle(
                        color: AppTheme.textHint,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    statusText,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeText,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subText,
                    style: const TextStyle(
                        color: AppTheme.textHint,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: _buildTodayStat(
                      'Shift Start', AppSession().shiftStartTime)),
              const SizedBox(width: 8),
              Expanded(
                  child:
                      _buildTodayStat('Shift End', AppSession().shiftEndTime)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildTodayStat('Status', 'On Time', isStatus: true)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isCheckingInOut
                      ? null
                      : () async {
                          if (!hasCheckedIn) {
                            await _handleCheckInOut('checked_in', true);
                          } else if (!hasCheckedOut) {
                            await _handleCheckInOut('checked_out', false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5C5CFF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isCheckingInOut
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          !hasCheckedIn
                              ? 'Check In'
                              : (!hasCheckedOut
                                  ? 'Check Out'
                                  : 'Done for Today'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => EmployeeAttendanceCorrectionScreen(
                                date: DateTime.now())));
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(
                        color: AppTheme.divider.withValues(alpha: 0.5)),
                  ),
                  child: const Text(
                    'Correction',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTodayStat(String label, String value, {bool isStatus = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
                color: AppTheme.textHint,
                fontSize: 10,
                fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          isStatus
              ? Text('On Time',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800))
              : Text(
                  _fmt12(value),
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
        ],
      ),
    );
  }

  String _fmt12(String hhmm) {
    try {
      final parts = hhmm.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final dt = DateTime(2000, 1, 1, h, m);
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return hhmm;
    }
  }

  Widget _buildThisWeekProgress(List<QueryDocumentSnapshot> docs) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'This Week',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.trending_up,
                      color: const Color(0xFF4CAF50), size: 16),
                  const SizedBox(width: 4),
                  const Text(
                    '98% attendance',
                    style: TextStyle(
                        color: const Color(0xFF4CAF50),
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildWeekDayCircle('Mon', '8h 02m', 1), // 1 = Present
              _buildWeekDayCircle('Tue', '8h 15m', 1),
              _buildWeekDayCircle('Wed', '7h 48m', 2), // 2 = Late
              _buildWeekDayCircle('Thu', '8h 30m', 1),
              _buildWeekDayCircle('Fri', '--', 3), // 3 = Current / Active
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekDayCircle(String day, String hours, int statusType) {
    Color bgColor;
    Widget icon;
    if (statusType == 1) {
      // Present
      bgColor = const Color(0xFFE8F5E9);
      icon = const Icon(Icons.check, color: Color(0xFF4CAF50), size: 16);
    } else if (statusType == 2) {
      // Late
      bgColor = const Color(0xFFFFF3E0);
      icon = const Text('L',
          style: TextStyle(
              color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w800));
    } else if (statusType == 3) {
      // Active
      bgColor = const Color(0xFF5C5CFF);
      icon = Container(
          width: 4,
          height: 4,
          decoration:
              const BoxDecoration(color: Colors.white, shape: BoxShape.circle));
    } else {
      bgColor = AppTheme.divider;
      icon = const SizedBox.shrink();
    }

    return Column(
      children: [
        Text(
          day,
          style: const TextStyle(
              color: AppTheme.textHint,
              fontSize: 11,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
          ),
          child: Center(child: icon),
        ),
        const SizedBox(height: 8),
        Text(
          hours,
          style: const TextStyle(
              color: AppTheme.textHint,
              fontSize: 10,
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildHistoryShortcut() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8EAF6),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.bar_chart, color: Color(0xFF5C5CFF), size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Attendance\nHistory',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        height: 1.2)),
                SizedBox(height: 4),
                Text('View past\nrecords',
                    style: TextStyle(
                        color: AppTheme.textHint,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        height: 1.2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrectionShortcut() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    EmployeeAttendanceCorrectionScreen(date: DateTime.now())));
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.divider.withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.error_outline,
                  color: Colors.orange, size: 18),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Request\nCorrection',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          height: 1.2)),
                  SizedBox(height: 4),
                  Text('Fix attendance\nerrors',
                      style: TextStyle(
                          color: AppTheme.textHint,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          height: 1.2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThisMonthSummary(List<QueryDocumentSnapshot> docs) {
    int present = 0;
    int late = 0;
    for (var d in docs) {
      final data = d.data() as Map<String, dynamic>;
      if (data['checkIn'] != null) present++;
      if (data['status'] == 'late') late++;
    }

    // A simple mock for attendance percentage based on present vs 22 working days
    double percentage =
        present == 0 ? 0.0 : ((present / 22) * 100).clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'This Month',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.trending_up,
                      color: Color(0xFF4CAF50), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        color: Color(0xFF4CAF50),
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildWeekStatBox(present, 'Present',
                    const Color(0xFF4CAF50), const Color(0xFFE8F5E9)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildWeekStatBox(
                    late, 'Late', Colors.orange, const Color(0xFFFFF3E0)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildWeekStatBox(
                    0, 'Absent', Colors.red, const Color(0xFFFFEBEE)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthStatBox(
      int count, String label, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
                color: color,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                height: 1.0),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildWeekStatBox(
      int count, String label, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1.0),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SUMMARY TAB
  // ==========================================

  bool _isMonthView = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Widget _buildSummaryTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _isMonthView = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: !_isMonthView
                                ? AppTheme.primary
                                : Colors.transparent),
                      ),
                      child: Text('Week',
                          style: TextStyle(
                              color: !_isMonthView
                                  ? AppTheme.primary
                                  : AppTheme.textHint,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _isMonthView = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _isMonthView
                                ? AppTheme.primary
                                : Colors.transparent),
                      ),
                      child: Text('Month',
                          style: TextStyle(
                              color: _isMonthView
                                  ? AppTheme.primary
                                  : AppTheme.textHint,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.filter_list,
                    size: 16, color: AppTheme.textSecondary),
                label: const Text('Filter',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.divider),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              )
            ],
          ),
        ),
        Expanded(
          child: _buildSummaryCalendar(_isMonthView),
        ),
      ],
    );
  }

  void _showDayBottomSheet(BuildContext context, DateTime day, Map<String, dynamic> initialData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DayDetailSheet(date: day, initialData: initialData),
    );
  }

  bool _isSameWeek(DateTime d1, DateTime d2) {
    DateTime w1 = d1.subtract(Duration(days: d1.weekday % 7));
    DateTime w2 = d2.subtract(Duration(days: d2.weekday % 7));
    return w1.year == w2.year && w1.month == w2.month && w1.day == w2.day;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Widget _buildCalendarCell(
      DateTime date, String? status, bool isSelected, bool isToday, {VoidCallback? onTap}) {
    Color bgColor = Colors.transparent;
    Color? dotColor;
    Color textColor = const Color(0xFF1F2937);

    if (isSelected) {
      bgColor = const Color(0xFF5C5CFF);
      textColor = Colors.white;
    } else if (isToday) {
      bgColor = const Color(0xFFEEF2FF);
      textColor = const Color(0xFF5C5CFF);
    }

    if (status != null && !isSelected) {
      switch (status) {
        case 'present':
          dotColor = const Color(0xFF22C55E);
          break;
        case 'late':
          dotColor = const Color(0xFFF59E0B);
          break;
        case 'wfh':
          dotColor = const Color(0xFF5C5CFF);
          break;
        case 'holiday':
          dotColor = const Color(0xFF4B5563);
          textColor = const Color(0xFF4B5563);
          break;
        case 'leave':
          dotColor = const Color(0xFF8B5CF6);
          break;
        case 'absent':
          dotColor = const Color(0xFFEF4444);
          break;
      }
    }

    final now = DateTime.now();
    final isPast = date.isBefore(DateTime(now.year, now.month, now.day));
    if (status == null && isPast && !isToday && !isSelected) {
      textColor = const Color(0xFF9CA3AF);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: const Border(
            right: BorderSide(color: Color(0xFFF3F4F6), width: 1),
            bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
          ),
        ),
        child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${date.day}',
                style: TextStyle(
                    color: textColor,
                    fontWeight: isToday || isSelected ? FontWeight.w800 : FontWeight.w700,
                    fontSize: 14)),
            const SizedBox(height: 4),
            if (dotColor != null)
              Container(
                  width: 5, height: 5,
                  decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle))
            else if (!isSelected)
              const SizedBox(height: 5),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSummaryCalendar(bool isMonth) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.userAttendanceCol(user?.email ?? '').snapshots(),
      builder: (context, snapshot) {
        int present = 0;
        int late = 0;
        int holiday = 0;
        int leave = 0;
        int absent = 0;

        Map<DateTime, String> statusMap = {};
        if (snapshot.hasData) {
          for (var d in snapshot.data!.docs) {
            final data = d.data() as Map<String, dynamic>;
            final date = DateTime.tryParse(d.id);
            if (date != null) {
              String st = 'absent';
              if (data['checkIn'] != null) {
                st = 'present';
                if (data['workMode'] == 'wfh') {
                  st = 'wfh';
                } else {
                  // Late detection using AppSession grace period
                  final checkInTs = data['checkIn'] as Timestamp?;
                  if (checkInTs != null) {
                    final checkIn = checkInTs.toDate();
                    final sParts = AppSession().shiftStartTime.split(':');
                    final lateThreshold = DateTime(checkIn.year, checkIn.month, checkIn.day,
                        int.parse(sParts[0]), int.parse(sParts[1]))
                        .add(Duration(minutes: AppSession().gracePeriod));
                    if (checkIn.isAfter(lateThreshold) && data['remarkStatus'] != 'approved') {
                      st = 'late';
                    }
                  }
                }
              }
              if (data['status'] == 'holiday') st = 'holiday';
              if (data['status'] == 'leave') st = 'leave';
              statusMap[DateTime(date.year, date.month, date.day)] = st;

              bool inRange = false;
              if (isMonth) {
                inRange = date.month == _focusedDay.month &&
                    date.year == _focusedDay.year;
              } else {
                inRange = _isSameWeek(date, _focusedDay);
              }

              if (inRange) {
                if (st == 'present') present++;
                if (st == 'late') late++;
                if (st == 'holiday') holiday++;
                if (st == 'leave') leave++;
                // In week view, absent is usually everything else not marked, but let's just count st == absent
                if (st == 'absent')
                  absent++; // assuming we might have 'absent' status in db explicitly
              }
            }
          }
        }

        if (!isMonth) {
          int absentCount = 0; // The screenshot has 0 absent
          List<DocumentSnapshot> weekDocs = snapshot.hasData
              ? snapshot.data!.docs.where((d) {
                  final date = DateTime.tryParse(d.id);
                  return date != null && _isSameWeek(date, _focusedDay);
                }).toList()
              : [];
          weekDocs.sort((a, b) => b.id.compareTo(a.id));

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _focusedDay =
                            _focusedDay.subtract(const Duration(days: 7))),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppTheme.divider, width: 0.5)),
                          child: const Icon(Icons.chevron_left,
                              size: 20, color: AppTheme.textSecondary),
                        ),
                      ),
                      Column(
                        children: [
                          Text(DateFormat('MMMM yyyy').format(_focusedDay),
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary)),
                          const SizedBox(height: 4),
                          Text(
                              '${DateFormat('dd MMM').format(_focusedDay.subtract(Duration(days: _focusedDay.weekday % 7)))} - ${DateFormat('dd MMM yyyy').format(_focusedDay.add(Duration(days: 6 - (_focusedDay.weekday % 7))))}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textHint,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _focusedDay =
                            _focusedDay.add(const Duration(days: 7))),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppTheme.divider, width: 0.5)),
                          child: const Icon(Icons.chevron_right,
                              size: 20, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                          child: _buildWeekStatBox(
                              present,
                              'Present',
                              const Color(0xFF4CAF50),
                              const Color(0xFFE8F5E9))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _buildWeekStatBox(late, 'Late', Colors.orange,
                              const Color(0xFFFFF3E0))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _buildWeekStatBox(leave, 'Leave', Colors.grey,
                              Colors.grey.shade100)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _buildWeekStatBox(absentCount, 'Absent',
                              Colors.red, const Color(0xFFFFEBEE))),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: weekDocs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final date = DateTime.tryParse(doc.id)!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildWeekDayCard(
                            date,
                            data,
                            statusMap[
                                DateTime(date.year, date.month, date.day)]),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isMonth) {
                            _focusedDay = DateTime(_focusedDay.year,
                                _focusedDay.month - 1, _focusedDay.day);
                          } else {
                            _focusedDay =
                                _focusedDay.subtract(const Duration(days: 7));
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppTheme.divider, width: 0.5)),
                        child: const Icon(Icons.chevron_left,
                            size: 20, color: AppTheme.textSecondary),
                      ),
                    ),
                    Text(
                        isMonth
                            ? DateFormat('MMMM yyyy').format(_focusedDay)
                            : '${DateFormat('MMM d').format(_focusedDay.subtract(Duration(days: _focusedDay.weekday % 7)))} - ${DateFormat('MMM d').format(_focusedDay.add(Duration(days: 6 - (_focusedDay.weekday % 7))))}',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary)),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isMonth) {
                            _focusedDay = DateTime(_focusedDay.year,
                                _focusedDay.month + 1, _focusedDay.day);
                          } else {
                            _focusedDay =
                                _focusedDay.add(const Duration(days: 7));
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppTheme.divider, width: 0.5)),
                        child: const Icon(Icons.chevron_right,
                            size: 20, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFF3F4F6), width: 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      headerVisible: false,
                      calendarFormat:
                          isMonth ? CalendarFormat.month : CalendarFormat.week,
                      rowHeight: 60,
                      daysOfWeekHeight: 48,
                      calendarStyle: const CalendarStyle(
                        outsideDaysVisible: false,
                        cellMargin: EdgeInsets.zero,
                        cellPadding: EdgeInsets.zero,
                      ),
                      calendarBuilders: CalendarBuilders(
                        dowBuilder: (context, day) {
                          final text = DateFormat.E().format(day)[0];
                          return Container(
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
                                right: BorderSide(color: Color(0xFFF3F4F6), width: 1),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              text,
                              style: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        },
                        defaultBuilder: (context, day, focusedDay) =>
                            _buildCalendarCell(
                                day,
                                statusMap[DateTime(day.year, day.month, day.day)],
                                isSameDay(_selectedDay, day),
                                false,
                                onTap: () {
                                  setState(() {
                                    _selectedDay = day;
                                    _focusedDay = focusedDay;
                                  });
                                  _navigateToDetail(day, snapshot);
                                }),
                        todayBuilder: (context, day, focusedDay) =>
                            _buildCalendarCell(
                                day,
                                statusMap[DateTime(day.year, day.month, day.day)],
                                isSameDay(_selectedDay, day),
                                true,
                                onTap: () {
                                  setState(() {
                                    _selectedDay = day;
                                    _focusedDay = focusedDay;
                                  });
                                  _navigateToDetail(day, snapshot);
                                }),
                        outsideBuilder: (context, day, focusedDay) => Container(
                          decoration: const BoxDecoration(
                            border: Border(
                              right: BorderSide(color: Color(0xFFF3F4F6), width: 1),
                              bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
                            ),
                          ),
                        ),
                      ),
                    selectedDayPredicate: (day) => false,
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                      _navigateToDetail(selectedDay, snapshot);
                    },
                    onPageChanged: (focusedDay) {
                      setState(() {
                        _focusedDay = focusedDay;
                      });
                    },
                  ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Dots Legend
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildLegend(const Color(0xFF4CAF50), 'Present'),
                      _buildLegend(Colors.orange, 'Late'),
                      _buildLegend(const Color(0xFF5C5CFF), 'Holiday'),
                      _buildLegend(Colors.grey, 'Leave'),
                      _buildLegend(Colors.red, 'Absent'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        isMonth
                            ? '${DateFormat('MMMM').format(_focusedDay)} Summary'
                            : 'This Week Summary',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                            child: _buildMonthStatBox(
                                present,
                                'Present',
                                const Color(0xFF4CAF50),
                                const Color(0xFFE8F5E9))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _buildMonthStatBox(late, 'Late',
                                Colors.orange, const Color(0xFFFFF3E0))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _buildMonthStatBox(
                                holiday,
                                'Holiday',
                                const Color(0xFF5C5CFF),
                                const Color(0xFFE8EAF6))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _buildMonthStatBox(leave, 'Leave',
                                Colors.grey, Colors.grey.shade100)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeekDayCard(
      DateTime date, Map<String, dynamic> data, String? status) {
    Color bgColor = Colors.grey.shade100;
    Color textColor = Colors.grey;
    String statusText = 'Absent';

    if (status == 'present') {
      bgColor = const Color(0xFFE8F5E9);
      textColor = const Color(0xFF4CAF50);
      statusText = 'Present';
      if (data['status'] == 'active' || data['checkOut'] == null) {
        statusText = 'Active';
      }
    } else if (status == 'late') {
      bgColor = const Color(0xFFFFF3E0);
      textColor = Colors.orange;
      statusText = 'Late';
    } else if (status == 'holiday') {
      bgColor = const Color(0xFFE8EAF6);
      textColor = const Color(0xFF5C5CFF);
      statusText = 'Holiday';
    } else if (status == 'leave') {
      bgColor = Colors.grey.shade100;
      textColor = Colors.grey;
      statusText = 'Leave';
    }

    if (data['status'] == 'half_day') {
      bgColor = const Color(0xFFE0F7FA);
      textColor = const Color(0xFF00BCD4);
      statusText = 'Half Day';
    }

    String dayTitle = DateFormat('EEE').format(date);
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      dayTitle = 'Today';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      dayTitle = 'Yesterday';
    }

    final checkInTs = data['checkIn'] as Timestamp?;
    final checkOutTs = data['checkOut'] as Timestamp?;
    String cin = checkInTs != null
        ? DateFormat('hh:mm a').format(checkInTs.toDate())
        : '--:--';
    String cout = checkOutTs != null
        ? DateFormat('hh:mm a').format(checkOutTs.toDate())
        : '--:--';

    String? totalHours;
    if (checkInTs != null && checkOutTs != null) {
      final diff = checkOutTs.toDate().difference(checkInTs.toDate());
      totalHours =
          '${diff.inHours}h ${diff.inMinutes.remainder(60).toString().padLeft(2, '0')}m';
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    EmployeeAttendanceDetailScreen(date: date, data: data)));
      },
      child: Container(
        padding:
            const EdgeInsets.only(left: 12, right: 16, top: 12, bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(DateFormat('MMM').format(date),
                      style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          height: 1.0)),
                  const SizedBox(height: 2),
                  Text(DateFormat('d').format(date),
                      style: TextStyle(
                          color: textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.0)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(dayTitle,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(statusText,
                            style: TextStyle(
                                color: textColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                      if (data['overtime'] == true ||
                          (totalHours != null &&
                              checkOutTs!
                                      .toDate()
                                      .difference(checkInTs!.toDate())
                                      .inHours >
                                  8)) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: const Color(0xFFE8EAF6),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Text('+OT',
                              style: TextStyle(
                                  color: Color(0xFF5C5CFF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('In: ',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textHint,
                              fontWeight: FontWeight.w600)),
                      Text(cin,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 12),
                      const Text('Out: ',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textHint,
                              fontWeight: FontWeight.w600)),
                      Text(cout,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700)),
                      if (totalHours != null) ...[
                        const SizedBox(width: 12),
                        Text(totalHours,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF5C5CFF),
                                fontWeight: FontWeight.w700)),
                      ]
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textHint, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textHint,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _navigateToDetail(DateTime date, AsyncSnapshot<QuerySnapshot> snapshot) {
    Map<String, dynamic> dayData = {};
    if (snapshot.hasData) {
      try {
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final doc = snapshot.data!.docs.firstWhere((d) => d.id == dateStr);
        dayData = doc.data() as Map<String, dynamic>;
      } catch (_) {}
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmployeeAttendanceDetailScreen(date: date, data: dayData),
      ),
    );
  }
}

// ─── Day Detail Bottom Sheet ──────────────────────────────────────────────────

class _DayDetailSheet extends StatefulWidget {
  final DateTime date;
  final Map<String, dynamic> initialData;
  const _DayDetailSheet({required this.date, required this.initialData});

  @override
  State<_DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends State<_DayDetailSheet> {
  final _userEmail = FirebaseAuth.instance.currentUser?.email ?? '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmtAmPm(Timestamp? t) {
    if (t == null) return '--:--';
    return DateFormat('hh:mm a').format(t.toDate().toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final docId = DateFormat('yyyy-MM-dd').format(widget.date);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirestoreService.userAttendanceCol(_userEmail).doc(docId).snapshots(),
      builder: (context, snap) {
        final Map<String, dynamic> d = Map<String, dynamic>.from(widget.initialData);
        if (snap.hasData && snap.data!.exists) {
          d.addAll(snap.data!.data() as Map<String, dynamic>);
        }
        return _buildSheet(d);
      },
    );
  }

  Widget _buildSheet(Map<String, dynamic> d) {
    final now = DateTime.now();
    final checkInTs = d['checkIn'] as Timestamp?;
    final checkOutTs = d['checkOut'] as Timestamp?;
    final bool hasIn = checkInTs != null;
    final bool hasOut = checkOutTs != null;
    final workMode = (d['workMode'] as String? ?? 'office');

    // Status
    String statusLabel = 'Absent';
    Color statusColor = const Color(0xFFEF4444);
    Color statusBg = const Color(0xFFFEF2F2);

    if (hasIn) {
      if (workMode == 'wfh') {
        statusLabel = 'WFH';
        statusColor = const Color(0xFF5C5CFF);
        statusBg = const Color(0xFFEEF2FF);
      } else {
        statusLabel = 'Present';
        statusColor = const Color(0xFF10B981);
        statusBg = const Color(0xFFECFDF5);
        final checkIn = checkInTs!.toDate();
        final sParts = AppSession().shiftStartTime.split(':');
        final lateThreshold = DateTime(checkIn.year, checkIn.month, checkIn.day,
            int.parse(sParts[0]), int.parse(sParts[1]))
            .add(Duration(minutes: AppSession().gracePeriod));
        if (checkIn.isAfter(lateThreshold) && d['remarkStatus'] != 'approved') {
          statusLabel = 'Late';
          statusColor = const Color(0xFFF59E0B);
          statusBg = const Color(0xFFFFFBEB);
        }
      }
    }
    if (d['status'] == 'leave') { statusLabel = 'On Leave'; statusColor = const Color(0xFF8B5CF6); statusBg = const Color(0xFFF5F3FF); }
    if (d['status'] == 'holiday') { statusLabel = 'Holiday'; statusColor = const Color(0xFF4B5563); statusBg = const Color(0xFFF3F4F6); }

    // Working hours
    String workStr = '0h 0m';
    if (hasIn) {
      final end = hasOut ? checkOutTs!.toDate() : now;
      final diff = end.difference(checkInTs!.toDate());
      workStr = '${diff.inHours}h ${diff.inMinutes % 60}m';
    }

    final dateStr = DateFormat('EEE, d MMM yyyy').format(widget.date);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F8FC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dateStr, style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827),
                    )),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(statusLabel, style: TextStyle(
                        color: statusColor, fontSize: 12, fontWeight: FontWeight.w700,
                      )),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280), size: 22),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Content
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              children: [
                // Time card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _timeBox(
                            _fmtAmPm(checkInTs), 'Check In',
                            const Color(0xFFECFDF5), const Color(0xFF059669), const Color(0xFF10B981),
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: _timeBox(
                            hasOut ? _fmtAmPm(checkOutTs) : (hasIn ? 'Ongoing' : '--:--'),
                            'Check Out',
                            const Color(0xFFFFFBEB), const Color(0xFFD97706), const Color(0xFFF59E0B),
                          )),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _smallBox(workStr, 'Working Hrs')),
                          const SizedBox(width: 8),
                          Expanded(child: _smallBox(workMode == 'wfh' ? 'WFH' : 'Office', 'Work Mode')),
                          const SizedBox(width: 8),
                          Expanded(child: _smallBox(AppSession().shiftStartTime, 'Shift Start')),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      _detailRow('Status', statusLabel),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      _detailRow('Shift', '${AppSession().shiftStartTime} – ${AppSession().shiftEndTime}'),
                      const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      _detailRow('Work Mode', workMode == 'wfh' ? 'Work From Home' : 'Office'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Open full detail button
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => EmployeeAttendanceDetailScreen(date: widget.date, data: d),
                    ));
                  },
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5C5CFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('View Full Details', style: TextStyle(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700,
                        )),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _timeBox(String time, String label, Color bg, Color timeColor, Color labelColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(time, style: TextStyle(color: timeColor, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: labelColor, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _smallBox(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
      alignment: Alignment.center,
      child: Column(children: [
        Text(value, style: const TextStyle(color: Color(0xFF111827), fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 9, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(color: Color(0xFF111827), fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
