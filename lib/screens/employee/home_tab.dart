import 'package:attendance_app/screens/employee/employee_team_tasks_tab.dart';
import 'package:attendance_app/screens/employee/employee_team_announcements_tab.dart';
import 'package:attendance_app/screens/employee/employee_feed_tab.dart';
import 'package:attendance_app/screens/employee/employee_team_members_tab.dart';
import 'package:attendance_app/screens/employee/employee_attendance_summary_screen.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/location_service.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/widgets/location_map_card.dart';
import 'package:attendance_app/widgets/full_map_screen.dart';
import 'package:attendance_app/screens/employee/attendance_tab.dart';
import 'package:attendance_app/utils/notification_helper.dart';
import 'package:attendance_app/screens/employee/employee_leave_summary_screen.dart';
import 'package:attendance_app/screens/employee/employee_calendar_tab.dart';
import 'package:attendance_app/utils/notification_service.dart';
import 'package:attendance_app/screens/employee/daily_summary_screen.dart';
import 'package:attendance_app/screens/employee/announcement_tab.dart';
import 'package:attendance_app/screens/employee/notifications_screen.dart';
import 'package:attendance_app/screens/login_screen.dart'
    as attendance_app_login;

const _kPrimary = Color(0xFF5C5CFF);
const _kPrimaryLight = Color(0xFFEEEEFF);
const _kBg = Color(0xFFF6F7FB);
const _kCard = Colors.white;
const _kText = Color(0xFF111827);
const _kSubText = Color(0xFF6B7280);
const _kBorder = Color(0xFFEEEFF3);
const _kGreen = Color(0xFF22C55E);
const _kYellow = Color(0xFFF59E0B);
const _kRed = Color(0xFFEF4444);

class EmployeeHomeTab extends StatefulWidget {
  const EmployeeHomeTab({super.key});
  @override
  State<EmployeeHomeTab> createState() => _EmployeeHomeTabState();
}

class _EmployeeHomeTabState extends State<EmployeeHomeTab> {
  final user = FirebaseAuth.instance.currentUser;
  LocationData? _currentLocationData;
  bool _isCheckingInOut = false;
  Timer? _timer;
  int _selectedMainSpace = 0;
  int _selectedSubTab = 0;

  String _getAttendanceDocId() =>
      DateFormat('yyyy-MM-dd').format(DateTime.now());

  late final CollectionReference<Map<String, dynamic>> _todayRef;
  late final Stream<DocumentSnapshot> _userStream;
  late final Stream<DocumentSnapshot> _todayAttendanceStream;
  late final Stream<QuerySnapshot> _allAttendanceStream;
  late final Stream<QuerySnapshot> _leaveRequestsStream;

  @override
  void initState() {
    super.initState();
    final userEmail = user?.email ?? '';
    _todayRef = FirestoreService.userAttendanceCol(userEmail);
    _userStream = FirestoreService.userStreamByEmail(userEmail);
    _todayAttendanceStream = _todayRef.doc(_getAttendanceDocId()).snapshots();
    _allAttendanceStream = _todayRef.snapshots();
    _leaveRequestsStream =
        FirestoreService.userLeaveRequestsCol(userEmail).snapshots();
    _startLocationUpdates();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startLocationUpdates() {
    LocationService().startRealtimeTracking();
    LocationService.getStream().listen((data) {
      if (mounted && data.position != null)
        setState(() => _currentLocationData = data);
    });
  }

  String _fmt12(String hhmm) {
    try {
      final parts = hhmm.split(':');
      return DateFormat('hh:mm a').format(
          DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1])));
    } catch (_) {
      return hhmm;
    }
  }

  String _getWorkingDuration(Timestamp? checkIn, Timestamp? checkOut) {
    if (checkIn == null) return '0h 0m';
    final diff =
        (checkOut?.toDate() ?? DateTime.now()).difference(checkIn.toDate());
    return '${diff.inHours}h ${diff.inMinutes % 60}m';
  }

  String _getOvertimeDuration(Timestamp? checkIn, Timestamp? checkOut) {
    if (checkIn == null) return '0 min';
    final now = checkOut?.toDate() ?? DateTime.now();
    try {
      final sParts = AppSession().shiftStartTime.split(':');
      final eParts = AppSession().shiftEndTime.split(':');
      final shiftDur = Duration(
              hours: int.parse(eParts[0]), minutes: int.parse(eParts[1])) -
          Duration(hours: int.parse(sParts[0]), minutes: int.parse(sParts[1]));
      final worked = now.difference(checkIn.toDate());
      if (worked > shiftDur) {
        final ot = worked - shiftDur;
        return ot.inHours > 0
            ? '${ot.inHours}h ${ot.inMinutes % 60}m'
            : '${ot.inMinutes} min';
      }
    } catch (_) {}
    return '0 min';
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'EM';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1)
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  Future<void> _handleCheckInOut(String status, bool isCheckIn) async {
    if (_isCheckingInOut) return;
    setState(() => _isCheckingInOut = true);
    try {
      final now = DateTime.now();
      final userEmail = user?.email ?? '';
      final isInside = _currentLocationData?.isWithinRadius ?? false;
      final data = {
        'companyId': FirestoreService.companyId,
        'userId': userEmail,
        'status': status,
        if (isCheckIn) 'workMode': isInside ? 'office' : 'wfh',
        if (isCheckIn) 'checkIn': Timestamp.fromDate(now),
        if (isCheckIn)
          'checkInLocation': _currentLocationData?.address ?? 'Unknown',
        if (!isCheckIn) 'checkOut': Timestamp.fromDate(now),
        if (!isCheckIn)
          'checkOutLocation': _currentLocationData?.address ?? 'Unknown',
        'date': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
        'recordDate': DateFormat('yyyy-MM-dd').format(now),
      };
      await _todayRef
          .doc(_getAttendanceDocId())
          .set(data, SetOptions(merge: true));
      if (!isCheckIn) {
        final doc = await _todayRef.doc(_getAttendanceDocId()).get();
        final checkInTime = (doc.data()?['checkIn'] as Timestamp?)?.toDate();
        if (checkInTime != null) {
          final diff = now.difference(checkInTime);
          final sParts = AppSession().shiftStartTime.split(':');
          final eParts = AppSession().shiftEndTime.split(':');
          final standardDuration = Duration(
                  hours: int.parse(eParts[0]), minutes: int.parse(eParts[1])) -
              Duration(
                  hours: int.parse(sParts[0]), minutes: int.parse(sParts[1]));
          if (diff.inSeconds > standardDuration.inSeconds) {
            final otMinutes = diff.inMinutes - standardDuration.inMinutes;
            final querySnapshot = await FirestoreService.usersCol
                .where('email', isEqualTo: userEmail)
                .limit(1)
                .get();
            final userName = querySnapshot.docs.isNotEmpty
                ? querySnapshot.docs.first.data()['name']
                : user?.displayName ?? 'Employee';
            await FirestoreService.userOvertimeRequestsCol(userEmail).add({
              'companyId': FirestoreService.companyId,
              'userId': user?.uid,
              'userName': userName,
              'requestDate': Timestamp.fromDate(now),
              'durationInMinutes': otMinutes,
              'status': 'pending',
              'isAutoSubmitted': true,
              'checkInTime': Timestamp.fromDate(checkInTime),
              'checkOutTime': Timestamp.fromDate(now),
            });
          }
        }
      }
      await NotificationHelper.notifyEmployee(
        employeeEmail: userEmail,
        title: isCheckIn ? 'Check-In Successful' : 'Check-Out Successful',
        body:
            'You have successfully ${isCheckIn ? 'checked in' : 'checked out'} at ${DateFormat('hh:mm a').format(now)}.',
        type: isCheckIn ? 'check_in' : 'check_out',
        extraData: {'userId': user?.uid},
      );
      if (isCheckIn) {
        final eParts = AppSession().shiftEndTime.split(':');
        await NotificationService().scheduleCheckoutReminder(DateTime(now.year,
            now.month, now.day, int.parse(eParts[0]), int.parse(eParts[1])));
      } else {
        await NotificationService().cancelCheckoutReminder();
      }
      if (mounted) _showSuccessModal(isCheckIn ? 'Check In' : 'Check Out', now);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: AppTheme.danger));
    } finally {
      if (mounted) setState(() => _isCheckingInOut = false);
    }
  }

  void _showSuccessModal(String title, DateTime time) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => ElasticIn(
        child: Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                    color: Color(0xFFECFDF5), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_outline_rounded,
                    color: Color(0xFF10B981), size: 56),
              ),
              const SizedBox(height: 20),
              const Text('Successfully Done',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4B5563))),
              const SizedBox(height: 6),
              Text(title,
                  style: const TextStyle(
                      color: _kPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text('Time: ${DateFormat('hh:mm:ss a').format(time)}',
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0),
                child: const Text('Okay',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _showCheckInSheet() {
    final isInside = _currentLocationData?.isWithinRadius ?? false;
    final shiftStart = _fmt12(AppSession().shiftStartTime);
    final shiftEnd = _fmt12(AppSession().shiftEndTime);
    final grace = AppSession().gracePeriod;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 24),
          Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                  color: _kPrimaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.access_time_rounded,
                  color: _kPrimary, size: 34)),
          const SizedBox(height: 20),
          const Text('Confirm Check-In',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: _kText)),
          const SizedBox(height: 6),
          const Text("You're about to start your work session for today.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _kSubText, height: 1.4)),
          const SizedBox(height: 24),
          _sheetInfoRow(
              bgColor: const Color(0xFFEEEEFF),
              icon: Icons.access_time_rounded,
              iconColor: _kPrimary,
              label: 'Shift',
              value: 'General Shift  -  ${AppSession().shiftStartTime} - ${AppSession().shiftEndTime}'),
          const SizedBox(height: 10),
          _sheetInfoRow(
              bgColor: const Color(0xFFECFDF5),
              icon: Icons.location_on_rounded,
              iconColor: const Color(0xFF10B981),
              label: 'Location',
              value: isInside
                  ? 'Headquarters  -  Verified'
                  : 'Outside Office Range'),
          const SizedBox(height: 10),
          _sheetInfoRow(
              bgColor: const Color(0xFFFFFBEB),
              icon: Icons.timer_outlined,
              iconColor: const Color(0xFFD97706),
              label: 'Late Buffer',
              value: '$grace minutes grace period'),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _isCheckingInOut
                ? null
                : () async {
                    Navigator.pop(ctx);
                    await _handleCheckInOut('checked_in', true);
                  },
            style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                elevation: 0),
            child: _isCheckingInOut
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Text('Check In Now',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
          ),
          const SizedBox(height: 14),
          GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(
                      fontSize: 14,
                      color: _kSubText,
                      fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }

  void _showCheckOutSheet(Timestamp? checkIn) {
    Duration targetDuration = const Duration(hours: 8);
    try {
      final sParts = AppSession().shiftStartTime.split(':');
      final eParts = AppSession().shiftEndTime.split(':');
      targetDuration = Duration(
              hours: int.parse(eParts[0]), minutes: int.parse(eParts[1])) -
          Duration(hours: int.parse(sParts[0]), minutes: int.parse(sParts[1]));
    } catch (_) {}
    final now = DateTime.now();
    final workedDuration =
        checkIn != null ? now.difference(checkIn.toDate()) : Duration.zero;
    final workedStr =
        '${workedDuration.inHours}h ${(workedDuration.inMinutes % 60).toString().padLeft(2, '0')}m';
    final targetStr =
        '${targetDuration.inHours}h ${(targetDuration.inMinutes % 60).toString().padLeft(2, '0')}m';
    String statusLabel = 'Short';
    Color statusColor = const Color(0xFFF97316);
    if (workedDuration >= targetDuration) {
      statusLabel = (workedDuration.inMinutes - targetDuration.inMinutes) > 0
          ? 'Overtime'
          : 'On Time';
      statusColor = const Color(0xFF10B981);
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 28),
          Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded,
                  color: Color(0xFF10B981), size: 36)),
          const SizedBox(height: 20),
          const Text('Ready to Check Out?',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: _kText)),
          const SizedBox(height: 8),
          const Text(
              'Your session will be saved and your summary will be\ngenerated.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _kSubText, height: 1.45)),
          const SizedBox(height: 28),
          Row(children: [
            _checkoutStatPill(
                value: workedStr,
                label: 'Worked',
                valueColor: _kPrimary,
                bg: const Color(0xFFEEEEFF)),
            const SizedBox(width: 10),
            _checkoutStatPill(
                value: targetStr,
                label: 'Target',
                valueColor: const Color(0xFF10B981),
                bg: const Color(0xFFECFDF5)),
            const SizedBox(width: 10),
            _checkoutStatPill(
                value: statusLabel,
                label: 'Status',
                valueColor: statusColor,
                bg: statusColor.withValues(alpha: 0.10)),
          ]),
          const SizedBox(height: 28),
          Row(children: [
            Expanded(
                child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5)),
              child: const Text('Cancel',
                  style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: ElevatedButton(
              onPressed: _isCheckingInOut
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await _handleCheckInOut('checked_out', false);
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0),
              child: const Text('Confirm',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            )),
          ]),
        ]),
      ),
    );
  }

  Widget _checkoutStatPill(
      {required String value,
      required String label,
      required Color valueColor,
      required Color bg}) {
    return Expanded(
        child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(value,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: valueColor,
                letterSpacing: -0.2)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: _kSubText)),
      ]),
    ));
  }

  Widget _sheetInfoRow(
      {required Color bgColor,
      required IconData icon,
      required Color iconColor,
      required String label,
      required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: iconColor.withValues(alpha: 0.85),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, color: _kText, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null)
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: _kPrimary)));
    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (context, userSnap) {
        final userData = userSnap.data?.data() as Map<String, dynamic>?;
        final rawName = userData?['name']?.toString() ??
            AppSession().userName ??
            user?.displayName ??
            'Employee';
        final fullName = rawName.trim().isEmpty ? 'Employee' : rawName.trim();
        final initials = _getInitials(fullName);
        return StreamBuilder<DocumentSnapshot>(
          stream: _todayAttendanceStream,
          builder: (context, todaySnap) {
            final record = todaySnap.data?.data() as Map<String, dynamic>?;
            final status = record?['status'];
            final checkInTime = record?['checkIn'] as Timestamp?;
            final checkOutTime = record?['checkOut'] as Timestamp?;
            return StreamBuilder<QuerySnapshot>(
              stream: _allAttendanceStream,
              builder: (context, allSnap) {
                final records = allSnap.data?.docs ?? [];
                return StreamBuilder<QuerySnapshot>(
                  stream: _leaveRequestsStream,
                  builder: (context, leaveSnap) {
                    final leaveDocs = leaveSnap.data?.docs ?? [];
                    return Scaffold(
                      backgroundColor: _kBg,
                      body: SafeArea(
                        child: RefreshIndicator(
                          onRefresh: () async {
                            setState(() {});
                            await Future.delayed(
                                const Duration(milliseconds: 600));
                          },
                          color: _kPrimary,
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics()),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 16, 16, 0),
                                      child: _buildHeader(
                                          fullName, initials, userData)),
                                  const SizedBox(height: 16),
                                  Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      child: _buildSpaceTabs()),
                                  if (_selectedMainSpace == 0) ...[
                                    Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        child: _buildSubTabs()),
                                    const SizedBox(height: 16),
                                    if (_selectedSubTab == 0)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _buildOfficeLocationCard(),
                                              const SizedBox(height: 12),
                                              _buildAttendanceTodayCard(status,
                                                  checkInTime, checkOutTime),
                                              const SizedBox(height: 12),
                                              _buildTodayShiftCard(),
                                              const SizedBox(height: 12),
                                              _buildAttendanceSummaryCard(
                                                  records),
                                              const SizedBox(height: 12),
                                              _buildLeaveSummaryCard(leaveDocs),
                                              const SizedBox(height: 12),
                                              _buildActiveTasksCard(),
                                              const SizedBox(height: 12),
                                              _buildPendingRequestsCard(),
                                              const SizedBox(height: 12),
                                              _buildRecentAnnouncementsCard(),
                                              const SizedBox(height: 12),
                                              _buildUpcomingHolidaysCard(),
                                              const SizedBox(height: 100),
                                            ]),
                                      )
                                    else if (_selectedSubTab == 1)
                                      const Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 16),
                                          child: EmployeeAnnouncementTab())
                                    else if (_selectedSubTab == 2)
                                      const Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 16),
                                          child: EmployeeCalendarTab()),
                                  ] else ...[
                                    Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        child: _buildTeamSubTabs()),
                                    const SizedBox(height: 16),
                                    if (_selectedSubTab == 0)
                                      const Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 16),
                                          child: EmployeeTeamMembersTab())
                                    else if (_selectedSubTab == 1)
                                      SizedBox(
                                        height:
                                            MediaQuery.of(context).size.height -
                                                240,
                                        child: const EmployeeFeedTab(),
                                      )
                                    else if (_selectedSubTab == 2)
                                      const EmployeeTeamAnnouncementsTab()
                                    else if (_selectedSubTab == 3)
                                      const EmployeeTeamTasksTab(),
                                  ],
                                ]),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(
      String fullName, String initials, Map<String, dynamic>? userData) {
    final hour = DateTime.now().hour;
    String greeting = hour < 12
        ? 'Good Morning,'
        : hour < 17
            ? 'Good Afternoon,'
            : 'Good Evening,';
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$greeting $fullName',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _kText,
                letterSpacing: -0.3)),
        const SizedBox(height: 2),
        Text(dateStr,
            style: const TextStyle(
                fontSize: 12, color: _kSubText, fontWeight: FontWeight.w500)),
      ])),
      Row(children: [
        Stack(children: [
          _headerIconBtn(Icons.notifications_none_rounded,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const EmployeeNotificationsScreen()))),
          Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 16,
                height: 16,
                decoration:
                    const BoxDecoration(color: _kRed, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Text('2',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
              )),
        ]),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => _showProfileSheet(
              context, fullName, initials, userData?['role'] ?? ''),
          child: Container(
            width: 36,
            height: 36,
            decoration:
                const BoxDecoration(color: _kPrimary, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(initials,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
        ),
      ]),
    ]);
  }

  Widget _headerIconBtn(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBorder)),
          child: Icon(icon, color: _kSubText, size: 20),
        ));
  }

  void _showProfileSheet(
      BuildContext context, String fullName, String initials, String roleStr) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: _kPrimary, borderRadius: BorderRadius.circular(24)),
            child: Row(children: [
              Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(initials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20))),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(fullName,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(roleStr,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8))),
                    const SizedBox(height: 8),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12)),
                        child: const Text('EMPLOYEE',
                            style: TextStyle(
                                color: _kPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                letterSpacing: 0.5))),
                  ])),
            ]),
          ),
          const SizedBox(height: 24),
          _profileItem(
              icon: Icons.person_outline_rounded,
              title: 'My Profile',
              subtitle: 'View & edit personal info',
              onTap: () {}),
          _profileItem(
              icon: Icons.settings_outlined,
              title: 'Settings',
              subtitle: 'App preferences & display',
              onTap: () {}),
          _profileItem(
              icon: Icons.shield_outlined,
              title: 'Security',
              subtitle: 'Password & 2FA',
              onTap: () {}),
          _profileItem(
              icon: Icons.help_outline_rounded,
              title: 'Help Center',
              subtitle: 'Support & FAQs',
              onTap: () {}),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              AppSession().clear();
              await FirebaseAuth.instance.signOut();
              if (mounted)
                Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (context) =>
                            const attendance_app_login.LoginScreen()),
                    (route) => false);
            },
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.logout_rounded,
                          color: Color(0xFFEF4444), size: 22)),
                  const SizedBox(width: 16),
                  const Expanded(
                      child: Text('Logout',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFEF4444)))),
                ])),
          ),
        ]),
      ),
    );
  }

  Widget _profileItem(
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return InkWell(
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: const Color(0xFF4B5563), size: 22)),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937))),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF9CA3AF))),
                  ])),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFD1D5DB)),
            ])));
  }

  Widget _buildSpaceTabs() {
    const tabs = ['My Space', 'Team'];
    return Row(
        children: List.generate(tabs.length, (i) {
      final sel = _selectedMainSpace == i;
      return GestureDetector(
        onTap: () => setState(() {
          _selectedMainSpace = i;
          _selectedSubTab = 0;
        }),
        child: Container(
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
              color: sel ? _kPrimaryLight : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: sel ? _kPrimary : const Color(0xFFE5E7EB),
                  width: 1.3)),
          child: Text(tabs[i],
              style: TextStyle(
                  color: sel ? _kPrimary : _kSubText,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ),
      );
    }));
  }

  Widget _buildTeamSubTabs() {
    const tabs = ['Members', 'Feed', 'Announcements', 'Tasks'];
    return Container(
      decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
            children: List.generate(tabs.length, (i) {
          final sel = _selectedSubTab == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedSubTab = i),
            child: Container(
              margin: const EdgeInsets.only(right: 24),
              padding: const EdgeInsets.only(bottom: 11),
              decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color: sel ? _kPrimary : Colors.transparent,
                          width: 2))),
              child: Text(tabs[i],
                  style: TextStyle(
                      color: sel ? _kPrimary : const Color(0xFF9CA3AF),
                      fontWeight: sel ? FontWeight.bold : FontWeight.w600,
                      fontSize: 13)),
            ),
          );
        })),
      ),
    );
  }

  Widget _buildSubTabs() {
    const tabs = ['Dashboard', 'Announcements', 'Calendar'];
    return Container(
      decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
            children: List.generate(tabs.length, (i) {
          final sel = _selectedSubTab == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedSubTab = i),
            child: Container(
              margin: const EdgeInsets.only(right: 24),
              padding: const EdgeInsets.only(bottom: 11),
              decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color: sel ? _kPrimary : Colors.transparent,
                          width: 2))),
              child: Text(tabs[i],
                  style: TextStyle(
                      color: sel ? _kPrimary : const Color(0xFF9CA3AF),
                      fontWeight: sel ? FontWeight.bold : FontWeight.w600,
                      fontSize: 13)),
            ),
          );
        })),
      ),
    );
  }

  Widget _buildOfficeLocationCard() {
    final isInside = _currentLocationData?.isWithinRadius ?? false;
    return Container(
      decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder)),
      child: Column(children: [
        SizedBox(
            height: 130,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
              child: LocationMapCard(
                  officeLat: LocationService.officeLat,
                  officeLng: LocationService.officeLng,
                  allowedRadius: LocationService.allowedRadius,
                  userLocation: _currentLocationData?.latLng,
                  userAddress: _currentLocationData?.address,
                  height: 130),
            )),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Office Location',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kText)),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        color: isInside ? _kGreen : _kRed,
                        shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(isInside ? 'INSIDE OFFICE RANGE' : 'OUTSIDE OFFICE RANGE',
                    style: TextStyle(
                        fontSize: 10,
                        color: isInside ? _kGreen : _kRed,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3)),
              ]),
            ]),
            GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => FullMapScreen(
                          officeLat: LocationService.officeLat,
                          officeLng: LocationService.officeLng,
                          allowedRadius: LocationService.allowedRadius,
                          userLocation: _currentLocationData?.latLng,
                          userAddress: _currentLocationData?.address))),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                    color: _kPrimaryLight,
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: const [
                  Icon(Icons.location_on_outlined, color: _kPrimary, size: 14),
                  SizedBox(width: 4),
                  Text('View Map',
                      style: TextStyle(
                          color: _kPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildAttendanceTodayCard(
      String? status, Timestamp? checkIn, Timestamp? checkOut) {
    final isCheckedIn = status == 'checked_in';
    final isCheckedOut = status == 'checked_out';
    final isPresent = isCheckedIn || isCheckedOut;
    final checkInStr = checkIn != null
        ? DateFormat('hh:mm a').format(checkIn.toDate())
        : '--:-- --';
    final workingStr = _getWorkingDuration(checkIn, checkOut);
    final overtimeStr = _getOvertimeDuration(checkIn, checkOut);

    return Container(
      decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder)),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('ATTENDANCE TODAY',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kSubText,
                    letterSpacing: 0.4)),
            if (isPresent)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kGreen.withValues(alpha: 0.3))),
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.check_circle_rounded, color: _kGreen, size: 13),
                  SizedBox(width: 4),
                  Text('Present',
                      style: TextStyle(
                          fontSize: 11,
                          color: _kGreen,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                isCheckedOut
                    ? 'Checked Out'
                    : isCheckedIn
                        ? 'Checked In'
                        : 'Not Checked In',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: _kText)),
            const SizedBox(height: 2),
            Text('$checkInStr  -  General Shift',
                style: const TextStyle(
                    fontSize: 12,
                    color: _kSubText,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _statPill(checkInStr, 'Check In')),
              const SizedBox(width: 8),
              Expanded(child: _statPill(workingStr, 'Working')),
              const SizedBox(width: 8),
              Expanded(child: _statPill(overtimeStr, 'Overtime')),
            ]),
            const SizedBox(height: 14),
            if (isCheckedOut)
              _outlinedActionBtn(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Shift Complete',
                  color: _kGreen,
                  onTap: null)
            else if (isCheckedIn)
              _outlinedActionBtn(
                  icon: Icons.logout_rounded,
                  label: 'Check Out',
                  color: _kRed,
                  onTap: () => _showCheckOutSheet(checkIn))
            else
              SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _showCheckInSheet,
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: const Text('Check In Now',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                  )),
          ]),
        ),
      ]),
    );
  }

  Widget _statPill(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
          color: const Color(0xFFF6F7FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder)),
      child: Column(children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: _kText),
              textAlign: TextAlign.center),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 10, color: _kSubText, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
        ),
      ]),
    );
  }

  Widget _outlinedActionBtn(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: color.withValues(alpha: 0.4), width: 1.5)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 14, color: color, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _buildTodayShiftCard() {
    final shiftStart = _fmt12(AppSession().shiftStartTime);
    final shiftEnd = _fmt12(AppSession().shiftEndTime);
    final managerName = AppSession().companyName ?? 'Manager';
    final displayManager = managerName.length > 10
        ? '${managerName.substring(0, 9)}...'
        : managerName;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Today's Shift",
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _kText)),
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ShiftDetailsScreen())),
            child: Row(children: const [
              Text('Details',
                  style: TextStyle(
                      fontSize: 12,
                      color: _kPrimary,
                      fontWeight: FontWeight.w700)),
              SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded, color: _kPrimary, size: 16),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                  color: _kPrimaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.access_time_rounded,
                  color: _kPrimary, size: 18)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('General Shift',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kText)),
                const SizedBox(height: 2),
                Text(
                    '$shiftStart  -  $shiftEnd  -  Office',
                    style: const TextStyle(
                        fontSize: 11,
                        color: _kSubText,
                        fontWeight: FontWeight.w500)),
              ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('Manager',
                style: TextStyle(
                    fontSize: 10,
                    color: _kSubText,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(displayManager,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: _kText)),
          ]),
        ]),
      ]),
    );
  }

  Widget _buildAttendanceSummaryCard(List<QueryDocumentSnapshot> records) {
    final now = DateTime.now();
    int totalWorkdays = 0;
    for (int d = 1; d <= now.day; d++) {
      final date = DateTime(now.year, now.month, d);
      if (date.weekday >= 1 && date.weekday <= 5) totalWorkdays++;
    }
    if (totalWorkdays == 0) totalWorkdays = 1;
    int presentCount = 0, lateCount = 0;
    final sParts = AppSession().shiftStartTime.split(':');
    final shiftStartH = int.parse(sParts[0]),
        shiftStartM = int.parse(sParts[1]);
    for (var doc in records) {
      final data = doc.data() as Map<String, dynamic>;
      final checkIn = (data['checkIn'] as Timestamp?)?.toDate();
      if (checkIn != null &&
          checkIn.month == now.month &&
          checkIn.year == now.year &&
          checkIn.weekday >= 1 &&
          checkIn.weekday <= 5) {
        presentCount++;
        final shiftStartDT = DateTime(
            checkIn.year, checkIn.month, checkIn.day, shiftStartH, shiftStartM);
        if (checkIn.isAfter(shiftStartDT
                .add(Duration(minutes: AppSession().gracePeriod))) &&
            data['remarkStatus'] != 'approved') lateCount++;
      }
    }
    final rate = (presentCount / totalWorkdays) * 100.0;
    return _sectionCard(
        title: 'ATTENDANCE SUMMARY',
        actionLabel: 'View All',
        onAction: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const EmployeeAttendanceSummaryScreen())),
        child: Row(children: [
          Expanded(
              child: _summaryBox('$presentCount', 'Present',
                  const Color(0xFFECFDF5), _kGreen)),
          const SizedBox(width: 8),
          Expanded(
              child: _summaryBox(
                  '$lateCount', 'Late', const Color(0xFFFFFBEB), _kYellow)),
          const SizedBox(width: 8),
          Expanded(
              child: _summaryBox('${rate.toStringAsFixed(1)}%', 'Rate',
                  const Color(0xFFEEF2FF), _kPrimary)),
        ]));
  }

  Widget _summaryBox(String value, String label, Color bg, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _buildLeaveSummaryCard(List<QueryDocumentSnapshot> leaveRequests) {
    final now = DateTime.now();
    final int totalPaidLeaves = AppSession().paidLeavesPerYear > 0
        ? AppSession().paidLeavesPerYear
        : 12;
    int usedPaidLeaves = 0, pendingCount = 0, upcomingCount = 0;
    for (var doc in leaveRequests) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['status'] == 'pending') pendingCount++;
      if (data['leaveType'] == 'Paid Leave' && data['status'] == 'approved') {
        final start = (data['fromDate'] as Timestamp?)?.toDate();
        if (start != null && start.year == now.year)
          usedPaidLeaves += (data['durationInDays'] as num?)?.toInt() ?? 0;
      }
      if (data['status'] == 'approved') {
        final start = (data['fromDate'] as Timestamp?)?.toDate();
        if (start != null && start.isAfter(now)) upcomingCount++;
      }
    }
    final int leaveBalance =
        (totalPaidLeaves - usedPaidLeaves).clamp(0, totalPaidLeaves);
    final double leaveProgress = totalPaidLeaves > 0
        ? (leaveBalance / totalPaidLeaves).clamp(0.0, 1.0)
        : 0.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('LEAVE SUMMARY',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kSubText,
                  letterSpacing: 0.4)),
          GestureDetector(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const EmployeeLeaveSummaryScreen())),
            child: Row(children: const [
              Text('View All',
                  style: TextStyle(
                      fontSize: 12,
                      color: _kPrimary,
                      fontWeight: FontWeight.w700)),
              SizedBox(width: 2),
              Icon(Icons.arrow_forward_rounded, color: _kPrimary, size: 14)
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
              child: _leaveSummaryItem('$leaveBalance', 'Balance',
                  const Color(0xFFECFDF5), _kGreen)),
          const SizedBox(width: 8),
          Expanded(
              child: _leaveSummaryItem('$pendingCount', 'Pending',
                  const Color(0xFFFFFBEB), _kYellow)),
          const SizedBox(width: 8),
          Expanded(
              child: _leaveSummaryItem('$upcomingCount', 'Upcoming',
                  const Color(0xFFF5F3FF), const Color(0xFF8B5CF6))),
        ]),
        const SizedBox(height: 14),
        ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
                value: leaveProgress,
                backgroundColor: const Color(0xFFE5E7EB),
                color: _kGreen,
                minHeight: 5)),
      ]),
    );
  }

  Widget _leaveSummaryItem(String value, String label, Color bg, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _buildActiveTasksCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('organizations')
          .doc(FirestoreService.companyId)
          .collection('tasks')
          .where('assignedTo', isEqualTo: user?.email)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        final tasks = snapshot.data?.docs ?? [];
        final List<Map<String, dynamic>> displayTasks = tasks.isEmpty
            ? [
                {
                  'title': 'Wireframe Review',
                  'due': 'Today, 6 PM',
                  'badge': 'New',
                  'badgeColor': _kPrimary,
                  'dot': _kRed
                },
                {
                  'title': 'Submit Sprint Report',
                  'due': 'Today, 5 PM',
                  'badge': 'Due Today',
                  'badgeColor': _kYellow,
                  'dot': _kRed
                },
                {
                  'title': 'User Testing Prep',
                  'due': 'Jul 27',
                  'badge': 'Overdue',
                  'badgeColor': _kRed,
                  'dot': _kYellow
                },
              ]
            : tasks.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
                final isOverdue =
                    dueDate != null && dueDate.isBefore(DateTime.now());
                final isDueToday = dueDate != null &&
                    dueDate.year == DateTime.now().year &&
                    dueDate.month == DateTime.now().month &&
                    dueDate.day == DateTime.now().day;
                return {
                  'title': data['title'] ?? 'Task',
                  'due': dueDate != null
                      ? DateFormat('MMM d').format(dueDate)
                      : 'No due',
                  'badge': isOverdue
                      ? 'Overdue'
                      : isDueToday
                          ? 'Due Today'
                          : data['status'] ?? 'New',
                  'badgeColor': isOverdue
                      ? _kRed
                      : isDueToday
                          ? _kYellow
                          : _kPrimary,
                  'dot': isOverdue ? _kYellow : _kRed,
                };
              }).toList();
        return _sectionCard(
          title: 'ACTIVE TASKS',
          actionLabel: 'View All',
          onAction: () {},
          child: Column(
              children: displayTasks
                  .map((task) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(children: [
                          Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: task['dot'] as Color,
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(task['title'],
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _kText)),
                                const SizedBox(height: 2),
                                Text('Due: ${task['due']}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: _kSubText,
                                        fontWeight: FontWeight.w500)),
                              ])),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: (task['badgeColor'] as Color)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: (task['badgeColor'] as Color)
                                        .withValues(alpha: 0.3))),
                            child: Text(task['badge'],
                                style: TextStyle(
                                    fontSize: 10,
                                    color: task['badgeColor'] as Color,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ]),
                      ))
                  .toList()),
        );
      },
    );
  }

  Widget _buildPendingRequestsCard() {
    final userEmail = user?.email ?? '';
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('organizations')
          .doc(FirestoreService.companyId)
          .collection('leave_requests')
          .where('userId', isEqualTo: AppSession().uid)
          .where('status', isEqualTo: 'pending')
          .limit(5)
          .snapshots(),
      builder: (context, leaveSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('organizations')
              .doc(FirestoreService.companyId)
              .collection('attendance_corrections')
              .where('userId', isEqualTo: AppSession().uid)
              .where('status', isEqualTo: 'pending')
              .limit(3)
              .snapshots(),
          builder: (context, corrSnap) {
            final List<Map<String, dynamic>> requests = [];
            for (var doc in corrSnap.data?.docs ?? []) {
              final data = doc.data() as Map<String, dynamic>;
              final date = (data['date'] as Timestamp?)?.toDate();
              requests.add({
                'icon': Icons.access_time_outlined,
                'title': 'Attendance Correction',
                'subtitle': date != null
                    ? '${DateFormat('MMM d').format(date)}  -  Pending approval'
                    : 'Pending approval'
              });
            }
            for (var doc in leaveSnap.data?.docs ?? []) {
              final data = doc.data() as Map<String, dynamic>;
              final from = (data['fromDate'] as Timestamp?)?.toDate();
              final days = data['durationInDays'] ?? '';
              requests.add({
                'icon': Icons.calendar_today_outlined,
                'title': 'Leave Request',
                'subtitle': from != null
                    ? '${DateFormat('MMM d').format(from)}  -  $days days'
                    : 'Pending'
              });
            }
            if (requests.isEmpty) {
              requests.addAll([
                {
                  'icon': Icons.access_time_outlined,
                  'title': 'Attendance Correction',
                  'subtitle': 'Jul 25  -  Pending approval'
                },
                {
                  'icon': Icons.calendar_today_outlined,
                  'title': 'Leave Request',
                  'subtitle': 'Aug 2-3  -  2 days'
                },
                {
                  'icon': Icons.laptop_mac_outlined,
                  'title': 'Work From Home',
                  'subtitle': 'Jul 30  -  Pending approval'
                },
              ]);
            }
            return _sectionCard(
              title: 'PENDING REQUESTS',
              actionLabel: 'View All',
              onAction: () {},
              child: Column(
                  children: requests
                      .map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(children: [
                              Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Icon(r['icon'] as IconData,
                                      size: 18, color: _kSubText)),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(r['title'],
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: _kText)),
                                    const SizedBox(height: 2),
                                    Text(r['subtitle'],
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: _kSubText,
                                            fontWeight: FontWeight.w500)),
                                  ])),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color:
                                            _kYellow.withValues(alpha: 0.4))),
                                child: const Text('Pending',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: _kYellow,
                                        fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.chevron_right_rounded,
                                  color: Color(0xFFD1D5DB), size: 18),
                            ]),
                          ))
                      .toList()),
            );
          },
        );
      },
    );
  }

  Widget _buildRecentAnnouncementsCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('organizations')
          .doc(FirestoreService.companyId)
          .collection('announcements')
          .orderBy('createdAt', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final List<Map<String, dynamic>> anns = docs.isEmpty
            ? [
                {
                  'tag': 'Policy',
                  'tagColor': _kPrimary,
                  'ago': '2 days ago',
                  'title': 'Policy Update',
                  'body':
                      'Work From Office policy updated effective 1 Aug 2026.'
                },
                {
                  'tag': 'HR',
                  'tagColor': _kGreen,
                  'ago': 'Yesterday',
                  'title': 'WFO Reminder',
                  'body':
                      'All employees must report Mon-Thu. WFH on Fridays.'
                },
              ]
            : docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final created = (data['createdAt'] as Timestamp?)?.toDate();
                String ago = '';
                if (created != null) {
                  final diff = DateTime.now().difference(created);
                  ago = diff.inDays == 0
                      ? 'Today'
                      : diff.inDays == 1
                          ? 'Yesterday'
                          : '${diff.inDays} days ago';
                }
                return {
                  'tag': data['category'] ?? 'General',
                  'tagColor': _kPrimary,
                  'ago': ago,
                  'title': data['title'] ?? '${AppSession().shiftStartTime} - ${AppSession().shiftEndTime}',
                  'body': data['body'] ?? data['message'] ?? ''
                };
              }).toList();

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('RECENT ANNOUNCEMENTS',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kSubText,
                      letterSpacing: 0.4)),
              Row(children: const [
                Text('View All',
                    style: TextStyle(
                        fontSize: 12,
                        color: _kPrimary,
                        fontWeight: FontWeight.w700)),
                SizedBox(width: 2),
                Icon(Icons.arrow_forward_rounded, color: _kPrimary, size: 14)
              ]),
            ]),
            const SizedBox(height: 14),
            ...anns.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                    color: (a['tagColor'] as Color)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6)),
                                child: Text(a['tag'],
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: a['tagColor'] as Color,
                                        fontWeight: FontWeight.w700))),
                            Text(a['ago'],
                                style: const TextStyle(
                                    fontSize: 11, color: _kSubText)),
                          ]),
                      const SizedBox(height: 6),
                      Text(a['title'],
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _kText)),
                      const SizedBox(height: 3),
                      Text(a['body'],
                          style: const TextStyle(
                              fontSize: 12, color: _kSubText, height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ]))),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF6F7FB),
                  borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('View All Announcements',
                        style: TextStyle(
                            fontSize: 13,
                            color: _kPrimary,
                            fontWeight: FontWeight.w700)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded,
                        color: _kPrimary, size: 14),
                  ]),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildUpcomingHolidaysCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('organizations')
          .doc(FirestoreService.companyId)
          .collection('company_calendar')
          .snapshots(),
      builder: (context, snap) {
        final now = DateTime.now();
        List<Map<String, dynamic>> holidays = [];
        if (snap.hasData) {
          final sorted = snap.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['date'] == null) return false;
            final date = (data['date'] as Timestamp).toDate();
            return date.isAfter(now) ||
                (date.year == now.year &&
                    date.month == now.month &&
                    date.day == now.day);
          }).toList()
            ..sort((a, b) => ((a.data() as Map)['date'] as Timestamp)
                .toDate()
                .compareTo(((b.data() as Map)['date'] as Timestamp).toDate()));
          holidays = sorted.take(3).map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final date = (data['date'] as Timestamp).toDate();
            final diff =
                date.difference(DateTime(now.year, now.month, now.day)).inDays;
            return {
              'day': DateFormat('d').format(date),
              'month': DateFormat('MMM').format(date).toUpperCase(),
              'name': data['reason'] ?? 'Holiday',
              'subtitle':
                  '${DateFormat('EEEE').format(date)}  -  ${diff == 0 ? 'Today' : '$diff days away'}',
              'type': data['type'] ?? 'National',
            };
          }).toList();
        }
        if (holidays.isEmpty) {
          holidays = [
            {
              'day': '15',
              'month': 'AUG',
              'name': 'Independence Day',
              'subtitle':
                  'Saturday  -  18 days away',
              'type': 'National'
            },
            {
              'day': '27',
              'month': 'AUG',
              'name': 'Ganesh Chaturthi',
              'subtitle':
                  'Wednesday  -  30 days away',
              'type': 'Regional'
            },
          ];
        }
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder)),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('UPCOMING HOLIDAYS',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kSubText,
                      letterSpacing: 0.4)),
              Row(children: const [
                Text('Calendar',
                    style: TextStyle(
                        fontSize: 12,
                        color: _kPrimary,
                        fontWeight: FontWeight.w700)),
                SizedBox(width: 4),
                Icon(Icons.calendar_month_outlined, color: _kPrimary, size: 14)
              ]),
            ]),
            const SizedBox(height: 12),
            ...holidays.map((h) {
              final isNational =
                  (h['type'] as String).toLowerCase() == 'national';
              final typeColor = isNational ? _kPrimary : _kGreen;
              return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Container(
                        width: 46,
                        height: 50,
                        decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(h['month'],
                                  style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: _kSubText)),
                              Text(h['day'],
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: _kText,
                                      height: 1.2)),
                            ])),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(h['name'],
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _kText)),
                          const SizedBox(height: 2),
                          Text(h['subtitle'],
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: _kSubText,
                                  fontWeight: FontWeight.w500)),
                        ])),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: typeColor.withValues(alpha: 0.25))),
                      child: Text(h['type'],
                          style: TextStyle(
                              fontSize: 11,
                              color: typeColor,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFFD1D5DB), size: 18),
                  ]));
            }),
          ]),
        );
      },
    );
  }

  Widget _sectionCard(
      {required String title,
      required String actionLabel,
      required VoidCallback onAction,
      required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kSubText,
                  letterSpacing: 0.4)),
          GestureDetector(
              onTap: onAction,
              child: Row(children: [
                Text(actionLabel,
                    style: const TextStyle(
                        fontSize: 12,
                        color: _kPrimary,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_forward_rounded,
                    color: _kPrimary, size: 14),
              ])),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}

class ShiftDetailsScreen extends StatelessWidget {
  const ShiftDetailsScreen({super.key});
  String _fmt12(String hhmm) {
    try {
      final parts = hhmm.split(':');
      return DateFormat('hh:mm a').format(
          DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1])));
    } catch (_) {
      return hhmm;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shiftStart = _fmt12(AppSession().shiftStartTime);
    final shiftEnd = _fmt12(AppSession().shiftEndTime);
    final grace = AppSession().gracePeriod;
    final managerName = AppSession().companyName ?? 'Sarah Mitchell';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
        title: const Text('Shift Details',
            style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: const Color(0xFF5C5CFF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'General Shift',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$shiftStart  -  $shiftEnd',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
              ),
              child: Column(
                children: [
                  _buildListTile('Work Mode', 'Office'),
                  _buildDivider(),
                  _buildListTile('Shift Type', 'Fixed'),
                  _buildDivider(),
                  _buildListTile('Grace Period', '$grace minutes'),
                  _buildDivider(),
                  _buildListTile('Break', '1 hour'),
                  _buildDivider(),
                  _buildListTile('Manager', managerName),
                  _buildDivider(),
                  _buildListTile('Department', 'Design'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF111827),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0xFFF3F4F6),
      indent: 24,
      endIndent: 24,
    );
  }
}


