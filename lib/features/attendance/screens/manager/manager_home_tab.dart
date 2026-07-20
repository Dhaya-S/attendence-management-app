import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/location_service.dart';
import 'package:attendance_app/utils/notification_helper.dart';
import 'package:attendance_app/utils/notification_service.dart';
import 'package:attendance_app/widgets/live_attendance_builder.dart';
import 'package:attendance_app/widgets/notification_action.dart';
import 'package:attendance_app/widgets/announcements_tab_view.dart';
import 'package:attendance_app/widgets/location_map_card.dart';
import 'package:attendance_app/widgets/full_map_screen.dart';
class ManagerHomeTab extends StatefulWidget {
  final Function(int)? onTabChange;
  const ManagerHomeTab({super.key, this.onTabChange});

  @override
  State<ManagerHomeTab> createState() => _ManagerHomeTabState();
}

class _ManagerHomeTabState extends State<ManagerHomeTab> {
  final user = FirebaseAuth.instance.currentUser;
  late final Stream<DocumentSnapshot> _currentUserStream = FirestoreService.userStreamByEmail(user?.email ?? '');
  late final Stream<QuerySnapshot> _usersStream = FirestoreService.companyUsersQuery.snapshots();

  // Manager Attendance state
  late final CollectionReference<Map<String, dynamic>> _todayRef;
  late final Stream<DocumentSnapshot> _todayAttendanceStream;
  LocationData? _currentLocationData;
  bool _isCheckingInOut = false;
  Timer? _timer;

  // Tabs state
  int _selectedMainTab = 0; // 0: My Space, 1: Team, 2: Organization
  int _selectedSubTab = 0; // 0: Dashboard, 1: Approvals, 2: Announcements, 3: Calendar
  
  // Approvals Sub-Tabs state
  int _selectedApprovalTab = 0; // 0: Leave, 1: Attendance, 2: WFH

  @override
  void initState() {
    super.initState();
    final userEmail = user?.email ?? '';
    _todayRef = FirestoreService.userAttendanceCol(userEmail);
    _todayAttendanceStream = _todayRef.doc(_getAttendanceDocId()).snapshots();
    
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

  String _getAttendanceDocId() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  void _startLocationUpdates() {
    LocationService().startRealtimeTracking();
    LocationService.getStream().listen((data) {
      if (mounted && data.position != null) {
        setState(() => _currentLocationData = data);
      }
    });
  }

  // Check In/Out Logic for Manager
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
        if (isCheckIn) 'checkInLocation': _currentLocationData?.address ?? 'Unknown',
        if (!isCheckIn) 'checkOut': Timestamp.fromDate(now),
        if (!isCheckIn) 'checkOutLocation': _currentLocationData?.address ?? 'Unknown',
        'date': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
        'recordDate': DateFormat('yyyy-MM-dd').format(now),
      };
      
      await _todayRef.doc(_getAttendanceDocId()).set(data, SetOptions(merge: true));
      
      await NotificationHelper.notifyEmployee(
        employeeEmail: userEmail,
        title: isCheckIn ? 'Check-In Successful' : 'Check-Out Successful',
        body: 'You have successfully ${isCheckIn ? "checked in" : "checked out"} at ${DateFormat('hh:mm a').format(now)}.',
        type: isCheckIn ? 'check_in' : 'check_out',
        extraData: {'userId': user?.uid},
      );
      
      if (isCheckIn) {
        final eParts = AppSession().shiftEndTime.split(':');
        await NotificationService().scheduleCheckoutReminder(DateTime(now.year, now.month, now.day, int.parse(eParts[0]), int.parse(eParts[1])));
      } else {
        await NotificationService().cancelCheckoutReminder();
      }
      
      if (mounted) _showSuccessModal(isCheckIn ? 'Check In' : 'Check Out', now);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger));
      }
    } finally {
      if (mounted) setState(() => _isCheckingInOut = false);
    }
  }

  void _showSuccessModal(String title, DateTime time) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => ElasticIn(
        child: Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: Color(0xFFECFDF5), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 56),
              ),
              const SizedBox(height: 20),
              const Text('Successfully Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
              const SizedBox(height: 6),
              Text(title, style: const TextStyle(color: Color(0xFF5C5CFF), fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              const SizedBox(height: 12),
              Text(DateFormat('hh:mm a').format(time), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
              const SizedBox(height: 4),
              Text(DateFormat('EEEE, dd MMM yyyy').format(time), style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5C5CFF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Done', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  String _getWorkingDuration(Timestamp? checkIn, Timestamp? checkOut) {
    if (checkIn == null) return '0h 0m';
    final diff = (checkOut?.toDate() ?? DateTime.now()).difference(checkIn.toDate());
    return '${diff.inHours}h ${diff.inMinutes % 60}m';
  }

  String _getOvertimeDuration(Timestamp? checkIn, Timestamp? checkOut) {
    if (checkIn == null) return '0 min';
    final now = checkOut?.toDate() ?? DateTime.now();
    try {
      final sParts = AppSession().shiftStartTime.split(':');
      final eParts = AppSession().shiftEndTime.split(':');
      final shiftDur = Duration(hours: int.parse(eParts[0]), minutes: int.parse(eParts[1])) -
          Duration(hours: int.parse(sParts[0]), minutes: int.parse(sParts[1]));
      final worked = now.difference(checkIn.toDate());
      if (worked > shiftDur) {
        final ot = worked - shiftDur;
        return ot.inHours > 0 ? '${ot.inHours}h ${ot.inMinutes % 60}m' : '${ot.inMinutes} min';
      }
    } catch (_) {}
    return '0 min';
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }
  
  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'EM';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9), // Light bg from image
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTopNavigation(),
            _buildSubNavigation(),
            Expanded(
              child: _selectedMainTab == 0
                  ? (_selectedSubTab == 0
                      ? _buildDashboardView()
                      : _selectedSubTab == 1
                          ? _buildApprovalsView()
                          : _selectedSubTab == 2
                              ? const AnnouncementsTabView(isAdmin: false)
                              : const Center(child: Text('Coming Soon')))
                  : _selectedMainTab == 2
                      ? (_selectedSubTab == 0
                          ? _buildOrgOverviewView()
                          : _selectedSubTab == 1
                              ? _buildOrgEmployeesView()
                              : const Center(child: Text('Coming Soon')))
                      : const Center(child: Text('Coming Soon')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: _currentUserStream,
              builder: (context, snapshot) {
                final data = snapshot.data?.data() as Map<String, dynamic>?;
                String rawName = AppSession().userName ?? 'Manager';
                if (data?['name'] != null && data!['name'].toString().trim().isNotEmpty) {
                  rawName = data['name'].toString();
                } else if (user?.displayName != null && user!.displayName!.trim().isNotEmpty) {
                  rawName = user!.displayName!;
                }
                final firstName = rawName.split(' ')[0];
                final greeting = _getGreeting();
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting, $firstName',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Row(
            children: [
              NotificationAction(isManager: true, backgroundColor: const Color(0xFFF3F4F6)),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => widget.onTabChange?.call(3), // More tab
                child: StreamBuilder<DocumentSnapshot>(
                  stream: _currentUserStream,
                  builder: (context, snapshot) {
                    String? imageUrl;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data() as Map<String, dynamic>;
                      imageUrl = data['profileImageUrl'];
                    }
                    return Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF5C5CFF),
                      ),
                      child: ClipOval(
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? (imageUrl.startsWith('http')
                                ? Image.network(imageUrl, fit: BoxFit.cover)
                                : Image.memory(base64Decode(imageUrl), fit: BoxFit.cover))
                            : const Center(child: Text('RK', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopNavigation() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildTopTab('My Space', 0),
          _buildTopTab('Team', 1),
          _buildTopTab('Organization', 2),
        ],
      ),
    );
  }

  Widget _buildTopTab(String label, int index) {
    final isActive = _selectedMainTab == index;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedMainTab = index;
        _selectedSubTab = 0; // Reset sub tab
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFEEF2FF) : Colors.transparent, // Very light blue
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? const Color(0xFF5C5CFF) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? const Color(0xFF5C5CFF) : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildSubNavigation() {
    if (_selectedMainTab == 1) return const SizedBox.shrink(); // Team has no sub tabs yet
    
    return Container(
      color: Colors.white,
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _selectedMainTab == 0
              ? [
                  _buildSubTab('Dashboard', 0),
                  _buildSubTab('Approvals', 1),
                  _buildSubTab('Announcements', 2),
                  _buildSubTab('Calendar', 3),
                ]
              : [
                  _buildSubTab('Overview', 0),
                  _buildSubTab('Employees', 1),
                  _buildSubTab('Departments', 2),
                  _buildSubTab('People', 3),
                ],
        ),
      ),
    );
  }

  Widget _buildSubTab(String label, int index) {
    final isActive = _selectedSubTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedSubTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFF5C5CFF) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? const Color(0xFF5C5CFF) : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // DASHBOARD VIEW
  // ==========================================
  Widget _buildDashboardView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOfficeLocationCard(),
          const SizedBox(height: 16),
          _buildAttendanceTodayCard(),
          const SizedBox(height: 16),
          _buildPendingApprovalsCard(),
          const SizedBox(height: 16),
          _buildTeamStatusTodayCard(),
          const SizedBox(height: 16),
          _buildAttendanceSummaryCard(),
          const SizedBox(height: 16),
          _buildLeaveSummaryCard(),
          const SizedBox(height: 16),
          _buildTeamTasksCard(),
          const SizedBox(height: 16),
          _buildRecentAnnouncementsCard(),
          const SizedBox(height: 16),
          _buildUpcomingHolidaysCard(),
          const SizedBox(height: 40), // Bottom padding
        ],
      ),
    );
  }

  Widget _buildCardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
  
  Widget _buildSectionHeader(String title, {String? actionText, VoidCallback? onAction}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
            letterSpacing: 0.5,
          ),
        ),
        if (actionText != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Row(
              children: [
                Text(
                  actionText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5C5CFF),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded, color: Color(0xFF5C5CFF), size: 14),
              ],
            ),
          ),
        if (actionText == null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF5C5CFF), size: 16),
          ),
      ],
    );
  }

  Widget _buildOfficeLocationCard() {
    final isInside = _currentLocationData?.isWithinRadius ?? false;
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6))),
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
                      color: Color(0xFF111827))),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        color: isInside ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(isInside ? 'INSIDE OFFICE RANGE' : 'OUTSIDE OFFICE RANGE',
                    style: TextStyle(
                        fontSize: 10,
                        color: isInside ? const Color(0xFF10B981) : const Color(0xFFEF4444),
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
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: const [
                  Icon(Icons.location_on_outlined, color: Color(0xFF5C5CFF), size: 14),
                  SizedBox(width: 4),
                  Text('View Map',
                      style: TextStyle(
                          color: Color(0xFF5C5CFF),
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

  Widget _buildAttendanceTodayCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _todayAttendanceStream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final checkIn = data?['checkIn'] as Timestamp?;
        final checkOut = data?['checkOut'] as Timestamp?;
        final status = data?['status'] as String?;
        final isCheckedIn = checkIn != null && checkOut == null;
        final isCheckedOut = checkIn != null && checkOut != null;
        final isPresent = isCheckedIn || isCheckedOut;
        final checkInStr = checkIn != null
            ? DateFormat('hh:mm a').format(checkIn.toDate())
            : '--:-- --';
        final workingStr = _getWorkingDuration(checkIn, checkOut);
        final overtimeStr = _getOvertimeDuration(checkIn, checkOut);

        return Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF3F4F6))),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('ATTENDANCE TODAY',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                        letterSpacing: 0.4)),
                if (isPresent)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: const [
                      Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 13),
                      SizedBox(width: 4),
                      Text('Present',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF10B981),
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
                        fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                const SizedBox(height: 2),
                Text('$checkInStr  -  General Shift',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
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
                      color: const Color(0xFF10B981),
                      onTap: null)
                else if (isCheckedIn)
                  _outlinedActionBtn(
                      icon: Icons.logout_rounded,
                      label: _isCheckingInOut ? 'Processing...' : 'Check Out',
                      color: const Color(0xFFEF4444),
                      onTap: _isCheckingInOut ? null : () => _handleCheckInOut('present', false))
                else
                  SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isCheckingInOut ? null : () => _handleCheckInOut('present', true),
                        icon: _isCheckingInOut ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.login_rounded, size: 18),
                        label: Text(_isCheckingInOut ? 'Checking In...' : 'Check In Now',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5C5CFF),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                      )),
              ]),
            ),
          ]),
        );
      },
    );
  }

  Widget _statPill(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
          color: const Color(0xFFF6F7FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF3F4F6))),
      child: Column(children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
              textAlign: TextAlign.center),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
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
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: color.withOpacity(0.4), width: 1.5)),
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

  Widget _buildTimeBox(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingApprovalsCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('PENDING APPROVALS', actionText: 'View All', onAction: () {
            setState(() {
              _selectedSubTab = 1; // Go to Approvals
            });
          }),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirestoreService.allLeaveRequestsQuery.where('status', isEqualTo: 'pending').snapshots(),
            builder: (context, leaveSnap) {
              final leaveCount = leaveSnap.data?.docs.length ?? 0;
              // Mock attendance and wfh counts for UI since exact queries might differ
              final attendanceCount = 2; // Mocked
              final wfhCount = 2; // Mocked
              
              return Row(
                children: [
                  Expanded(child: _buildCountBox(leaveCount.toString(), 'Leave', const Color(0xFFEEF2FF), const Color(0xFF5C5CFF))), // Light purple
                  const SizedBox(width: 12),
                  Expanded(child: _buildCountBox(attendanceCount.toString(), 'Attendance', const Color(0xFFFFFBEB), const Color(0xFFF59E0B))), // Light yellow
                  const SizedBox(width: 12),
                  Expanded(child: _buildCountBox(wfhCount.toString(), 'WFH', const Color(0xFFECFDF5), const Color(0xFF10B981))), // Light green
                ],
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _buildCountBox(String count, String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamStatusTodayCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _usersStream,
      builder: (context, usersSnapshot) {
        if (!usersSnapshot.hasData) return const SizedBox.shrink();
        
        final employees = usersSnapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data['role'] ?? 'employee').toString().toLowerCase() != 'manager';
        }).toList();
        final uidToEmail = <String, String>{};
        for (var doc in employees) {
          final data = doc.data() as Map<String, dynamic>;
          final uid = data['uid'] as String?;
          if (uid != null) uidToEmail[uid] = doc.id;
        }
        
        final identifiers = [...employees.map((e) => e.id), ...uidToEmail.keys];
        
        return LiveAttendanceBuilder(
          userIds: identifiers,
          builder: (context, records) {
            // Processing records
            final presentRecords = records.where((r) => r['checkIn'] != null).toList();
            // Just take a few to display (like in image)
            final displayRecords = presentRecords.take(4).toList();
            
            return _buildCardContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('TEAM STATUS TODAY', actionText: 'Details', onAction: () {}),
                  const SizedBox(height: 16),
                  if (displayRecords.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text('No team members checked in yet.', style: TextStyle(color: Color(0xFF6B7280)))),
                    )
                  else
                    ...displayRecords.map((r) {
                      final email = r['userId'] as String? ?? '';
                      // Find name from employees
                      String name = 'Employee';
                      try {
                        final empDoc = employees.firstWhere((e) => e.id == email || (e.data() as Map)['uid'] == email);
                        name = (empDoc.data() as Map)['name'] ?? 'Employee';
                      } catch (_) {}
                      
                      final checkInTs = r['checkIn'] as Timestamp?;
                      final timeStr = checkInTs != null ? DateFormat('hh:mm a').format(checkInTs.toDate()) : '--:--';
                      
                      final workMode = r['workMode'] as String? ?? 'office';
                      final remarkStatus = r['remarkStatus'] as String?;
                      
                      bool isLate = false;
                      if (checkInTs != null && workMode != 'wfh') {
                        final checkIn = checkInTs.toDate();
                        final sParts = AppSession().shiftStartTime.split(':');
                        final lateThreshold = DateTime(checkIn.year, checkIn.month, checkIn.day, int.parse(sParts[0]), int.parse(sParts[1]))
                            .add(Duration(minutes: AppSession().gracePeriod));
                        if (checkIn.isAfter(lateThreshold) && remarkStatus != 'approved') {
                          isLate = true;
                        }
                      }
                      
                      String statusText = workMode == 'wfh' ? 'WFH' : isLate ? 'Late' : 'Present';
                      Color statusColor = workMode == 'wfh' ? const Color(0xFF5C5CFF) : isLate ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
                      Color statusBg = workMode == 'wfh' ? const Color(0xFFEEF2FF) : isLate ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5);
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFF5C5CFF),
                                  child: Text(_getInitials(name), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                                  const SizedBox(height: 2),
                                  Text('In: $timeStr', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: statusColor.withOpacity(0.3)),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  if (presentRecords.length > 4)
                    Center(
                      child: Text(
                        '+${presentRecords.length - 4} more members',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF5C5CFF)),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      }
    );
  }

  Widget _buildAttendanceSummaryCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('ATTENDANCE SUMMARY', onAction: () {}),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildCountBox('22', 'Present', const Color(0xFFECFDF5), const Color(0xFF10B981))), // Light green
              const SizedBox(width: 12),
              Expanded(child: _buildCountBox('1', 'Late', const Color(0xFFFFFBEB), const Color(0xFFF59E0B))), // Light yellow
              const SizedBox(width: 12),
              Expanded(child: _buildCountBox('98.2%', 'Rate', const Color(0xFFEEF2FF), const Color(0xFF5C5CFF))), // Light purple
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveSummaryCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('LEAVE SUMMARY', onAction: () {}),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildCountBox('8', 'Balance', const Color(0xFFF9FAFB), const Color(0xFF8B5CF6))), // Light grey, purple text
              const SizedBox(width: 12),
              Expanded(child: _buildCountBox('2', 'Pending', const Color(0xFFFFFBEB), const Color(0xFFF59E0B))), // Light yellow
              const SizedBox(width: 12),
              Expanded(child: _buildCountBox('1', 'On Leave Today', const Color(0xFFEEF2FF), const Color(0xFF5C5CFF))), // Light blue
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamTasksCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('TEAM TASKS', onAction: () {}),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildCountBox('5', 'Assigned', const Color(0xFFEEF2FF), const Color(0xFF5C5CFF))), // Light purple
              const SizedBox(width: 12),
              Expanded(child: _buildCountBox('2', 'In Progress', const Color(0xFFEEF2FF), const Color(0xFF5C5CFF))), // Light purple
              const SizedBox(width: 12),
              Expanded(child: _buildCountBox('1', 'Overdue', const Color(0xFFFEF2F2), const Color(0xFFEF4444))), // Light red
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAnnouncementsCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('RECENT ANNOUNCEMENTS', onAction: () {}),
          const SizedBox(height: 16),
          _buildAnnouncementItem('Policy', 'Updated Leave Policy FY 2025â€“26', '2 days ago', const Color(0xFFEEF2FF), const Color(0xFF8B5CF6)),
          const Divider(height: 32, color: Color(0xFFF3F4F6)),
          _buildAnnouncementItem('HR', 'WFO Reminder â€” Mon to Thu', 'Yesterday', const Color(0xFFEFF6FF), const Color(0xFF3B82F6)),
        ],
      ),
    );
  }

  Widget _buildAnnouncementItem(String tag, String title, String time, Color tagBg, Color tagColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(12)),
                child: Text(tag, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: tagColor)),
              ),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
            ],
          ),
        ),
        Text(time, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
      ],
    );
  }
  
  Widget _buildUpcomingHolidaysCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('UPCOMING HOLIDAYS', onAction: () {}),
          const SizedBox(height: 16),
          _buildHolidayItem('AUG', '15', 'Independence Day', '18 days away'),
          const SizedBox(height: 16),
          _buildHolidayItem('AUG', '27', 'Ganesh Chaturthi', '30 days away'),
        ],
      ),
    );
  }
  
  Widget _buildHolidayItem(String month, String day, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(month, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF5C5CFF))),
              const SizedBox(height: 2),
              Text(day, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF5C5CFF))),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // APPROVALS VIEW
  // ==========================================
  Widget _buildApprovalsView() {
    return Column(
      children: [
        // Approvals sub-tabs
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(child: _buildApprovalTab('Leave', 0)),
              Expanded(child: _buildApprovalTab('Attendance', 1)),
              Expanded(child: _buildApprovalTab('WFH', 2)),
            ],
          ),
        ),
        // Content
        Expanded(
          child: _selectedApprovalTab == 0
              ? _buildLeaveApprovalsList()
              : const Center(child: Text('Under Construction')),
        ),
      ],
    );
  }

  Widget _buildApprovalTab(String label, int index) {
    final isActive = _selectedApprovalTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedApprovalTab = index),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFF5C5CFF) : const Color(0xFFE5E7EB),
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? const Color(0xFF5C5CFF) : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaveApprovalsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.allLeaveRequestsQuery.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs;
        final pending = docs.where((d) => (d.data() as Map)['status'] == 'pending').length;
        final approved = docs.where((d) => (d.data() as Map)['status'] == 'approved').length;
        final rejected = docs.where((d) => (d.data() as Map)['status'] == 'rejected').length;
        
        // Sort docs logically (pending first, then others by date)
        final sortedDocs = docs.toList()..sort((a, b) {
          final sA = (a.data() as Map)['status'] ?? 'pending';
          final sB = (b.data() as Map)['status'] ?? 'pending';
          if (sA == 'pending' && sB != 'pending') return -1;
          if (sA != 'pending' && sB == 'pending') return 1;
          
          final dA = (a.data() as Map)['requestDate'] as Timestamp?;
          final dB = (b.data() as Map)['requestDate'] as Timestamp?;
          if (dA == null) return 1;
          if (dB == null) return -1;
          return dB.compareTo(dA);
        });

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$pending pending - $approved approved - $rejected rejected',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...sortedDocs.map((doc) => _buildLeaveApprovalCard(doc)),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeaveApprovalCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['userName'] ?? 'Employee';
    final dept = data['department'] ?? 'Design'; // Default for UI mock
    final status = data['status'] ?? 'pending';
    final leaveType = data['leaveType'] ?? 'Leave';
    final reason = data['reason'] ?? 'No reason';
    final reqDate = data['requestDate'] as Timestamp?;
    final from = data['fromDate'] as Timestamp?;
    final to = data['toDate'] as Timestamp?;
    
    final reqDateStr = reqDate != null ? DateFormat('MMM d').format(reqDate.toDate()) : '--';
    
    String datesStr = '--';
    int days = 1;
    if (from != null && to != null) {
      final f = from.toDate();
      final t = to.toDate();
      days = t.difference(f).inDays + 1;
      if (f.month == t.month) {
        datesStr = '${DateFormat('MMM d').format(f)} - ${DateFormat('MMM d').format(t)}';
      } else {
        datesStr = '${DateFormat('MMM d').format(f)} - ${DateFormat('MMM d').format(t)}';
      }
    }
    
    Color badgeColor;
    Color badgeBg;
    Color badgeBorder;
    String badgeText;
    
    switch (status.toString().toLowerCase()) {
      case 'approved':
        badgeColor = const Color(0xFF10B981);
        badgeBg = const Color(0xFFECFDF5);
        badgeBorder = const Color(0xFF10B981);
        badgeText = 'Approved';
        break;
      case 'rejected':
        badgeColor = const Color(0xFFEF4444);
        badgeBg = const Color(0xFFFEF2F2);
        badgeBorder = const Color(0xFFEF4444);
        badgeText = 'Rejected';
        break;
      default:
        badgeColor = const Color(0xFFF59E0B);
        badgeBg = const Color(0xFFFFFBEB);
        badgeBorder = const Color(0xFFF59E0B);
        badgeText = 'Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF5C5CFF),
                child: Text(_getInitials(name), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                    Text('$dept Â· Applied $reqDateStr', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeBorder.withOpacity(0.3)),
                ),
                child: Text(badgeText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: badgeColor)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(leaveType, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                const SizedBox(height: 4),
                Text('$datesStr Â· $days day${days > 1 ? "s" : ""}', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                const SizedBox(height: 8),
                Text(reason, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                if (status == 'rejected' && data['comment'] != null) ...[
                  const SizedBox(height: 8),
                  Text('Comment: ${data['comment']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                ]
              ],
            ),
          ),
          if (status == 'pending') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _updateLeaveStatus(doc.reference, 'approved'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: const Color(0xFFECFDF5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 16),
                        SizedBox(width: 4),
                        Text('Approve', style: TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showRejectDialog(doc.reference, name),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: const Color(0xFFFEF2F2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 16),
                        SizedBox(width: 4),
                        Text('Reject', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.more_horiz, color: Color(0xFF4B5563), size: 20),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _updateLeaveStatus(DocumentReference ref, String status, {String? comment}) async {
    try {
      await ref.update({
        'status': status,
        if (comment != null) 'comment': comment,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 20),
                const SizedBox(width: 12),
                Text(
                  status == 'approved' ? 'Request approved successfully' : 'Request rejected',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1F2937),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            elevation: 0,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)));
      }
    }
  }

  void _showRejectDialog(DocumentReference ref, String employeeName) {
    final commentController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Reject Request',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
              ),
              const SizedBox(height: 8),
              Text(
                'Add a comment for $employeeName explaining the reason.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: commentController,
                maxLines: 4,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
                decoration: InputDecoration(
                  hintText: 'Reason for rejection...',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF5C5CFF)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF3F4F6),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4B5563))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _updateLeaveStatus(ref, 'rejected', comment: commentController.text.isNotEmpty ? commentController.text : null);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF3F4F6),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Reject', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF))),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // ORGANIZATION VIEWS
  // ==========================================
  Widget _buildOrgOverviewView() {
    final companyName = AppSession().companyName ?? 'Sunrise Technologies';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Organization Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5C5CFF), Color(0xFF4338CA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ORGANIZATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Text(companyName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 4),
                const Text('Established 2015 Â· Bangalore, India', style: TextStyle(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildOrgStat('234', 'Employees'),
                    _buildOrgStat('8', 'Departments'),
                    _buildOrgStat('4', 'Locations'),
                    const SizedBox(width: 10), // spacer
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Departments Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 2.2,
            children: [
              _buildDeptCard('Design', '7 employees', const Color(0xFFEEF2FF), const Color(0xFF5C5CFF)),
              _buildDeptCard('Engineering', '12 employees', const Color(0xFFF0FDF4), const Color(0xFF059669)),
              _buildDeptCard('HR', '5 employees', const Color(0xFFFDF2F8), const Color(0xFFDB2777)),
              _buildDeptCard('Product', '4 employees', const Color(0xFFFFFBEB), const Color(0xFFD97706)),
            ],
          ),
          const SizedBox(height: 24),
          
          // Office Locations
          const Text('OFFICE LOCATIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 1.0)),
          const SizedBox(height: 12),
          _buildCardContainer(
            child: Column(
              children: [
                _buildLocationItem('Bangalore HQ', 'Plot 14, Whitefield Â· 180 employees'),
                const Divider(height: 24, color: Color(0xFFF3F4F6)),
                _buildLocationItem('Chennai', 'Anna Nagar Â· 32 employees'),
                const Divider(height: 24, color: Color(0xFFF3F4F6)),
                _buildLocationItem('Hyderabad', 'Hitech City Â· 22 employees'),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildOrgStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }

  Widget _buildDeptCard(String name, String count, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 4),
          Text(count, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }

  Widget _buildLocationItem(String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFFEEF2FF),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.location_on_outlined, color: Color(0xFF5C5CFF), size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
          ],
        ),
      ],
    );
  }

  Widget _buildOrgEmployeesView() {
    return Column(
      children: [
        // Controls
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
                          SizedBox(width: 8),
                          Text('Search employees...', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5C5CFF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Directory', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: const Text('Org Tree', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterPill('All', true),
                    _buildFilterPill('Design', false),
                    _buildFilterPill('HR', false),
                    _buildFilterPill('Engineering', false),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _usersStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF5C5CFF)));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No employees found.'));
              }

              final employees = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data['role'] ?? 'employee').toString().toLowerCase() != 'manager';
              }).toList();
              
              final uids = employees.map((e) => e.id).toList();

              return LiveAttendanceBuilder(
                userIds: uids,
                builder: (context, records) {
                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text('${employees.length} employees', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                      const SizedBox(height: 12),
                      ...employees.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final email = doc.id;
                        final name = data['name'] ?? 'Employee';
                        final role = data['jobTitle'] ?? 'Staff';
                        final dept = data['department'] ?? 'Design';
                        
                        final record = records.firstWhere((r) => r['userId'] == email || r['userId'] == data['uid'], orElse: () => <String, dynamic>{});
                        final checkIn = record['checkIn'];
                        final workMode = record['workMode'];
                        final statusStr = record['status'] as String?;
                        
                        String status = 'Absent';
                        if (statusStr == 'leave') status = 'On Leave';
                        else if (checkIn != null) {
                          if (workMode == 'wfh') status = 'WFH';
                          else {
                            // simple late logic
                            status = 'Present';
                            final sParts = AppSession().shiftStartTime.split(':');
                            if (sParts.length == 2) {
                              final dt = (checkIn as Timestamp).toDate();
                              final s = DateTime(dt.year, dt.month, dt.day, int.parse(sParts[0]), int.parse(sParts[1]));
                              if (dt.isAfter(s.add(Duration(minutes: AppSession().gracePeriod)))) {
                                status = 'Late';
                              }
                            }
                          }
                        }
                        
                        return _buildEmployeeCard(name, role, dept, status);
                      }).toList(),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPill(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF5C5CFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSelected ? const Color(0xFF5C5CFF) : const Color(0xFFE5E7EB)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : const Color(0xFF6B7280),
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(String name, String role, String dept, String status) {
    Color statusColor;
    Color statusBg;
    if (status == 'Present') {
      statusColor = const Color(0xFF10B981);
      statusBg = const Color(0xFFECFDF5);
    } else if (status == 'Late') {
      statusColor = const Color(0xFFF59E0B);
      statusBg = const Color(0xFFFFFBEB);
    } else if (status == 'WFH') {
      statusColor = const Color(0xFF3B82F6);
      statusBg = const Color(0xFFEFF6FF);
    } else if (status == 'On Leave') {
      statusColor = const Color(0xFF8B5CF6);
      statusBg = const Color(0xFFF5F3FF);
    } else {
      statusColor = const Color(0xFF9CA3AF);
      statusBg = const Color(0xFFF3F4F6);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color((name.hashCode * 0xFFFFFF).toInt()).withOpacity(1.0).withRed(150),
                ),
                child: Center(child: Text(_getInitials(name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                const SizedBox(height: 2),
                Text('$role Â· $dept', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF), size: 18),
        ],
      ),
    );
  }
}
