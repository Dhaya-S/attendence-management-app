import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/screens/profile_screen.dart';
import 'package:attendance_app/screens/auth_wrapper.dart';
import 'attendance_screen.dart';

/// Admin-specific Attendance screen with My Space / Team tabs.
/// My Space = personal attendance (existing AttendanceScreen).
/// Team = company-wide employee attendance overview.
class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  int _selectedTab = 0; // 0=My Space, 1=Team
  final _user = FirebaseAuth.instance.currentUser;
  late final Stream<DocumentSnapshot> _userStream;

  @override
  void initState() {
    super.initState();
    _userStream = FirestoreService.userStreamByEmail(_user?.email ?? '');
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
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
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _selectedTab == 0
                  ? const AttendanceScreen()
                  : const _TeamAttendanceTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1.5)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting row with avatar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: _userStream,
                  builder: (context, snapshot) {
                    final data = snapshot.data?.data() as Map<String, dynamic>?;
                    String rawName = AppSession().userName ?? 'Admin';
                    if (data?['name'] != null &&
                        data!['name'].toString().trim().isNotEmpty) {
                      rawName = data['name'].toString();
                    }
                    final firstName = rawName.split(' ').first;
                    final role = AppSession().role?.toUpperCase() ?? 'ADMIN';
                    final greeting = _getGreeting();
                    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
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
                          '$role · $dateStr',
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
                      stream: _userStream,
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
          const SizedBox(height: 14),
          // Screen title
          const Text(
            'Attendance',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          _buildTabSwitcher(),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tabPill('My Space', 0),
          const SizedBox(width: 12),
          _tabPill('Team', 1),
        ],
      ),
    );
  }

  Widget _tabPill(String label, int index) {
    final isActive = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(24),
          border: isActive
              ? null
              : Border.all(color: const Color(0xFFE5E7EB), width: 1),
          boxShadow: isActive
              ? [
                  const BoxShadow(
                    color: Color(0x305C5CFF),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  TEAM ATTENDANCE TAB
// ============================================================

class _TeamAttendanceTab extends StatefulWidget {
  const _TeamAttendanceTab();

  @override
  State<_TeamAttendanceTab> createState() => _TeamAttendanceTabState();
}

class _TeamAttendanceTabState extends State<_TeamAttendanceTab> {
  // 0=Overview, 1=Exceptions, 2=Analytics
  int _subTab = 0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? _selectedDept;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Column(
      children: [
        // Sub tab bar
        _buildSubTabBar(),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirestoreService.allAttendanceRecordsCol
                .where('recordDate', isEqualTo: todayStr)
                .snapshots(),
            builder: (context, attSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirestoreService.employeesCol.snapshots(),
                builder: (context, empSnap) {
                  final attDocs = attSnap.data?.docs ?? [];
                  final empDocs = empSnap.data?.docs ?? [];

                  // Build today's attendance map: email -> data
                  final Map<String, Map<String, dynamic>> todayAtt = {};
                  for (final doc in attDocs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final email = (data['userId'] as String? ??
                        data['email'] as String? ??
                        '').toLowerCase();
                    if (email.isNotEmpty) {
                      todayAtt[email] = data;
                    }
                  }

                  // Build per-employee today data
                  final employees = empDocs.map((e) {
                    final data = e.data() as Map<String, dynamic>;
                    final email =
                        (data['email'] as String? ?? '').toLowerCase();
                    final attData = todayAtt[email];
                    return _EmpAttInfo(
                      name: data['name'] as String? ?? email,
                      email: email,
                      department: data['department'] as String? ?? '',
                      designation: data['designation'] as String? ??
                          data['role'] as String? ??
                          '',
                      attData: attData,
                    );
                  }).toList();

                  // Compute stats
                  final stats = _computeStats(employees);

                  if (_subTab == 0) {
                    return _buildOverviewContent(
                        employees, stats, todayStr, attDocs);
                  } else if (_subTab == 1) {
                    return _buildExceptionsContent(employees);
                  } else {
                    return _buildAnalyticsContent(
                        employees, attDocs, empDocs);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubTabBar() {
    final tabs = ['Overview', 'Exceptions', 'Analytics'];
    return Container(
      color: Colors.white,
      child: Row(
        children: tabs.asMap().entries.map((e) {
          final i = e.key;
          final label = e.value;
          final isActive = _subTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _subTab = i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isActive
                          ? AppTheme.primary
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isActive
                          ? AppTheme.primary
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Stats computation ────────────────────────────────────
  Map<String, int> _computeStats(List<_EmpAttInfo> employees) {
    int present = 0, wfh = 0, late = 0, onLeave = 0, absent = 0;
    final shiftParts = AppSession().shiftStartTime.split(':');
    final today = DateTime.now();
    final shiftStart = DateTime(today.year, today.month, today.day,
        int.parse(shiftParts[0]), int.parse(shiftParts[1]));
    final grace = AppSession().gracePeriod;

    for (final emp in employees) {
      final att = emp.attData;
      if (att == null) {
        absent++;
        continue;
      }
      final checkIn = att['checkIn'] as Timestamp?;
      final mode = att['workMode'] as String? ?? '';

      if (checkIn != null) {
        final lateThreshold =
            shiftStart.add(Duration(minutes: grace));
        if (checkIn.toDate().isAfter(lateThreshold)) {
          late++;
        } else {
          present++;
        }
        if (mode == 'wfh') wfh++;
      } else {
        // Has att doc but no checkIn — treat as absent today
        absent++;
      }
    }

    return {
      'present': present,
      'wfh': wfh,
      'late': late,
      'onLeave': onLeave,
      'absent': absent,
    };
  }

  // ── Overview ─────────────────────────────────────────────
  Widget _buildOverviewContent(
    List<_EmpAttInfo> employees,
    Map<String, int> stats,
    String todayStr,
    List<QueryDocumentSnapshot> allAttDocs,
  ) {
    // Collect departments for filter
    final departments = employees
        .map((e) => e.department)
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList();

    // Filter employees
    final filtered = employees.where((e) {
      final q = _searchQuery.toLowerCase();
      final matchSearch = q.isEmpty ||
          e.name.toLowerCase().contains(q) ||
          e.email.toLowerCase().contains(q);
      final matchDept =
          _selectedDept == null || e.department == _selectedDept;
      return matchSearch && matchDept;
    }).toList();

    // Sort: late > present > wfh > absent > on leave
    filtered.sort((a, b) {
      int score(Map<String, dynamic>? d) {
        if (d == null) return 4;
        final checkIn = d['checkIn'] as Timestamp?;
        if (checkIn == null) return 4;
        final mode = d['workMode'] as String? ?? '';
        final shiftParts = AppSession().shiftStartTime.split(':');
        final today = DateTime.now();
        final shiftStart = DateTime(today.year, today.month, today.day,
            int.parse(shiftParts[0]), int.parse(shiftParts[1]));
        final grace = AppSession().gracePeriod;
        final lateThreshold =
            shiftStart.add(Duration(minutes: grace));
        if (checkIn.toDate().isAfter(lateThreshold)) return 1; // late
        if (mode == 'wfh') return 2; // wfh
        return 0; // present
      }

      return score(a.attData) - score(b.attData);
    });

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Stats row
        SliverToBoxAdapter(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: _buildStatsRow(stats),
          ),
        ),
        const SliverToBoxAdapter(
            child: SizedBox(height: 8)),
        // Department chips
        if (departments.isNotEmpty)
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _deptChip('All', null),
                    ...departments.map((d) => _deptChip(d, d)),
                  ],
                ),
              ),
            ),
          ),
        // Search bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _buildSearchBar(),
          ),
        ),
        // Employee list
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final emp = filtered[index];
              return FadeInUp(
                duration: const Duration(milliseconds: 300),
                delay: Duration(milliseconds: index * 40),
                child: _buildEmployeeAttRow(emp, index == filtered.length - 1),
              );
            },
            childCount: filtered.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildStatsRow(Map<String, int> stats) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _statPill(stats['present'].toString(), 'Present',
            const Color(0xFF10B981), const Color(0xFFECFDF5)),
        _statPill(stats['wfh'].toString(), 'WFH',
            const Color(0xFF3B82F6), const Color(0xFFEFF6FF)),
        _statPill(stats['late'].toString(), 'Late',
            const Color(0xFFF59E0B), const Color(0xFFFFFBEB)),
        _statPill(stats['onLeave'].toString(), 'Leave',
            const Color(0xFFAB40FF), const Color(0xFFF5F3FF)),
        _statPill(stats['absent'].toString(), 'Absent',
            const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
      ],
    );
  }

  Widget _statPill(
      String count, String label, Color color, Color bgColor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deptChip(String label, String? value) {
    final isActive = _selectedDept == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedDept = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: const InputDecoration(
          hintText: 'Search employee...',
          hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          prefixIcon:
              Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
      ),
    );
  }

  Widget _buildEmployeeAttRow(_EmpAttInfo emp, bool isLast) {
    final att = emp.attData;
    final checkIn = att?['checkIn'] as Timestamp?;
    final checkOut = att?['checkOut'] as Timestamp?;
    final mode = att?['workMode'] as String? ?? '';

    // Determine status
    String statusLabel;
    Color statusColor;
    Color statusBg;

    if (att == null || checkIn == null) {
      statusLabel = 'Absent';
      statusColor = const Color(0xFF6B7280);
      statusBg = const Color(0xFFF3F4F6);
    } else {
      final shiftParts = AppSession().shiftStartTime.split(':');
      final today = DateTime.now();
      final shiftStart = DateTime(today.year, today.month, today.day,
          int.parse(shiftParts[0]), int.parse(shiftParts[1]));
      final grace = AppSession().gracePeriod;
      final lateThreshold = shiftStart.add(Duration(minutes: grace));

      if (mode == 'wfh') {
        statusLabel = 'WFH';
        statusColor = const Color(0xFF3B82F6);
        statusBg = const Color(0xFFEFF6FF);
      } else if (checkIn.toDate().isAfter(lateThreshold)) {
        statusLabel = 'Late';
        statusColor = const Color(0xFFF59E0B);
        statusBg = const Color(0xFFFFFBEB);
      } else {
        statusLabel = 'Present';
        statusColor = const Color(0xFF10B981);
        statusBg = const Color(0xFFECFDF5);
      }
    }

    final checkInStr = checkIn != null
        ? 'In: ${DateFormat('hh:mm a').format(checkIn.toDate())}'
        : '—';

    final initials = _getInitials(emp.name);
    final colors = [
      const Color(0xFF5C5CFF),
      const Color(0xFFAB40FF),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF3B82F6),
    ];
    final avatarColor = emp.name.isEmpty
        ? colors[0]
        : colors[emp.name.codeUnitAt(0) % colors.length];

    return GestureDetector(
      onTap: () => _showEmployeeAttDetail(emp, checkIn, checkOut, mode,
          statusLabel, statusColor),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: Row(
          children: [
            // Avatar with status dot
            Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: avatarColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 1,
                  right: 1,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    emp.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    emp.designation.isNotEmpty
                        ? '${emp.designation} · $checkInStr'
                        : '${emp.department} · $checkInStr',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFD1D5DB), size: 18),
          ],
        ),
      ),
    );
  }

  void _showEmployeeAttDetail(
    _EmpAttInfo emp,
    Timestamp? checkIn,
    Timestamp? checkOut,
    String mode,
    String status,
    Color statusColor,
  ) {
    final workDuration = (checkIn != null)
        ? () {
            final end = checkOut?.toDate() ?? DateTime.now();
            final diff = end.difference(checkIn.toDate());
            return '${diff.inHours}h ${diff.inMinutes % 60}m';
          }()
        : '—';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _getInitials(emp.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(emp.name,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1F2937))),
                      Text(
                          emp.designation.isNotEmpty
                              ? emp.designation
                              : emp.department,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(status,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(color: Color(0xFFF3F4F6)),
            const SizedBox(height: 16),
            // Attendance details
            Row(
              children: [
                _detailTile(
                  'Check In',
                  checkIn != null
                      ? DateFormat('hh:mm a')
                          .format(checkIn.toDate())
                      : '—',
                  Icons.login_rounded,
                  const Color(0xFF10B981),
                ),
                const SizedBox(width: 12),
                _detailTile(
                  'Check Out',
                  checkOut != null
                      ? DateFormat('hh:mm a')
                          .format(checkOut.toDate())
                      : '—',
                  Icons.logout_rounded,
                  const Color(0xFFEF4444),
                ),
                const SizedBox(width: 12),
                _detailTile(
                  'Duration',
                  workDuration,
                  Icons.timer_outlined,
                  AppTheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _detailTile(
              'Work Mode',
              mode == 'wfh'
                  ? 'Work From Home'
                  : mode == 'office'
                      ? 'Office'
                      : '—',
              Icons.home_work_outlined,
              const Color(0xFF3B82F6),
              fullWidth: true,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _detailTile(String label, String value, IconData icon,
      Color color, {bool fullWidth = false}) {
    final content = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9CA3AF))),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: content) : Expanded(child: content);
  }

  // ── Exceptions ────────────────────────────────────────────
  Widget _buildExceptionsContent(List<_EmpAttInfo> employees) {
    final shiftParts = AppSession().shiftStartTime.split(':');
    final today = DateTime.now();
    final shiftStart = DateTime(today.year, today.month, today.day,
        int.parse(shiftParts[0]), int.parse(shiftParts[1]));
    final grace = AppSession().gracePeriod;
    final lateThreshold = shiftStart.add(Duration(minutes: grace));

    // Employees with late or absent
    final lateList = employees.where((e) {
      final checkIn = e.attData?['checkIn'] as Timestamp?;
      if (checkIn == null) return false;
      return checkIn.toDate().isAfter(lateThreshold);
    }).toList();

    final absentList =
        employees.where((e) => e.attData == null || e.attData!['checkIn'] == null).toList();

    if (lateList.isEmpty && absentList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.check_circle_outline,
                size: 48, color: Color(0xFF10B981)),
            SizedBox(height: 12),
            Text('No exceptions today!',
                style:
                    TextStyle(fontSize: 15, color: Color(0xFF6B7280))),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (lateList.isNotEmpty) ...[
          _sectionLabel('LATE ARRIVALS · ${lateList.length}'),
          const SizedBox(height: 8),
          ...lateList.map((e) => _buildEmployeeAttRow(
              e, e == lateList.last && absentList.isEmpty)),
          const SizedBox(height: 16),
        ],
        if (absentList.isNotEmpty) ...[
          _sectionLabel('ABSENT TODAY · ${absentList.length}'),
          const SizedBox(height: 8),
          ...absentList.map(
              (e) => _buildEmployeeAttRow(e, e == absentList.last)),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: Color(0xFF9CA3AF),
        letterSpacing: 0.5,
      ),
    );
  }

  // ── Analytics ────────────────────────────────────────────
  Widget _buildAnalyticsContent(
    List<_EmpAttInfo> employees,
    List<QueryDocumentSnapshot> allAttDocs,
    List<QueryDocumentSnapshot> empDocs,
  ) {
    final stats = _computeStats(employees);
    final total = employees.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "TODAY'S BREAKDOWN",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF9CA3AF),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildAnalyticsCard(stats, total),
          const SizedBox(height: 20),
          const Text(
            'ATTENDANCE RATE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF9CA3AF),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildAttendanceRateCard(stats, total),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(Map<String, int> stats, int total) {
    final items = [
      _AnalyticsItem('Present', stats['present']!, total, const Color(0xFF10B981), const Color(0xFFECFDF5)),
      _AnalyticsItem('WFH', stats['wfh']!, total, const Color(0xFF3B82F6), const Color(0xFFEFF6FF)),
      _AnalyticsItem('Late', stats['late']!, total, const Color(0xFFF59E0B), const Color(0xFFFFFBEB)),
      _AnalyticsItem('On Leave', stats['onLeave']!, total, const Color(0xFFAB40FF), const Color(0xFFF5F3FF)),
      _AnalyticsItem('Absent', stats['absent']!, total, const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        children: items.map((item) {
          final pct = total > 0 ? item.count / total : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: item.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(item.label,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937))),
                      ],
                    ),
                    Text(
                      '${item.count} (${(pct * 100).toStringAsFixed(0)}%)',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4B5563)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: pct.clamp(0.0, 1.0),
                  backgroundColor: item.bgColor,
                  color: item.color,
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 6,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAttendanceRateCard(Map<String, int> stats, int total) {
    final presentCount =
        (stats['present'] ?? 0) + (stats['wfh'] ?? 0);
    final rate = total > 0 ? (presentCount / total * 100) : 0.0;
    final rateStr = rate.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$rateStr%',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                  height: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: rate >= 80
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  rate >= 80 ? 'Good' : 'Needs Attention',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: rate >= 80
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$presentCount of $total employees present or WFH',
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: (rate / 100).clamp(0.0, 1.0),
            backgroundColor:
                AppTheme.primary.withValues(alpha: 0.1),
            color: rate >= 80
                ? const Color(0xFF10B981)
                : const Color(0xFFF59E0B),
            borderRadius: BorderRadius.circular(6),
            minHeight: 10,
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0]
          .substring(0, parts[0].length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }
}

// ── Data model ────────────────────────────────────────────
class _EmpAttInfo {
  final String name;
  final String email;
  final String department;
  final String designation;
  final Map<String, dynamic>? attData;

  const _EmpAttInfo({
    required this.name,
    required this.email,
    required this.department,
    required this.designation,
    required this.attData,
  });
}

class _AnalyticsItem {
  final String label;
  final int count;
  final int total;
  final Color color;
  final Color bgColor;
  const _AnalyticsItem(
      this.label, this.count, this.total, this.color, this.bgColor);
}
