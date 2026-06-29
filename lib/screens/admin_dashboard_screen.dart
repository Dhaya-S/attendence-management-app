import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/screens/employee_setup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendance_app/screens/auth_wrapper.dart';
import 'package:attendance_app/screens/profile_screen.dart';
class DashboardActivity {
  final String text;
  final DateTime timestamp;
  DashboardActivity(this.text, this.timestamp);
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _bottomNavIndex = 0;
  late final String orgId;
  late final String orgName;

  @override
  void initState() {
    super.initState();
    orgId = AppSession().companyId ?? '';
    orgName = AppSession().companyName ?? 'Organization';
  }

  // ─── Real-Time Stream Getters ──────────────────────────────────────────────

  Stream<int> get _pendingActionsStream {
    final leaves = FirestoreService.allLeaveRequestsQuery.where('status', isEqualTo: 'pending').snapshots();
    final overtime = FirestoreService.allOvertimeRequestsQuery.snapshots();
    final adjustments = FirestoreService.allAttendanceRecordsCol
        .where('isAdjustmentRequest', isEqualTo: true)
        .where('remarkStatus', isEqualTo: 'pending')
        .snapshots();

    final controller = StreamController<int>();
    
    StreamSubscription? sub1;
    StreamSubscription? sub2;
    StreamSubscription? sub3;

    int count1 = 0;
    int count2 = 0;
    int count3 = 0;

    void update() {
      if (!controller.isClosed) {
        controller.add(count1 + count2 + count3);
      }
    }

    sub1 = leaves.listen((snap) {
      count1 = snap.docs.length;
      update();
    }, onError: (_) {});

    sub2 = overtime.listen((snap) {
      count2 = snap.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        return data['status'] == 'pending';
      }).length;
      update();
    }, onError: (_) {});

    sub3 = adjustments.listen((snap) {
      count3 = snap.docs.length;
      update();
    }, onError: (_) {});

    controller.onCancel = () {
      sub1?.cancel();
      sub2?.cancel();
      sub3?.cancel();
    };

    return controller.stream;
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

  Stream<List<DashboardActivity>> get _recentActivityStream {
    final controller = StreamController<List<DashboardActivity>>();

    final members = FirestoreService.orgMembersCol(orgId).snapshots();
    final depts = FirestoreService.orgDepartmentsCol(orgId).snapshots();
    final attendance = FirestoreService.allAttendanceRecordsCol.snapshots();
    final leaves = FirestoreService.allLeaveRequestsQuery.snapshots();

    StreamSubscription? subMem;
    StreamSubscription? subDept;
    StreamSubscription? subAtt;
    StreamSubscription? subLeave;

    List<DocumentSnapshot> memDocs = [];
    List<DocumentSnapshot> deptDocs = [];
    List<DocumentSnapshot> attDocs = [];
    List<DocumentSnapshot> leaveDocs = [];

    void update() {
      if (controller.isClosed) return;

      final List<DashboardActivity> activities = [];

      for (final doc in memDocs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final createdAt = data['createdAt'];
        final fullName = data['fullName'] ?? '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
        final role = data['role'] ?? 'employee';
        final designation = data['designation'] ?? 'Staff';
        
        if (createdAt is Timestamp && role != 'admin') {
          activities.add(DashboardActivity(
            '$fullName joined as $designation',
            createdAt.toDate(),
          ));
        }
      }

      for (final doc in deptDocs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final createdAt = data['createdAt'];
        final name = data['name'] ?? 'New Dept';
        if (createdAt is Timestamp) {
          activities.add(DashboardActivity(
            'New department "$name" created',
            createdAt.toDate(),
          ));
        }
      }

      for (final doc in attDocs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final checkIn = data['checkIn'];
        final userEmail = data['userEmail'] ?? data['userId'] ?? 'Employee';
        final workMode = data['workMode'] == 'wfh' ? 'WFH' : 'Office';
        
        if (checkIn is Timestamp) {
          activities.add(DashboardActivity(
            '$userEmail checked in ($workMode)',
            checkIn.toDate(),
          ));
        }

        final checkOut = data['checkOut'];
        if (checkOut is Timestamp) {
          activities.add(DashboardActivity(
            '$userEmail checked out',
            checkOut.toDate(),
          ));
        }
      }

      for (final doc in leaveDocs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final updatedAt = data['updatedAt'] ?? data['createdAt'];
        final userEmail = data['userEmail'] ?? 'Employee';
        final status = data['status'] ?? 'pending';
        final type = data['leaveType'] ?? 'Leave';

        if (updatedAt is Timestamp) {
          activities.add(DashboardActivity(
            'Leave request ($type) for $userEmail is $status',
            updatedAt.toDate(),
          ));
        }
      }

      activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      controller.add(activities.take(4).toList());
    }

    subMem = members.listen((snap) {
      memDocs = snap.docs;
      update();
    }, onError: (_) {});

    subDept = depts.listen((snap) {
      deptDocs = snap.docs;
      update();
    }, onError: (_) {});

    subAtt = attendance.listen((snap) {
      attDocs = snap.docs;
      update();
    }, onError: (_) {});

    subLeave = leaves.listen((snap) {
      leaveDocs = snap.docs;
      update();
    }, onError: (_) {});

    controller.onCancel = () {
      subMem?.cancel();
      subDept?.cancel();
      subAtt?.cancel();
      subLeave?.cancel();
    };

    return controller.stream;
  }

  String _getUserInitials() {
    final name = AppSession().userName ?? '';
    if (name.isEmpty) {
      final email = AppSession().email ?? 'A';
      return email.substring(0, email.indexOf('@')).substring(0, 2).toUpperCase();
    }
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name.substring(0, 2.clamp(0, name.length)).toUpperCase();
  }

  String formatRelativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return DateFormat('MMM dd').format(dt);
  }

  // ─── Header and Tabs ────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Organization', style: TextStyle(fontSize: 11, color: AppTheme.textHint, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(orgName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            ],
          ),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.search_rounded, size: 20, color: AppTheme.textSecondary),
              ),
              const SizedBox(width: 8),
              Stack(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.notifications_none_rounded, size: 20, color: AppTheme.textSecondary),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
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
                        Text('Edit Profile'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings_outlined, size: 20),
                        SizedBox(width: 8),
                        Text('Settings'),
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
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1F2937),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(_getUserInitials(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTopTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('My Space', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(width: 32),
          const Text('Team', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(width: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF), // very light blue
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('Organization', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabs() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _subTabItem('Dashboard', true),
            _subTabItem('Employees', false),
            _subTabItem('Policies', false),
            _subTabItem('Roles', false),
            _subTabItem('Settings', false),
          ],
        ),
      ),
    );
  }

  Widget _subTabItem(String title, bool isActive) {
    return Container(
      padding: const EdgeInsets.only(bottom: 12, top: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isActive ? AppTheme.primary : Colors.transparent, width: 2)),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          color: isActive ? AppTheme.primary : AppTheme.textHint,
        ),
      ),
    );
  }

  Widget _buildAlerts() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Warning alert
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFEF08A)),
            ),
            child: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Color(0xFFD97706), size: 16),
                SizedBox(width: 8),
                Text('3 employee onboarding invitations pending', style: TextStyle(fontSize: 12, color: Color(0xFFB45309), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Info alert
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppTheme.primary, size: 16),
                SizedBox(width: 8),
                Text('Attendance policy renewal due in 7 days', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, String subtext, Color color, Color bgColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textHint, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(subtext, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirestoreService.orgMembersCol(orgId).snapshots(),
                  builder: (context, snapshot) {
                    final docs = snapshot.data?.docs ?? [];
                    final employees = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      return data['role'] != 'admin';
                    }).toList();
                    
                    final now = DateTime.now();
                    final sevenDaysAgo = now.subtract(const Duration(days: 7));
                    final recentCount = employees.where((doc) {
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      final createdAt = data['createdAt'];
                      if (createdAt is Timestamp) {
                        return createdAt.toDate().isAfter(sevenDaysAgo);
                      }
                      return false;
                    }).length;

                    return _statCard(
                      '${employees.length}',
                      'Total Employees',
                      '+$recentCount this week',
                      AppTheme.primary,
                      const Color(0xFFEFF6FF),
                      Icons.people_outline_rounded,
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirestoreService.orgDepartmentsCol(orgId).snapshots(),
                  builder: (context, snapshot) {
                    final docs = snapshot.data?.docs ?? [];
                    final activeCount = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      return data['isActive'] != false;
                    }).length;
                    return _statCard(
                      '${docs.length}',
                      'Departments',
                      '$activeCount active',
                      const Color(0xFF10B981),
                      const Color(0xFFECFDF5),
                      Icons.business_outlined,
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StreamBuilder<int>(
                  stream: _pendingActionsStream,
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return _statCard(
                      '$count',
                      'Pending Actions',
                      count > 0 ? '$count needs review' : 'All caught up',
                      const Color(0xFFF59E0B),
                      const Color(0xFFFFFBEB),
                      Icons.error_outline_rounded,
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirestoreService.orgPoliciesCol(orgId).snapshots(),
                  builder: (context, snapshot) {
                    final docs = snapshot.data?.docs ?? [];
                    final count = docs.where((doc) => doc.id.startsWith('leave_') || doc.id == 'attendance').length;
                    return _statCard(
                      '$count',
                      'Active Policies',
                      'Configured',
                      const Color(0xFF06B6D4),
                      const Color(0xFFECFEFF),
                      Icons.description_outlined,
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

  Widget _quickActionBtn(String title, Color iconColor, Color bgColor, IconData icon, [VoidCallback? onTap]) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: iconColor)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quick Actions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 16),
            Row(
              children: [
                _quickActionBtn('Add Employee', const Color(0xFF4F46E5), const Color(0xFFEEF2FF), Icons.person_add_outlined, () {
                  final session = AppSession();
                  if (session.companyId != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EmployeeSetupScreen(
                          orgId: session.companyId!,
                          orgName: session.companyName ?? '',
                        ),
                      ),
                    );
                  }
                }),
                const SizedBox(width: 12),
                _quickActionBtn('Create Dept', const Color(0xFF10B981), const Color(0xFFECFDF5), Icons.domain_add_outlined),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _quickActionBtn('Manage Policies', const Color(0xFFD97706), const Color(0xFFFFFBEB), Icons.assignment_outlined),
                const SizedBox(width: 12),
                _quickActionBtn('Assign Roles', const Color(0xFF6366F1), const Color(0xFFEEF2FF), Icons.admin_panel_settings_outlined),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _activityItem(String text, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(time, style: const TextStyle(fontSize: 10, color: AppTheme.textHint)),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return StreamBuilder<List<DashboardActivity>>(
      stream: _recentActivityStream,
      builder: (context, snapshot) {
        final activities = snapshot.data ?? [];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF3F4F6)),
              boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Recent Activity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                    Text('View All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                  ],
                ),
                const SizedBox(height: 20),
                if (activities.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(
                      child: Text(
                        'No recent activity',
                        style: TextStyle(fontSize: 12, color: AppTheme.textHint),
                      ),
                    ),
                  )
                else
                  ...activities.map((act) => _activityItem(act.text, formatRelativeTime(act.timestamp))),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _workforceStat(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkforceToday() {
    return StreamBuilder<Map<String, int>>(
      stream: _todayStatsStream,
      builder: (context, snapshot) {
        final data = snapshot.data ?? {'present': 0, 'wfh': 0, 'onLeave': 0};
        final present = data['present'] ?? 0;
        final wfh = data['wfh'] ?? 0;
        final onLeave = data['onLeave'] ?? 0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Color(0x334F46E5), blurRadius: 16, offset: Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Workforce Today', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _workforceStat('$present', 'Present'),
                    const SizedBox(width: 12),
                    _workforceStat('$onLeave', 'On Leave'),
                    const SizedBox(width: 12),
                    _workforceStat('$wfh', 'WFH'),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.only(top: 12, bottom: 24, left: 16, right: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _navItem(0, Icons.home_filled, 'Home'),
          _navItem(1, Icons.access_time_rounded, 'Attendance'),
          GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF111827),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ),
          _navItem(2, Icons.description_outlined, 'Leave'),
          _navItem(3, Icons.more_horiz_rounded, 'More'),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    bool isSelected = _bottomNavIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _bottomNavIndex = index),
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTopTabs(),
            const SizedBox(height: 16),
            _buildSubTabs(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildAlerts(),
                    const SizedBox(height: 24),
                    _buildStatsGrid(),
                    const SizedBox(height: 24),
                    _buildQuickActions(),
                    const SizedBox(height: 24),
                    _buildRecentActivity(),
                    const SizedBox(height: 24),
                    _buildWorkforceToday(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
}
