import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/location_service.dart';
import 'package:attendance_app/utils/notification_helper.dart';
import 'package:attendance_app/utils/notification_service.dart';
import 'package:attendance_app/screens/auth_wrapper.dart';
import 'package:attendance_app/screens/profile_screen.dart';
import 'package:attendance_app/widgets/live_attendance_builder.dart';
import 'package:attendance_app/widgets/announcements_tab_view.dart';
import 'package:attendance_app/widgets/calendar_tab_view.dart';
import 'package:attendance_app/widgets/tasks_tab_view.dart';
import 'package:attendance_app/widgets/location_map_card.dart';
import 'package:attendance_app/widgets/full_map_screen.dart';
import 'package:attendance_app/widgets/team_members_view.dart';
import 'package:attendance_app/widgets/team_feed_view.dart';
import 'package:attendance_app/widgets/team_tasks_view.dart';
import 'package:attendance_app/widgets/team_departments_view.dart';
import 'package:attendance_app/widgets/org_overview_tab.dart';
import 'package:attendance_app/widgets/org_policies_tab.dart';
import 'package:attendance_app/widgets/org_reports_tab.dart';
import 'package:attendance_app/screens/attendance/attendance_screen.dart';
import 'package:attendance_app/features/leave_management/screens/shared/universal_leave_tab.dart';
import 'package:attendance_app/screens/more/universal_more_tab.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final user = FirebaseAuth.instance.currentUser;
  late final Stream<DocumentSnapshot> _currentUserStream = FirestoreService.userStreamByEmail(user?.email ?? '');
  late final Stream<QuerySnapshot> _orgUsersStream;

  // Tabs State
  int _selectedMainTab = 0; // 0: My Space, 1: Team, 2: Organization
  int _selectedSubTab = 0; // 0: Dashboard, 1: Approvals, 2: Leave, 3: Announcements, 4: Calendar
  int _bottomNavIndex = 0;

  // Approvals State
  int _selectedApprovalTab = 0; // 0: All, 1: Shift, 2: Department, 3: Task, 4: Leave, 5: Attendance
  Map<String, dynamic>? _selectedApprovalData;
  DocumentReference? _selectedApprovalRef;

  // Personal Attendance State
  late final CollectionReference<Map<String, dynamic>> _todayRef;
  late final Stream<DocumentSnapshot> _todayAttendanceStream;
  LocationData? _currentLocationData;
  bool _isCheckingInOut = false;
  Timer? _timer;

  late final String orgId;

  @override
  void initState() {
    super.initState();
    orgId = AppSession().companyId ?? '';
    _orgUsersStream = FirestoreService.orgMembersCol(orgId).snapshots();
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

  // Real-time Streams for Stats
  Stream<int> get _pendingLeavesStream {
    return FirestoreService.allLeaveRequestsQuery.where('status', isEqualTo: 'pending').snapshots()
      .map((snap) => snap.docs.length);
  }

  Stream<Map<String, int>> get _todayStatsStream {
    final controller = StreamController<Map<String, int>>();
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    final attendance = FirestoreService.allAttendanceRecordsCol.snapshots();
    final leaves = FirestoreService.allLeaveRequestsQuery.where('status', isEqualTo: 'approved').snapshots();

    StreamSubscription? subAtt;
    StreamSubscription? subLeaves;

    List<DocumentSnapshot> attDocs = [];
    List<DocumentSnapshot> leaveDocs = [];

    void update() {
      if (controller.isClosed) return;

      int present = 0;
      int wfh = 0;
      int onLeave = 0;

      for (final doc in attDocs) {
        if (doc.id == todayStr) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          if (data['checkIn'] != null) {
            present++;
            if (data['workMode'] == 'wfh') {
              wfh++;
            }
          }
        }
      }

      for (final doc in leaveDocs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        try {
          final fromTs = data['fromDate'];
          final toTs = data['toDate'];
          if (fromTs == null || toTs == null) continue;
          DateTime? from = fromTs is Timestamp ? fromTs.toDate() : DateTime.tryParse(fromTs.toString());
          DateTime? to = toTs is Timestamp ? toTs.toDate() : DateTime.tryParse(toTs.toString());
          if (from != null && to != null) {
            final fromDate = DateTime(from.year, from.month, from.day);
            final toDate = DateTime(to.year, to.month, to.day);
            if (!todayDate.isBefore(fromDate) && !todayDate.isAfter(toDate)) {
              onLeave++;
            }
          }
        } catch (_) {}
      }

      controller.add({
        'present': present,
        'wfh': wfh,
        'onLeave': onLeave,
      });
    }

    subAtt = attendance.listen((snap) {
      attDocs = snap.docs;
      update();
    }, onError: (_) {});

    subLeaves = leaves.listen((snap) {
      leaveDocs = snap.docs;
      update();
    }, onError: (_) {});

    controller.onCancel = () {
      subAtt?.cancel();
      subLeaves?.cancel();
    };

    return controller.stream;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'RA';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: IndexedStack(
        index: _bottomNavIndex,
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildTopNavigation(),
                _buildSubNavigation(),
                Expanded(
                  child: _selectedMainTab == 0
                      ? (_selectedSubTab == 0
                          ? _buildDashboardView()
                          : (_selectedSubTab == 1 
                              ? _buildApprovalsView() 
                              : (_selectedSubTab == 2
                                  ? const Center(child: Text('Leave View'))
                                  : (_selectedSubTab == 3 
                                      ? const AnnouncementsTabView(isAdmin: true) 
                                      : (_selectedSubTab == 4
                                          ? const CalendarTabView()
                                          : (_selectedSubTab == 5
                                              ? const TasksTabView()
                                              : const Center(child: Text('Under Construction'))))))))
                      : _selectedMainTab == 1 
                          ? (_selectedSubTab == 0
                              ? const TeamMembersView()
                              : (_selectedSubTab == 1
                                  ? const TeamFeedView()
                                  : (_selectedSubTab == 2
                                      ? const AnnouncementsTabView(isAdmin: true)
                                      : (_selectedSubTab == 3
                                          ? const TeamTasksView()
                                          : (_selectedSubTab == 4
                                              ? const TeamDepartmentsView()
                                              : const Center(child: Text('Under Construction')))))))
                          : _selectedMainTab == 2
                              ? (_selectedSubTab == 0
                                  ? const OrgOverviewTab()
                                  : (_selectedSubTab == 1
                                      ? const OrgPoliciesTab()
                                      : (_selectedSubTab == 2
                                          ? const AnnouncementsTabView(isAdmin: true)
                                          : (_selectedSubTab == 3
                                              ? const OrgReportsTab()
                                              : const Center(child: Text('Under Construction'))))))
                              : const Center(child: Text('Under Construction')),
                ),
              ],
            ),
          ),
          const SafeArea(child: AttendanceScreen()),
          const SafeArea(child: UniversalLeaveTab()),
          const UniversalMoreTab(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
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
                String rawName = AppSession().userName ?? 'Admin';
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
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'HR Admin - ${DateFormat('EEEE, d MMMM yyyy').format(DateTime.now())}',
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
              Stack(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      color: Colors.white,
                    ),
                    child: const Icon(Icons.notifications_none_rounded, size: 20, color: Color(0xFF4B5563)),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Text('3', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              PopupMenuButton<String>(
                offset: const Offset(0, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) async {
                  if (value == 'logout') {
                    await FirebaseAuth.instance.signOut();
                    AppSession().clear();
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthWrapper()),
                      (route) => false,
                    );
                  } else if (value == 'profile') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, size: 20),
                        SizedBox(width: 8),
                        Text('Profile'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Logout', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                child: StreamBuilder<DocumentSnapshot>(
                  stream: _currentUserStream,
                  builder: (context, snapshot) {
                    String? imageUrl;
                    String name = AppSession().userName ?? 'Admin';
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data() as Map<String, dynamic>;
                      imageUrl = data['profileImageUrl'];
                      if (data['name'] != null) name = data['name'];
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
                            : Center(child: Text(_getInitials(name), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFEEF2FF) : Colors.transparent, // Very light blue
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF5C5CFF) : Colors.transparent,
            width: 1,
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

  Widget _buildSubNavigation() {
    return Container(
      color: Colors.white,
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _selectedMainTab == 0 
          ? Row(
              children: [
                _buildSubTab('Dashboard', 0),
                _buildSubTab('Approvals', 1),
                _buildSubTab('Leave', 2),
                _buildSubTab('Announcements', 3),
                _buildSubTab('Calendar', 4),
                _buildSubTab('Tasks', 5),
              ],
            )
          : _selectedMainTab == 1
            ? Row(
                children: [
                  _buildSubTab('Members', 0),
                  _buildSubTab('Feed', 1),
                  _buildSubTab('Announcements', 2),
                  _buildSubTab('Task', 3),
                  _buildSubTab('Department', 4),
                ],
              )
            : _selectedMainTab == 2
              ? Row(
                  children: [
                    _buildSubTab('Overview', 0),
                    _buildSubTab('Policies', 1),
                    _buildSubTab('Announcements', 2),
                    _buildSubTab('Reports', 3),
                  ],
                )
              : const SizedBox(),
      ),
    );
  }

  Widget _buildSubTab(String label, int index) {
    final isActive = _selectedSubTab == index;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedSubTab = index;
        _selectedApprovalData = null; // reset approval view
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFF5C5CFF) : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            color: isActive ? const Color(0xFF5C5CFF) : const Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }

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
          _buildMonthlyAttendanceCard(),
          const SizedBox(height: 16),
          _buildStatsGrid(),
          const SizedBox(height: 16),
          _buildOrgWideAttendanceCard(),
          const SizedBox(height: 16),
          _buildPendingApprovalsCard(),
          const SizedBox(height: 16),
          _buildMyTasksCard(),
          const SizedBox(height: 16),
          _buildDepartmentHeadcountCard(),
          const SizedBox(height: 16),
          _buildRecentActivityCard(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildApprovalsView() {
    if (_selectedApprovalData != null) {
      return _buildApprovalDetailView();
    }
    
    return Column(
      children: [
        _buildApprovalSecondaryTabs(),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirestoreService.allLeaveRequestsQuery.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              
              final allDocs = snapshot.data?.docs ?? [];
              
              List<DocumentSnapshot> filteredDocs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                String type = (data['leaveType'] ?? data['type'] ?? 'leave').toString().toLowerCase();
                if (_selectedApprovalTab == 1) return type == 'shift';
                if (_selectedApprovalTab == 2) return type == 'department';
                if (_selectedApprovalTab == 3) return type == 'task';
                if (_selectedApprovalTab == 4) return type == 'leave' || type == 'annual' || type == 'sick' || type == 'wfh';
                if (_selectedApprovalTab == 5) return type == 'attendance';
                return true;
              }).toList();

              List<Widget> listItems = [];
              
              // Inject mock data to match the UI if real data is missing for specific tabs
              if (filteredDocs.isEmpty) {
                if (_selectedApprovalTab == 1) { // Shift Mock
                  listItems.add(_buildMockCard('KR', 'Kavya Reddy', 'Engineering Â· Applied Jul 26', 'Shift Change', 'General -> Night Shift Â· Jul 29', 'Shift', const Color(0xFF10B981), const Color(0xFF5C5CFF), const Color(0xFFEEF2FF)));
                } else if (_selectedApprovalTab == 2) { // Department Mock
                  listItems.add(_buildMockCard('SP', 'Sneha Patel', 'HR Â· Applied Jul 26', 'Department Transfer', 'HR -> Operations', 'Department', const Color(0xFF5C5CFF), const Color(0xFF5C5CFF), const Color(0xFFEEF2FF)));
                } else if (_selectedApprovalTab == 3) { // Task Mock
                  listItems.add(_buildMockCard('DJ', 'Deepak Joshi', 'Operations Â· Applied Jul 27', 'Task Extension', 'Q3 Audit - Extend to Aug 5', 'Task', const Color(0xFFF59E0B), const Color(0xFF5C5CFF), const Color(0xFFEEF2FF)));
                } else if (_selectedApprovalTab == 5) { // Attendance Mock
                  listItems.add(_buildMockCard('RK', 'Rohit Kumar', 'Sales Â· Applied Jul 25', 'Attendance Correction', 'Jul 24 Â· Missing check-out', 'Attendance', const Color(0xFFEF4444), const Color(0xFF5C5CFF), const Color(0xFFEEF2FF)));
                }
              }

              final pendingDocs = filteredDocs.where((d) => (d.data() as Map<String, dynamic>?)?['status'] == 'pending' || (d.data() as Map<String, dynamic>?)?['status'] == null).toList();
              final processedDocs = filteredDocs.where((d) => (d.data() as Map<String, dynamic>?)?['status'] != 'pending' && (d.data() as Map<String, dynamic>?)?['status'] != null).toList();

              if (pendingDocs.isNotEmpty || (_selectedApprovalTab == 0 && listItems.isEmpty)) {
                listItems.add(Padding(
                  padding: const EdgeInsets.only(bottom: 16, top: 0),
                  child: Text('PENDING Â· ${pendingDocs.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.5)),
                ));
                for (var doc in pendingDocs) {
                  listItems.add(_buildApprovalRequestCard(doc, doc.data() as Map<String, dynamic>));
                }
              }

              if (processedDocs.isNotEmpty) {
                listItems.add(Padding(
                  padding: const EdgeInsets.only(bottom: 16, top: 24),
                  child: Text('PROCESSED Â· ${processedDocs.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.5)),
                ));
                for (var doc in processedDocs) {
                  listItems.add(_buildApprovalRequestCard(doc, doc.data() as Map<String, dynamic>));
                }
              }
              
              if (listItems.isEmpty) {
                return const Center(child: Text('No requests found', style: TextStyle(color: Colors.grey)));
              }

              return ListView(
                padding: const EdgeInsets.all(20),
                children: listItems,
              );
            }
          ),
        ),
      ],
    );
  }

  Widget _buildMockCard(String initials, String name, String subtitle, String title, String details, String tag, Color avatarColor, Color tagColor, Color tagBgColor) {
    Map<String, dynamic> detailData = {
      'title': title,
      'type': tag,
      'details': details,
      'appliedOn': subtitle.contains('Applied') ? subtitle.split('Applied')[1].trim() : 'Jul 26',
      'status': 'Pending',
      'empName': name,
      'empDept': subtitle.split('Â·')[0].trim(),
      'initials': initials,
      'avatarColor': avatarColor.value,
    };
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: avatarColor, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Text('Pending', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                const SizedBox(height: 4),
                Text(details, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tagBgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tagColor.withOpacity(0.3)),
                ),
                child: Text(tag, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: tagColor)),
              ),
              GestureDetector(
                onTap: () => setState(() {
                   _selectedApprovalData = detailData;
                   _selectedApprovalRef = null;
                }),
                child: Row(
                  children: const [
                    Text('Review', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF5C5CFF))),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 14, color: Color(0xFF5C5CFF)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalSecondaryTabs() {
    final tabs = ['All', 'Shift', 'Department', 'Task', 'Leave', 'Attendance'];
    return Container(
      color: Colors.white,
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final isActive = _selectedApprovalTab == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedApprovalTab = index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isActive ? const Color(0xFF5C5CFF) : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
              child: Text(
                tabs[index],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? const Color(0xFF5C5CFF) : const Color(0xFF6B7280),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildApprovalRequestCard(DocumentSnapshot doc, Map<String, dynamic> data) {
    String rawType = (data['leaveType'] ?? data['type'] ?? 'Leave').toString();
    String type = rawType.toLowerCase();
    
    String title = type == 'wfh' ? 'Work From Home' : (type == 'sick' ? 'Sick Leave' : 'Annual Leave');
    String badgeTag = type == 'wfh' ? 'WFH' : 'Leave';
    
    if (type == 'attendance') {
       title = 'Attendance Correction';
       badgeTag = 'Attendance';
    } else if (type == 'shift') {
       title = 'Shift Change';
       badgeTag = 'Shift';
    }
    
    DateTime appliedDate = (data['appliedOn'] as Timestamp?)?.toDate() ?? DateTime.now();
    String appliedStr = DateFormat('MMM d').format(appliedDate);
    
    DateTime fromDate = (data['fromDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    DateTime toDate = (data['toDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    
    String dateRange = '';
    if (type == 'attendance' && data['recordDate'] != null) {
       dateRange = '${data['recordDate']} Â· Missing check-out';
    } else {
       dateRange = '${DateFormat('MMM d').format(fromDate)}â€“${DateFormat('d').format(toDate)} Â· ${toDate.difference(fromDate).inDays + 1} days';
    }
    
    String empId = data['userId'] ?? data['employeeId'] ?? 'Unknown';
    String empName = empId.split('@')[0];
    
    String status = (data['status'] ?? 'pending').toString().toLowerCase();
    
    Color statusBgColor = const Color(0xFFFFFBEB);
    Color statusBorderColor = const Color(0xFFFDE68A);
    Color statusTextColor = const Color(0xFFD97706);
    String statusText = 'Pending';
    
    if (status == 'approved') {
       statusBgColor = const Color(0xFFECFDF5);
       statusBorderColor = const Color(0xFF10B981).withOpacity(0.3);
       statusTextColor = const Color(0xFF10B981);
       statusText = 'Approved';
    } else if (status == 'rejected') {
       statusBgColor = const Color(0xFFFEF2F2);
       statusBorderColor = const Color(0xFFFCA5A5);
       statusTextColor = const Color(0xFFEF4444);
       statusText = 'Rejected';
    }
    
    List<Color> colors = [const Color(0xFFA855F7), const Color(0xFF10B981), const Color(0xFFF59E0B), const Color(0xFFEF4444), const Color(0xFF5C5CFF)];
    Color avatarColor = colors[empName.length % colors.length];
    
    Map<String, dynamic> detailData = {
      'title': title,
      'type': badgeTag,
      'details': dateRange,
      'appliedOn': appliedStr,
      'status': statusText,
      'empName': empName,
      'empDept': 'Engineering',
      'initials': _getInitials(empName),
      'avatarColor': avatarColor.value,
    };
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: avatarColor, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(_getInitials(empName), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(empName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                    Text('Engineering Â· Applied $appliedStr', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusBorderColor),
                ),
                child: Text(statusText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusTextColor)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                const SizedBox(height: 4),
                Text(dateRange, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: Text(badgeTag, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF5C5CFF))),
              ),
              GestureDetector(
                onTap: () => setState(() {
                   _selectedApprovalData = detailData;
                   _selectedApprovalRef = doc.reference;
                }),
                child: Row(
                  children: const [
                    Text('Review', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF5C5CFF))),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 14, color: Color(0xFF5C5CFF)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalDetailView() {
    final data = _selectedApprovalData!;
    
    String title = data['title'];
    String type = data['type'];
    String details = data['details'];
    String appliedStr = data['appliedOn'];
    String status = data['status'];
    String empName = data['empName'];
    String empDept = data['empDept'];
    String initials = data['initials'];
    Color avatarColor = Color(data['avatarColor']);
    
    Color statusBgColor = const Color(0xFFFFFBEB);
    Color statusBorderColor = const Color(0xFFFDE68A);
    Color statusTextColor = const Color(0xFFD97706);
    
    if (status == 'Approved') {
       statusBgColor = const Color(0xFFECFDF5);
       statusBorderColor = const Color(0xFF10B981).withOpacity(0.3);
       statusTextColor = const Color(0xFF10B981);
    } else if (status == 'Rejected') {
       statusBgColor = const Color(0xFFFEF2F2);
       statusBorderColor = const Color(0xFFFCA5A5);
       statusTextColor = const Color(0xFFEF4444);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _selectedApprovalData = null),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.arrow_back_ios, size: 16, color: Color(0xFF1F2937)),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF3F4F6)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(color: avatarColor, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(empName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                            Text(empDept, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusBorderColor),
                        ),
                        child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusTextColor)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF3F4F6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('REQUEST DETAILS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
                      const SizedBox(height: 24),
                      _buildDetailRow('Type', type),
                      const Divider(height: 32, color: Color(0xFFF3F4F6)),
                      _buildDetailRow('Title', title),
                      const Divider(height: 32, color: Color(0xFFF3F4F6)),
                      _buildDetailRow('Details', details),
                      const Divider(height: 32, color: Color(0xFFF3F4F6)),
                      _buildDetailRow('Applied On', appliedStr),
                      const Divider(height: 32, color: Color(0xFFF3F4F6)),
                      _buildDetailRow('Status', status),
                    ],
                  ),
                ),
                if (status == 'Pending') ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _updateApprovalStatus('approved'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF10B981)), // Green
                            backgroundColor: const Color(0xFFECFDF5),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Approve', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF10B981))),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _updateApprovalStatus('rejected'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFCA5A5)), // Red
                            backgroundColor: const Color(0xFFFEF2F2),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Reject', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFEF4444))),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
      ],
    );
  }

  void _updateApprovalStatus(String status) async {
    if (_selectedApprovalRef == null) {
      // Mock data scenario
      setState(() => _selectedApprovalData = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mock request ${status} successfully'), backgroundColor: status == 'approved' ? AppTheme.success : AppTheme.danger));
      }
      return;
    }
    
    try {
      await _selectedApprovalRef!.update({'status': status});
      setState(() => _selectedApprovalData = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request $status successfully'), backgroundColor: status == 'approved' ? AppTheme.success : AppTheme.danger));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger));
      }
    }
  }


  Widget _buildCardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: child,
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
        
        String workingStr = "0h 0m";
        String overtimeStr = "0h 0m";

        if (checkIn != null) {
          final diff = (checkOut?.toDate() ?? DateTime.now()).difference(checkIn.toDate());
          final h = diff.inHours;
          final m = diff.inMinutes % 60;
          workingStr = '${h}h ${m}m';
          
          if (h > 9 || (h == 9 && m > 0)) {
            final otMin = diff.inMinutes - (9 * 60);
            final oth = otMin ~/ 60;
            final otm = otMin % 60;
            overtimeStr = '${oth}h ${otm}m';
          }
        }

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


  Widget _buildMonthlyAttendanceCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MONTHLY ATTENDANCE â€” ${DateFormat('MMMM yyyy').format(DateTime.now()).toUpperCase()}',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildLegendItem(const Color(0xFF1D4ED8), 'â‰¥9 hrs'), // Dark Blue
              const SizedBox(width: 16),
              _buildLegendItem(const Color(0xFFF59E0B), 'Late (<9 hrs)'), // Orange
              const SizedBox(width: 16),
              _buildLegendItem(const Color(0xFF93C5FD), 'Leave'), // Light Blue
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 10,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        const style = TextStyle(color: Color(0xFF9CA3AF), fontSize: 10);
                        String text = '';
                        switch (value.toInt()) {
                          case 0: text = '1'; break;
                          case 3: text = '4'; break;
                          case 6: text = '7'; break;
                          case 9: text = '10'; break;
                          case 12: text = '13'; break;
                        }
                        return SideTitleWidget(axisSide: meta.axisSide, child: Text(text, style: style));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      interval: 3,
                      getTitlesWidget: (value, meta) {
                        return Text(value.toInt().toString(), style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10));
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  checkToShowHorizontalLine: (value) => value % 3 == 0,
                  getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xFFF3F4F6), strokeWidth: 1, dashArray: [4, 4]),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _makeBarGroup(0, 9.5, const Color(0xFF1D4ED8)),
                  _makeBarGroup(1, 9, const Color(0xFF1D4ED8)),
                  _makeBarGroup(2, 8.5, const Color(0xFFF59E0B)),
                  _makeBarGroup(3, 0, Colors.transparent),
                  _makeBarGroup(4, 0, Colors.transparent),
                  _makeBarGroup(5, 9, const Color(0xFF1D4ED8)),
                  _makeBarGroup(6, 0, Colors.transparent),
                  _makeBarGroup(7, 9.2, const Color(0xFF1D4ED8)),
                  _makeBarGroup(8, 9, const Color(0xFF1D4ED8)),
                  _makeBarGroup(9, 8, const Color(0xFFF59E0B)),
                  _makeBarGroup(10, 0, Colors.transparent),
                  _makeBarGroup(11, 9.5, const Color(0xFF1D4ED8)),
                  _makeBarGroup(12, 9, const Color(0xFF1D4ED8)),
                  _makeBarGroup(13, 8.2, const Color(0xFFF59E0B)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.rectangle)),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
      ],
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 8,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
        )
      ],
    );
  }

  Widget _buildStatsGrid() {
    return StreamBuilder<Map<String, int>>(
      stream: _todayStatsStream,
      builder: (context, statsSnap) {
        final stats = statsSnap.data ?? {'present': 0, 'wfh': 0, 'onLeave': 0};
        return StreamBuilder<QuerySnapshot>(
          stream: _orgUsersStream,
          builder: (context, usersSnap) {
            final totalEmp = usersSnap.data?.docs.where((d) => (d.data() as Map)['role'] != 'admin').length ?? 0;
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5, // width/height ratio
              children: [
                _buildStatCard(totalEmp.toString(), 'Total Employees', const Color(0xFFEEF2FF), const Color(0xFF5C5CFF)),
                _buildStatCard(stats['present'].toString(), 'Present Today', const Color(0xFFECFDF5), const Color(0xFF10B981)),
                _buildStatCard(stats['onLeave'].toString(), 'On Leave', const Color(0xFFFAF5FF), const Color(0xFFA855F7)), // Light purple, purple text
                _buildStatCard(stats['wfh'].toString(), 'Working from Home', const Color(0xFFEFF6FF), const Color(0xFF2563EB)), // Light blue, darker blue text
                _buildStatCard('8', 'New This Month', const Color(0xFFFFFBEB), const Color(0xFFF59E0B)), // Mock data
                _buildStatCard('3', 'Open Alerts', const Color(0xFFFEF2F2), const Color(0xFFEF4444)), // Mock data
              ],
            );
          },
        );
      }
    );
  }

  Widget _buildStatCard(String value, String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textColor)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
        ],
      ),
    );
  }

  Widget _buildOrgWideAttendanceCard() {
    return StreamBuilder<Map<String, int>>(
      stream: _todayStatsStream,
      builder: (context, statsSnap) {
        final stats = statsSnap.data ?? {'present': 0, 'wfh': 0, 'onLeave': 0};
        final p = stats['present'] ?? 0;
        final w = stats['wfh'] ?? 0;
        final l = stats['onLeave'] ?? 0;
        return StreamBuilder<QuerySnapshot>(
          stream: _orgUsersStream,
          builder: (context, usersSnap) {
            final total = usersSnap.data?.docs.where((d) => (d.data() as Map)['role'] != 'admin').length ?? 0;
            final nm = (total - p - l - w) < 0 ? 0 : (total - p - l - w);
            
            return _buildCardContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ATTENDANCE â€” TODAY (ORG-WIDE)',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 20),
                  _buildProgressBar('Present', p, total, const Color(0xFF10B981)),
                  const SizedBox(height: 16),
                  _buildProgressBar('On Leave', l, total, const Color(0xFFA855F7)),
                  const SizedBox(height: 16),
                  _buildProgressBar('WFH', w, total, const Color(0xFF2563EB)),
                  const SizedBox(height: 16),
                  _buildProgressBar('Not Marked', nm, total, const Color(0xFFD1D5DB)),
                ],
              ),
            );
          },
        );
      }
    );
  }

  Widget _buildProgressBar(String label, int value, int total, Color color) {
    double progress = total == 0 ? 0 : value / total;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
            Text(value.toString(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFFF3F4F6),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildPendingApprovalsCard() {
    return StreamBuilder<int>(
      stream: _pendingLeavesStream,
      builder: (context, snapshot) {
        final pendingCount = snapshot.data ?? 0;
        return _buildCardContainer(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pending Approvals', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
                  const SizedBox(height: 4),
                  Text('$pendingCount requests awaiting your action', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    Text('$pendingCount Pending', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 14, color: Color(0xFFD97706)),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildMyTasksCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('MY TASKS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.5)),
              Text('5 active', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF5C5CFF))),
            ],
          ),
          const SizedBox(height: 16),
          _buildTaskItem('Review Q3 Policy Updates', 'Due Aug 5, 2026', 'Assigned', const Color(0xFF5C5CFF), const Color(0xFFEEF2FF), null),
          const Divider(height: 32, color: Color(0xFFF3F4F6)),
          _buildTaskItem('Conduct Employee Satisfaction...', 'Due Jul 31, 2026', 'In Progress', const Color(0xFFD97706), const Color(0xFFFFFBEB), '01:02:28'),
          const Divider(height: 32, color: Color(0xFFF3F4F6)),
          _buildTaskItem('Audit Leave Records - Q2', 'Due Jul 20, 2026', 'Overdue', const Color(0xFFEF4444), const Color(0xFFFEF2F2), null),
          const Divider(height: 32, color: Color(0xFFF3F4F6)),
          _buildTaskItem('Prepare Onboarding Docs', 'Due Aug 10, 2026', 'Assigned', const Color(0xFF5C5CFF), const Color(0xFFEEF2FF), null),
        ],
      ),
    );
  }

  Widget _buildTaskItem(String title, String subtitle, String badgeText, Color badgeColor, Color badgeBg, String? timer) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        if (timer != null) ...[
          Text(timer, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF))),
          const SizedBox(width: 8),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: badgeColor.withOpacity(0.3)),
          ),
          child: Text(badgeText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badgeColor)),
        ),
      ],
    );
  }

  Widget _buildDepartmentHeadcountCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DEPARTMENT HEADCOUNT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.5)),
          const SizedBox(height: 16),
          _buildDeptHeadcountItem('Engineering', 54, const Color(0xFF5C5CFF)),
          const SizedBox(height: 16),
          _buildDeptHeadcountItem('Design', 22, const Color(0xFFA855F7)),
          const SizedBox(height: 16),
          _buildDeptHeadcountItem('Marketing', 31, const Color(0xFFF59E0B)),
          const SizedBox(height: 16),
          _buildDeptHeadcountItem('Sales', 45, const Color(0xFF10B981)),
          const SizedBox(height: 16),
          _buildDeptHeadcountItem('HR', 18, const Color(0xFFEC4899)),
          const SizedBox(height: 16),
          _buildDeptHeadcountItem('Finance', 27, const Color(0xFF1D4ED8)),
          const SizedBox(height: 16),
          _buildDeptHeadcountItem('Operations', 50, const Color(0xFFEF4444)),
        ],
      ),
    );
  }

  Widget _buildDeptHeadcountItem(String dept, int count, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Text(dept, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
          ],
        ),
        Text(count.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
      ],
    );
  }

  Widget _buildRecentActivityCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RECENT ACTIVITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.5)),
          const SizedBox(height: 16),
          _buildActivityItem('Priya Sharma joined Engineering', '2m ago', Icons.person_add_outlined, const Color(0xFF10B981), const Color(0xFFECFDF5)),
          const SizedBox(height: 20),
          _buildActivityItem('Neha Gupta applied for sick leave', '15m ago', Icons.calendar_today_outlined, const Color(0xFFA855F7), const Color(0xFFFAF5FF)),
          const SizedBox(height: 20),
          _buildActivityItem('WFH approved for Arjun Mehta', '1h ago', Icons.check_circle_outline, const Color(0xFF5C5CFF), const Color(0xFFEEF2FF)),
          const SizedBox(height: 20),
          _buildActivityItem('3 attendance corrections pending', '2h ago', Icons.error_outline, const Color(0xFFF59E0B), const Color(0xFFFFFBEB)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String text, String time, IconData icon, Color iconColor, Color bgColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
              const SizedBox(height: 2),
              Text(time, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x0A000000), offset: Offset(0, -4), blurRadius: 16)],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.home_outlined, Icons.home_filled, 'Home'),
              _navItem(1, Icons.access_time, Icons.access_time_filled, 'Attendance'),
              GestureDetector(
                onTap: () {}, // Add Action
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFF5C5CFF),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Color(0x405C5CFF), blurRadius: 12, offset: Offset(0, 4))],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
              _navItem(2, Icons.calendar_today_outlined, Icons.calendar_today, 'Leave'),
              _navItem(3, Icons.more_horiz, Icons.more_horiz, 'More'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData outlineIcon, IconData filledIcon, String label) {
    bool isSelected = _bottomNavIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _bottomNavIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? filledIcon : outlineIcon,
              size: 24,
              color: isSelected ? const Color(0xFF5C5CFF) : const Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF5C5CFF) : const Color(0xFF9CA3AF),
              ),
            )
          ],
        ),
      ),
    );
  }
}
