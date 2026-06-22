import 'dart:async';
import 'package:flutter/material.dart';
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
import 'package:attendance_app/screens/employee/attendance_tab.dart';
import 'package:attendance_app/screens/employee/leave_tab.dart';
import 'package:attendance_app/utils/notification_helper.dart';
import 'package:attendance_app/utils/notification_service.dart';

// ─── Primary Brand Color ───────────────────────────────────────────────
const _kPrimary = Color(0xFF5C5CFF);
const _kPrimaryLight = Color(0xFFEEEEFF);
const _kBg = Color(0xFFF6F7FB);
const _kCard = Colors.white;
const _kText = Color(0xFF111827);
const _kSubText = Color(0xFF6B7280);
const _kBorder = Color(0xFFEEEFF3);

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

  int _selectedMainSpace = 0; // 0=My Space, 1=Team, 2=Organization
  int _selectedSubTab = 0;    // 0=Dashboard, 1=Announcement, 2=Attendance, 3=Leave

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
      if (mounted && data.position != null) {
        setState(() => _currentLocationData = data);
      }
    });
  }

  // ─── Format 24h → 12h AM/PM ──────────────────────────────────────────
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

  // ─── Stopwatch text ──────────────────────────────────────────────────
  String _getStopwatchText(Timestamp? checkIn, Timestamp? checkOut) {
    if (checkIn == null) return '0m 00s';
    final start = checkIn.toDate();
    final end = checkOut?.toDate() ?? DateTime.now();
    final diff = end.difference(start);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    final seconds = diff.inSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  // ─── Initials ────────────────────────────────────────────────────────
  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'EM';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  // ─── Next Holiday ────────────────────────────────────────────────────
  Map<String, String> _getNextHoliday() {
    final now = DateTime.now();
    final holidays = [
      {'name': 'New Year\'s Day', 'date': DateTime(now.year, 1, 1)},
      {'name': 'Republic Day', 'date': DateTime(now.year, 1, 26)},
      {'name': 'Independence', 'date': DateTime(now.year, 8, 15)},
      {'name': 'Gandhi Jayanti', 'date': DateTime(now.year, 10, 2)},
      {'name': 'Christmas', 'date': DateTime(now.year, 12, 25)},
    ];
    DateTime? nextDate;
    String nextName = '';
    for (var h in holidays) {
      final date = h['date'] as DateTime;
      if (date.isAfter(now) ||
          (date.year == now.year &&
              date.month == now.month &&
              date.day == now.day)) {
        if (nextDate == null || date.isBefore(nextDate)) {
          nextDate = date;
          nextName = h['name'] as String;
        }
      }
    }
    if (nextDate == null) {
      nextDate = DateTime(now.year + 1, 1, 1);
      nextName = 'New Year\'s Day';
    }
    final diffDays =
        nextDate.difference(DateTime(now.year, now.month, now.day)).inDays;
    final weeks = (diffDays / 7).ceil();
    final dateFormatted = DateFormat('MMM dd').format(nextDate);
    return {
      'name': nextName,
      'sub': '$dateFormatted · $weeks weeks away',
    };
  }

  // ─── Check-In/Out Logic ──────────────────────────────────────────────
  Future<void> _handleCheckInOut(String status, bool isCheckIn) async {
    if (_isCheckingInOut) return;
    setState(() => _isCheckingInOut = true);
    try {
      final now = DateTime.now();
      final userEmail = user?.email ?? '';
      final isInside = _currentLocationData?.isWithinRadius ?? false;
      final mode = isInside ? 'office' : 'wfh';

      final data = {
        'companyId': FirestoreService.companyId,
        'userId': userEmail,
        'status': status,
        if (isCheckIn) 'workMode': mode,
        if (isCheckIn) 'checkIn': Timestamp.fromDate(now),
        if (isCheckIn)
          'checkInLocation': _currentLocationData?.address ?? 'Unknown Location',
        if (!isCheckIn) 'checkOut': Timestamp.fromDate(now),
        if (!isCheckIn)
          'checkOutLocation':
              _currentLocationData?.address ?? 'Unknown Location',
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
          final startH = int.parse(sParts[0]);
          final startM = int.parse(sParts[1]);
          final endH = int.parse(eParts[0]);
          final endM = int.parse(eParts[1]);
          final standardDuration = Duration(hours: endH, minutes: endM) -
              Duration(hours: startH, minutes: startM);
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
        title: isCheckIn ? 'Check-In Successful ✅' : 'Check-Out Successful 👋',
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

      if (mounted) _showSuccessModal(isCheckIn ? 'Check In' : 'Check Out', now);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: AppTheme.danger));
      }
    } finally {
      if (mounted) setState(() => _isCheckingInOut = false);
    }
  }

  // ─── Success Modal ────────────────────────────────────────────────────
  void _showSuccessModal(String title, DateTime time) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => ElasticIn(
        child: Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                Text(
                  'Time: ${DateFormat('hh:mm:ss a').format(time)}',
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Okay',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Check-In Confirmation Bottom Sheet (Image 2) ─────────────────────
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
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Clock icon circle
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: _kPrimaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.access_time_rounded,
                        color: _kPrimary, size: 34),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  const Text(
                    'Confirm Check-In',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _kText,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'You\'re about to start your work session for today.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: _kSubText,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Info row 1 – Shift
                  _sheetInfoRow(
                    bgColor: const Color(0xFFEEEEFF),
                    icon: Icons.access_time_rounded,
                    iconColor: _kPrimary,
                    label: 'Shift',
                    value: 'General Shift · $shiftStart – $shiftEnd',
                  ),
                  const SizedBox(height: 10),

                  // Info row 2 – Location
                  _sheetInfoRow(
                    bgColor: const Color(0xFFECFDF5),
                    icon: Icons.location_on_rounded,
                    iconColor: const Color(0xFF10B981),
                    label: 'Location',
                    value: isInside
                        ? 'Headquarters · Verified ✓'
                        : 'Outside Office Range',
                  ),
                  const SizedBox(height: 10),

                  // Info row 3 – Late Buffer
                  _sheetInfoRow(
                    bgColor: const Color(0xFFFFFBEB),
                    icon: Icons.timer_outlined,
                    iconColor: const Color(0xFFD97706),
                    label: 'Late Buffer',
                    value: '$grace minutes grace period',
                  ),
                  const SizedBox(height: 28),

                  // Check In Now button
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
                      elevation: 0,
                    ),
                    child: _isCheckingInOut
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : const Text(
                            'Check In Now',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                  const SizedBox(height: 14),

                  // Cancel
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        color: _kSubText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sheetInfoRow({
    required Color bgColor,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: iconColor.withValues(alpha: 0.85),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: _kText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: _kPrimary)));
    }

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
            final record =
                todaySnap.data?.data() as Map<String, dynamic>?;
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── 1. HEADER ───────────────────────
                                _buildHeader(fullName, initials),
                                const SizedBox(height: 18),

                                // ── 2. SPACE TABS ────────────────────
                                _buildSpaceTabs(),
                                const SizedBox(height: 14),

                                // ── 3. SUB TABS ───────────────────────
                                _buildSubTabs(),
                                const SizedBox(height: 16),

                                // ── 4. CONTENT ────────────────────────
                                if (_selectedSubTab == 0) ...[
                                  _buildOfficeLocationCard(),
                                  const SizedBox(height: 14),
                                  _buildTodayAttendanceCard(
                                      status, checkInTime, checkOutTime),
                                  const SizedBox(height: 14),
                                  _buildThisWeekCard(records),
                                  const SizedBox(height: 14),
                                  _buildTodayShiftCard(),
                                  const SizedBox(height: 14),
                                  _buildSplitStatsRow(leaveDocs),
                                  const SizedBox(height: 14),
                                  _buildThisMonthCard(records),
                                ] else if (_selectedSubTab == 2) ...[
                                  const SizedBox(
                                    height: 500,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(16)),
                                      child: EmployeeAttendanceTab(),
                                    ),
                                  ),
                                ] else if (_selectedSubTab == 3) ...[
                                  const SizedBox(
                                    height: 600,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(16)),
                                      child: EmployeeLeaveTab(),
                                    ),
                                  ),
                                ] else ...[
                                  _buildPlaceholderView(),
                                ],
                                const SizedBox(height: 100),
                              ],
                            ),
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

  // ════════════════════════════════════════════════════════════════════
  //  SECTION BUILDERS
  // ════════════════════════════════════════════════════════════════════

  // ── Header ─────────────────────────────────────────────────────────
  Widget _buildHeader(String fullName, String initials) {
    final hour = DateTime.now().hour;
    String greeting = 'Good morning 🌅';
    if (hour >= 12 && hour < 17) greeting = 'Good afternoon ☀️';
    if (hour >= 17) greeting = 'Good evening 🌙';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greeting,
              style: const TextStyle(
                fontSize: 13,
                color: _kSubText,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              fullName,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: _kText,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        Row(
          children: [
            _iconBtn(Icons.search_rounded,
                onTap: () {}),
            const SizedBox(width: 8),
            Stack(
              children: [
                _iconBtn(Icons.notifications_none_rounded, onTap: () {}),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _selectedSubTab = 4),
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: _kPrimary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _iconBtn(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder, width: 1),
        ),
        child: Icon(icon, color: const Color(0xFF4B5563), size: 20),
      ),
    );
  }

  // ── Space Tabs ──────────────────────────────────────────────────────
  Widget _buildSpaceTabs() {
    final tabs = ['My Space', 'Team', 'Organization'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final sel = _selectedMainSpace == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedMainSpace = i),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? _kPrimaryLight : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel ? _kPrimary : Colors.transparent,
                  width: 1.3,
                ),
              ),
              child: Text(
                tabs[i],
                style: TextStyle(
                  color: sel ? _kPrimary : _kSubText,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Sub Tabs ────────────────────────────────────────────────────────
  Widget _buildSubTabs() {
    final tabs = ['Dashboard', 'Announcement', 'Attendance', 'Leave'];
    return Container(
      decoration: const BoxDecoration(
        border:
            Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
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
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  tabs[i],
                  style: TextStyle(
                    color: sel ? _kPrimary : const Color(0xFF9CA3AF),
                    fontWeight:
                        sel ? FontWeight.bold : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── Office Location Card ────────────────────────────────────────────
  Widget _buildOfficeLocationCard() {
    final isInside = _currentLocationData?.isWithinRadius ?? false;
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder, width: 1.1),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(19)),
              child: LocationMapCard(
                officeLat: LocationService.officeLat,
                officeLng: LocationService.officeLng,
                allowedRadius: LocationService.allowedRadius,
                userLocation: _currentLocationData?.latLng,
                userAddress: _currentLocationData?.address,
                height: 120,
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Office Location',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _kText,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: isInside
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isInside
                              ? 'INSIDE OFFICE RANGE'
                              : 'OUTSIDE OFFICE RANGE',
                          style: TextStyle(
                            fontSize: 10,
                            color: isInside
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _FullMapScreen(
                          officeLat: LocationService.officeLat,
                          officeLng: LocationService.officeLng,
                          allowedRadius: LocationService.allowedRadius,
                          userLocation: _currentLocationData?.latLng,
                          userAddress: _currentLocationData?.address,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _kPrimaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'View Map',
                      style: TextStyle(
                        color: _kPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
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

  // ── Today's Attendance Card ─────────────────────────────────────────
  Widget _buildTodayAttendanceCard(
      String? status, Timestamp? checkIn, Timestamp? checkOut) {
    final isCheckedIn = status == 'checked_in';
    final isCheckedOut = status == 'checked_out';

    String statusLabel = 'Not Checked In';
    if (isCheckedIn) statusLabel = 'Checked In';
    if (isCheckedOut) statusLabel = 'Checked Out';

    final stopwatchText = _getStopwatchText(checkIn, checkOut);
    final shiftStart = _fmt12(AppSession().shiftStartTime);
    final shiftEnd = _fmt12(AppSession().shiftEndTime);
    final grace = AppSession().gracePeriod;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder, width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: label + stopwatch
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
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    statusLabel,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: _kText,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              Text(
                stopwatchText,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _kText,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Shift boxes row
          Row(
            children: [
              Expanded(
                child: _shiftBox(
                  label: 'Shift Start',
                  value: shiftStart,
                  bg: const Color(0xFFF9FAFB),
                  textColor: _kText,
                  labelColor: const Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _shiftBox(
                  label: 'Shift End',
                  value: shiftEnd,
                  bg: const Color(0xFFF9FAFB),
                  textColor: _kText,
                  labelColor: const Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _shiftBox(
                  label: 'Late Buffer',
                  value: '$grace min',
                  bg: const Color(0xFFFFFBEB),
                  textColor: const Color(0xFFD97706),
                  labelColor: const Color(0xFFD97706),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action button
          if (isCheckedOut)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Color(0xFF10B981), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'ATTENDANCE COMPLETED TODAY',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            )
          else if (isCheckedIn)
            ElevatedButton(
              onPressed: _isCheckingInOut
                  ? null
                  : () => _handleCheckInOut('checked_out', false),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isCheckingInOut
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Text(
                      'Check Out Now',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
            )
          else
            ElevatedButton(
              onPressed: _showCheckInSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text(
                'Check In Now',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
            ),
        ],
      ),
    );
  }

  Widget _shiftBox({
    required String label,
    required String value,
    required Color bg,
    required Color textColor,
    required Color labelColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: labelColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // ── This Week Card ──────────────────────────────────────────────────
  Widget _buildThisWeekCard(List<QueryDocumentSnapshot> records) {
    final now = DateTime.now();
    final weekday = now.weekday;
    final monday = now.subtract(Duration(days: weekday - 1));

    int presentDays = 0;
    int elapsedWorkdays = 0;
    final dayWidgets = <Widget>[];
    final dayNames = ['M', 'T', 'W', 'T', 'F'];

    final sParts = AppSession().shiftStartTime.split(':');
    final shiftStartH = int.parse(sParts[0]);
    final shiftStartM = int.parse(sParts[1]);

    for (int i = 0; i < 5; i++) {
      final dayDate = monday.add(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(dayDate);
      final isToday = (dayDate.year == now.year &&
          dayDate.month == now.month &&
          dayDate.day == now.day);
      final isFuture = dayDate.isAfter(now) && !isToday;

      if (!isFuture) elapsedWorkdays++;

      final recordDoc =
          records.where((doc) => doc.id == dateStr).firstOrNull;
      final hasRecord = recordDoc != null;

      Widget circleWidget;
      String hoursStr = '-';

      if (isFuture) {
        circleWidget = _weekSquare(
          child: const Text('–',
              style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w600,
                  fontSize: 16)),
          bg: const Color(0xFFF3F4F6),
          border: const Color(0xFFE5E7EB),
        );
        hoursStr = '–';
      } else if (hasRecord) {
        final data = recordDoc.data() as Map<String, dynamic>;
        final checkIn = (data['checkIn'] as Timestamp?)?.toDate();
        final checkOut = (data['checkOut'] as Timestamp?)?.toDate();

        if (checkIn != null) {
          final shiftStartDT = DateTime(
              checkIn.year, checkIn.month, checkIn.day, shiftStartH, shiftStartM);
          final graceLimit =
              shiftStartDT.add(Duration(minutes: AppSession().gracePeriod));
          final isLate =
              checkIn.isAfter(graceLimit) && data['remarkStatus'] != 'approved';

          if (isLate) {
            circleWidget = _weekSquare(
              child: const Text('L',
                  style: TextStyle(
                      color: Color(0xFFD97706),
                      fontWeight: FontWeight.bold,
                      fontSize: 20)),
              bg: const Color(0xFFFFFBEB),
              border: const Color(0xFFD97706),
            );
          } else {
            circleWidget = _weekSquare(
              child: const Icon(Icons.check_rounded,
                  color: Color(0xFF10B981), size: 26),
              bg: const Color(0xFFECFDF5),
            );
          }
          presentDays++;

          if (checkOut != null) {
            final diff = checkOut.difference(checkIn).inMinutes / 60.0;
            hoursStr = '${diff.toStringAsFixed(1)}h';
          } else if (isToday) {
            final diff =
                DateTime.now().difference(checkIn).inMinutes / 60.0;
            hoursStr = '${diff.toStringAsFixed(1)}h';
          }
        } else {
          circleWidget = _absentCircle();
          hoursStr = '0.0h';
        }
      } else {
        if (isToday) {
          circleWidget = _weekSquare(
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
            ),
            bg: _kPrimary,
          );
          hoursStr = '–';
        } else {
          circleWidget = _absentCircle();
          hoursStr = '–';
        }
      }

dayWidgets.add(
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                dayNames[i],
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2),
              ),
              const SizedBox(height: 10),
              circleWidget,
              const SizedBox(height: 8),
              Text(
                hoursStr,
                style: const TextStyle(
                    fontSize: 11,
                    color: _kSubText,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    final rate =
        elapsedWorkdays > 0 ? (presentDays / elapsedWorkdays) * 100 : 100.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder, width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('This Week',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _kText)),
              Text(
                '↗ ${rate.toStringAsFixed(0)}% attendance',
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          IntrinsicHeight(
            child: Row(
              children: dayWidgets,
            ),
          ),
        ],
      ),
    );
  }

  // Rounded square (squircle) for week day indicators
  Widget _weekSquare({
    required Widget child,
    required Color bg,
    Color? border,
  }) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: border != null
            ? Border.all(color: border, width: 1.5)
            : null,
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  // Keep _weekCircle for backward compat (unused now)
  Widget _weekCircle({
    required Widget child,
    required Color bg,
    Color? border,
  }) {
    return _weekSquare(child: child, bg: bg, border: border);
  }

  Widget _absentCircle() {
    return _weekSquare(
      child: const Icon(Icons.close_rounded,
          color: Color(0xFFEF4444), size: 20),
      bg: const Color(0xFFFDE8E8),
    );
  }

  // ── Today's Shift Card ──────────────────────────────────────────────
  Widget _buildTodayShiftCard() {
    final managerName = AppSession().companyName ?? 'Manager';
    final displayManager =
        managerName.length > 12 ? '${managerName.substring(0, 10)}...' : managerName;
    final shiftStart = _fmt12(AppSession().shiftStartTime);
    final shiftEnd = _fmt12(AppSession().shiftEndTime);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder, width: 1.1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Today\'s Shift',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _kText),
              ),
              GestureDetector(
                onTap: () => setState(() => _selectedSubTab = 2),
                child: const Text(
                  'Details',
                  style: TextStyle(
                      fontSize: 12,
                      color: _kPrimary,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: _kPrimaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.access_time_rounded,
                    color: _kPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'General Shift',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _kText),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$shiftStart – $shiftEnd · Office',
                      style: const TextStyle(
                          fontSize: 11,
                          color: _kSubText,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Manager',
                    style: TextStyle(
                        fontSize: 9,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayManager,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _kText),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Split Stats Row (Leave Balance + Next Holiday) ──────────────────
  Widget _buildSplitStatsRow(List<QueryDocumentSnapshot> leaveRequests) {
    final int totalPaidLeaves =
        AppSession().paidLeavesPerYear > 0 ? AppSession().paidLeavesPerYear : 12;
    int usedPaidLeaves = 0;
    final now = DateTime.now();

    for (var doc in leaveRequests) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['leaveType'] == 'Paid Leave' && data['status'] == 'approved') {
        final start = (data['fromDate'] as Timestamp?)?.toDate();
        if (start != null && start.year == now.year) {
          usedPaidLeaves += (data['durationInDays'] as num?)?.toInt() ?? 0;
        }
      }
    }

    final int leaveBalance =
        (totalPaidLeaves - usedPaidLeaves).clamp(0, totalPaidLeaves);
    final double leaveProgress =
        totalPaidLeaves > 0 ? (leaveBalance / totalPaidLeaves).clamp(0.0, 1.0) : 0.0;

    final holiday = _getNextHoliday();

    return Row(
      children: [
        // Leave Balance card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            height: 120,
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kBorder, width: 1.1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Leave Balance',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('$leaveBalance days',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _kText)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Annual leave',
                        style: TextStyle(
                            fontSize: 11,
                            color: _kSubText,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: leaveProgress,
                        backgroundColor: const Color(0xFFEEEEFF),
                        color: const Color(0xFF10B981),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Next Holiday card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            height: 120,
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kBorder, width: 1.1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Next Holiday',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text(
                      holiday['name']!,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _kText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                Text(
                  holiday['sub']!,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── This Month Card ─────────────────────────────────────────────────
  Widget _buildThisMonthCard(List<QueryDocumentSnapshot> records) {
    final now = DateTime.now();

    int totalWorkdays = 0;
    for (int d = 1; d <= now.day; d++) {
      final date = DateTime(now.year, now.month, d);
      if (date.weekday >= 1 && date.weekday <= 5) totalWorkdays++;
    }
    if (totalWorkdays == 0) totalWorkdays = 1;

    int presentCount = 0;
    int lateCount = 0;

    final sParts = AppSession().shiftStartTime.split(':');
    final shiftStartH = int.parse(sParts[0]);
    final shiftStartM = int.parse(sParts[1]);

    for (var doc in records) {
      final data = doc.data() as Map<String, dynamic>;
      final checkIn = (data['checkIn'] as Timestamp?)?.toDate();
      if (checkIn != null &&
          checkIn.month == now.month &&
          checkIn.year == now.year) {
        if (checkIn.weekday >= 1 && checkIn.weekday <= 5) {
          presentCount++;
          final shiftStartDT = DateTime(
              checkIn.year, checkIn.month, checkIn.day, shiftStartH, shiftStartM);
          final graceLimit =
              shiftStartDT.add(Duration(minutes: AppSession().gracePeriod));
          if (checkIn.isAfter(graceLimit) &&
              data['remarkStatus'] != 'approved') {
            lateCount++;
          }
        }
      }
    }

    final absentCount = (totalWorkdays - presentCount).clamp(0, totalWorkdays);
    final double rate = (presentCount / totalWorkdays) * 100.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder, width: 1.1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('This Month',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _kText)),
              Text(
                '↗ ${rate.toStringAsFixed(1)}%',
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _monthBox(
                      '$presentCount', 'Present',
                      const Color(0xFFECFDF5), const Color(0xFF10B981))),
              const SizedBox(width: 8),
              Expanded(
                  child: _monthBox('$lateCount', 'Late',
                      const Color(0xFFFFFBEB), const Color(0xFFF59E0B))),
              const SizedBox(width: 8),
              Expanded(
                  child: _monthBox('$absentCount', 'Absent',
                      const Color(0xFFFEF2F2), const Color(0xFFEF4444))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _monthBox(String count, String label, Color bg, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(count,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color.withValues(alpha: 0.8),
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPlaceholderView() {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder, width: 1.1),
      ),
      alignment: Alignment.center,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.layers_clear_rounded, size: 48, color: Color(0xFFD1D5DB)),
          SizedBox(height: 12),
          Text(
            'Coming soon',
            style: TextStyle(
                fontSize: 14,
                color: _kSubText,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ─── Full Map Sub-Screen ───────────────────────────────────────────────

class _FullMapScreen extends StatelessWidget {
  final double officeLat;
  final double officeLng;
  final double allowedRadius;
  final LatLng? userLocation;
  final String? userAddress;

  const _FullMapScreen({
    required this.officeLat,
    required this.officeLng,
    required this.allowedRadius,
    this.userLocation,
    this.userAddress,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 16, top: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back,
                color: Color(0xFF111827), size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: Stack(
        children: [
          LocationMapCard(
            officeLat: officeLat,
            officeLng: officeLng,
            allowedRadius: allowedRadius,
            userLocation: userLocation,
            userAddress: userAddress,
          ),
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: FadeInUp(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                          color: _kPrimaryLight, shape: BoxShape.circle),
                      child: const Icon(Icons.location_on,
                          color: _kPrimary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Office Range Area',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827))),
                          const SizedBox(height: 4),
                          Text(
                            'Allowed geofence radius: ${allowedRadius.toInt()} meters.',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


