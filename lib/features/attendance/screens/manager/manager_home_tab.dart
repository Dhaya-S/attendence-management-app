import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/features/employee_management/screens/manager/employee_list_screen.dart';
import 'package:attendance_app/features/leave_management/screens/manager/leave_approval_screen.dart';
import 'package:attendance_app/features/attendance/screens/manager/attendance_correction_screen.dart';
import 'package:attendance_app/screens/employee/attendance_history_screen.dart';
import 'package:attendance_app/features/settings/screens/manager/manager_notifications_screen.dart';
import 'package:attendance_app/features/attendance/screens/manager/late_adjustment_review_screen.dart';
import 'package:attendance_app/features/settings/screens/manager/manager_profile_tab.dart';
import 'package:attendance_app/features/attendance/screens/manager/attendance_status_detail_screen.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';
import 'package:attendance_app/widgets/live_attendance_builder.dart';
import 'package:attendance_app/widgets/notification_action.dart';
import 'package:attendance_app/features/attendance/screens/manager/overtime_report_screen.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';

class ManagerHomeTab extends StatefulWidget {
  final Function(int)? onTabChange;
  const ManagerHomeTab({super.key, this.onTabChange});

  @override
  State<ManagerHomeTab> createState() => _ManagerHomeTabState();
}

class _ManagerHomeTabState extends State<ManagerHomeTab> {
  final user = FirebaseAuth.instance.currentUser;
  late final Stream<QuerySnapshot> _usersStream = FirestoreService.companyUsersQuery.snapshots();
  late final Stream<DocumentSnapshot> _currentUserStream =
      FirestoreService.userStreamByEmail(user?.email ?? '');

  @override
  void initState() {
    super.initState();
  }

  void _navigateToStatusDetail(String filter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceStatusDetailScreen(initialFilter: filter),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  String get todayDocId {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: const Color(0xffF4F6F9),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeHeader(),
              const SizedBox(height: 24),
              // Single StreamBuilder provides data to both stat cards and team presence
              _buildDashboardBody(),
              const SizedBox(height: 24),
              _buildLeaveRequestsPreview(),
              const SizedBox(height: 24),
              _buildQuickActions(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  // Unified builder — fetches users + attendance ONCE and shares between children
  Widget _buildDashboardBody() {
    return StreamBuilder<QuerySnapshot>(
      stream: _usersStream,
      builder: (context, usersSnapshot) {
        if (!usersSnapshot.hasData) {
          return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
        }
        final employees = usersSnapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data['role'] ?? 'employee').toString().toLowerCase() != 'manager';
        }).toList();
        final uidToEmail = <String, String>{};
        final emailToUid = <String, String>{};
        for (var doc in employees) {
          final data = doc.data() as Map<String, dynamic>;
          final uid = data['uid'] as String?;
          if (uid != null) {
            uidToEmail[uid] = doc.id;
            emailToUid[doc.id] = uid;
          }
        }

        final identifiers = <String>[
          ...employees.map((e) => e.id), // All Emails
          ...uidToEmail.keys, // All UIDs
        ];
        final totalEmployees = employees.length;

        return LiveAttendanceBuilder(
          userIds: identifiers,
          builder: (context, records) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirestoreService.companyLeaveRequestsQuery
                  .where('status', isEqualTo: 'approved')
                  .snapshots(),
              builder: (context, leaveSnapshot) {
                final leaveData = <String, Map<String, dynamic>>{};
                if (leaveSnapshot.hasData) {
                  final today = DateTime.now();
                  final todayDate = DateTime(today.year, today.month, today.day);
                  for (var doc in leaveSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final userId = data['userId'] as String?;
                    if (userId == null) continue;
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
                          final key = data['userEmail'] as String? ?? userId;
                          if (key != null) leaveData[key] = data;
                        }
                      }
                    } catch (e) {
                      debugPrint('Error parsing leave: $e');
                    }
                  }
                }

                int presentToday = 0;
                int lateCount = 0;
                int wfhCount = 0;
                final presentUids = <String>{};

                for (var data in records) {
                  final id = data['userId'] as String?;
                  final email = uidToEmail[id] ?? id;
                  if (email != null && data['checkIn'] != null) {
                    presentToday++;
                    presentUids.add(email);
                    
                    final workMode = data['workMode'] as String?;
                    if (workMode == 'wfh') wfhCount++;

                    final checkInTs = data['checkIn'] as Timestamp?;
                    if (checkInTs != null) {
                      final checkIn = checkInTs.toDate();
                      final remarkStatus = data['remarkStatus'] as String?;
                      
                      final sParts = AppSession().shiftStartTime.split(':');
                      final lateThreshold = DateTime(checkIn.year, checkIn.month, checkIn.day,
                          int.parse(sParts[0]), int.parse(sParts[1]))
                          .add(Duration(minutes: AppSession().gracePeriod));

                      // Don't mark WFH as late unless specified, or just keep original logic
                      if (checkIn.isAfter(lateThreshold) && remarkStatus != 'approved' && workMode != 'wfh') {
                        lateCount++;
                      }
                    }
                  }
                }

                int actualOnLeave = 0;
                for (var email in emailToUid.keys) {
                  if (leaveData.containsKey(email) && !presentUids.contains(email)) {
                    actualOnLeave++;
                  }
                }

                final percent = totalEmployees > 0 ? (presentToday / totalEmployees * 100).round() : 0;

                return Column(
                  children: [
                    // Stat cards
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _statCard(icon: Icons.group_outlined, iconColor: const Color(0xFF8B5CF6), value: '$totalEmployees', valueColor: const Color(0xFF1F2937), label: 'Total Employees', onTap: () => _navigateToStatusDetail('All'))),
                              const SizedBox(width: 16),
                              Expanded(child: _statCard(icon: Icons.check_circle_outline_rounded, iconColor: const Color(0xFF10B981), value: '$presentToday', valueColor: const Color(0xFF10B981), label: 'Present Today', onTap: () => _navigateToStatusDetail('Present'))),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _statCard(icon: Icons.calendar_today_outlined, iconColor: const Color(0xFFF97316), value: '$actualOnLeave', valueColor: const Color(0xFFF97316), label: 'On Leave', onTap: () => _navigateToStatusDetail('Leave'))),
                              const SizedBox(width: 16),
                              Expanded(child: _statCard(icon: Icons.alarm_rounded, iconColor: const Color(0xFFEF4444), value: '$lateCount', valueColor: const Color(0xFFEF4444), label: 'Late', onTap: () => _navigateToStatusDetail('Late'))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Team Presence (reuses same data)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Team Presence', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                                Text('$percent%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF6366F1))),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: percent / 100,
                                backgroundColor: const Color(0xFFEEF2FF),
                                valueColor: const AlwaysStoppedAnimation(Color(0xFF6366F1)),
                                minHeight: 10,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                 Text('Present: $presentToday', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
                                const Text('Goal: 100%', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // ─── Welcome Header ───────────────────────────────────────────────────
  Widget _buildWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          // Avatar
          GestureDetector(
            onTap: () => widget.onTabChange?.call(3),
            child: StreamBuilder<DocumentSnapshot>(
              stream: _currentUserStream,
              builder: (context, snapshot) {
                String? imageUrl;
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  imageUrl = data['profileImageUrl'];
                }
                return Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? (imageUrl.startsWith('http')
                            ? Image.network(imageUrl, fit: BoxFit.cover)
                            : Image.memory(base64Decode(imageUrl),
                                fit: BoxFit.cover))
                        : Container(
                            color: const Color(0xFF1E3A5F),
                            child: const Icon(Icons.person, color: Colors.white, size: 26),
                          ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: _currentUserStream,
              builder: (context, snapshot) {
                final data = snapshot.data?.data() as Map<String, dynamic>?;
                final sessionName = AppSession().userName;
                final authName = user?.displayName;
                
                String rawName = 'Manager';
                if (data?['name'] != null && data!['name'].toString().trim().isNotEmpty) {
                  rawName = data['name'].toString();
                } else if (sessionName != null && sessionName.trim().isNotEmpty) {
                  rawName = sessionName;
                } else if (authName != null && authName.trim().isNotEmpty) {
                  rawName = authName;
                }
                
                final firstName = rawName.split(' ')[0];
                final greeting = _getGreeting();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$greeting,',
                      style: AppTheme.bodySmall.copyWith(
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      firstName,
                      style: AppTheme.h1.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 10,
                          color: Colors.black.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('EEEE, MMM d').format(DateTime.now()),
                          style: AppTheme.label.copyWith(
                            fontSize: 10,
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          // Notification bell with badge
          NotificationAction(isManager: true, backgroundColor: Color(0xFFF3F4F6)),
        ],
      ),
    );
  }

  // ─── Stat Cards (now handled inside _buildDashboardBody) ────────────
  Widget _buildStatCards_UNUSED() {
    return StreamBuilder<QuerySnapshot>(
      stream: _usersStream,
          builder: (context, usersSnapshot) {
            if (!usersSnapshot.hasData) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
                final employees = usersSnapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final role = (data['role'] ?? 'employee').toString().toLowerCase();
                  return role != 'manager';
                }).toList();
                
                final totalEmployees = employees.length;
                final employeeIds = employees.map((d) => d.id).toList();

                return LiveAttendanceBuilder(
                  userIds: employeeIds,
                  builder: (context, records) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirestoreService.companyLeaveRequestsQuery
                          .where('status', isEqualTo: 'approved')
                          .snapshots(),
                      builder: (context, leaveSnapshot) {
                        final leaveData = <String, Map<String, dynamic>>{};
                        if (leaveSnapshot.hasData) {
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          for (var doc in leaveSnapshot.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            final userId = data['userId'] as String?;
                            if (userId == null) continue;
                            
                            try {
                              final fromTs = data['fromDate'];
                              final toTs = data['toDate'];
                              if (fromTs == null || toTs == null) continue;
                              
                              DateTime? from;
                              DateTime? to;
                              
                              if (fromTs is Timestamp) from = fromTs.toDate();
                              else if (fromTs is String) from = DateTime.tryParse(fromTs);
                              
                              if (toTs is Timestamp) to = toTs.toDate();
                              else if (toTs is String) to = DateTime.tryParse(toTs);
                              
                              if (from != null && to != null) {
                                final fromDate = DateTime(from.year, from.month, from.day);
                                final toDate = DateTime(to.year, to.month, to.day);
                                if (!today.isBefore(fromDate) && !today.isAfter(toDate)) {
                                  leaveData[userId] = data;
                                }
                              }
                            } catch (e) {
                              debugPrint('Error parsing leave details: $e');
                            }
                          }
                        }

                        int presentToday = 0;
                        int lateCount = 0;
                        for (var data in records) {
                          final userId = data['userId'] as String?;
                          if (userId != null && employeeIds.contains(userId) && data['checkIn'] != null) {
                            presentToday++;
                            final checkInTs = data['checkIn'] as Timestamp?;
                            if (checkInTs != null) {
                              final checkIn = checkInTs.toDate();
                              final remarkStatus = data['remarkStatus'] as String?;
                              
                              final sParts = AppSession().shiftStartTime.split(':');
                              final lateThreshold = DateTime(checkIn.year, checkIn.month, checkIn.day,
                                  int.parse(sParts[0]), int.parse(sParts[1]))
                                  .add(Duration(minutes: AppSession().gracePeriod));

                              if (checkIn.isAfter(lateThreshold) && remarkStatus != 'approved') lateCount++;
                            }
                          }
                        }

                        // On Leave: Approved leave for today, but only for employees in our list
                        int actualOnLeave = 0;
                        for (var uid in employeeIds) {
                          if (leaveData.containsKey(uid) && !records.any((r) => r['userId'] == uid && r['checkIn'] != null)) {
                            actualOnLeave++;
                          }
                        }

                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _statCard(
                                    icon: Icons.group_outlined,
                                    iconColor: const Color(0xFF8B5CF6),
                                    value: '$totalEmployees',
                                    valueColor: const Color(0xFF1F2937),
                                    label: 'Total Employees',
                                    onTap: () => _navigateToStatusDetail('All'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _statCard(
                                    icon: Icons.check_circle_outline_rounded,
                                    iconColor: const Color(0xFF10B981),
                                    value: '$presentToday',
                                    valueColor: const Color(0xFF10B981),
                                    label: 'Present Today',
                                    onTap: () => _navigateToStatusDetail('Present'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _statCard(
                                    icon: Icons.calendar_today_outlined,
                                    iconColor: const Color(0xFFF97316),
                                    value: '$actualOnLeave',
                                    valueColor: const Color(0xFFF97316),
                                    label: 'On Leave',
                                    onTap: () => _navigateToStatusDetail('Leave'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _statCard(
                                    icon: Icons.alarm_rounded,
                                    iconColor: const Color(0xFFEF4444),
                                    value: '$lateCount',
                                    valueColor: const Color(0xFFEF4444),
                                    label: 'Late',
                                    onTap: () => _navigateToStatusDetail('Late'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
          },
        );

  }

  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required Color valueColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Team Presence (now handled inside _buildDashboardBody) ──────────
  Widget _buildTeamPresence_UNUSED() {
    return StreamBuilder<QuerySnapshot>(
      stream: _usersStream,
      builder: (context, usersSnapshot) {
        final totalEmpFallback = usersSnapshot.data?.docs.length ?? 0;

        if (!usersSnapshot.hasData) return const SizedBox.shrink();

        final employees = usersSnapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final role = (data['role'] ?? 'employee').toString().toLowerCase();
          return role != 'manager';
        }).toList();
        final totalEmp = employees.length;
        final employeeIds = employees.map((d) => d.id).toList();

        return LiveAttendanceBuilder(
          userIds: employeeIds,
          builder: (context, records) {
            int present = 0;
            for (var data in records) {
              final userId = data['userId'] as String?;
              if (userId != null && employeeIds.contains(userId) && data['checkIn'] != null) present++;
            }
            final percent = totalEmp > 0 ? (present / totalEmp * 100).round() : 0;

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Team Presence',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        '$percent%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: percent / 100,
                      backgroundColor: const Color(0xFFEEF2FF), // faint blue
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF6366F1)),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Present: $present Employees',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Text(
                        'Goal: 100%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── Leave Requests Preview ───────────────────────────────────────────
  Widget _buildLeaveRequestsPreview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Leave Requests',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirestoreService.companyLeaveRequestsQuery
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.data?.docs.length ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: count > 0 ? const Color(0xFFFFE4E6) : const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count PENDING',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: count > 0 ? const Color(0xFFE11D48) : const Color(0xFF059669),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LeaveApprovalScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
            ),
            child: Row(
              children: [
                // Mockup has overlapping avatars, we'll use an icon for simplicity
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.people_alt_rounded, color: Color(0xFF4B5563), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Check Leave Requests',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Waiting for your review',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1), // Royal blue / purple
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Review All',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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


  // ─── Quick Actions ────────────────────────────────────────────────────
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'QUICK ACTIONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _quickActionBtn(
                Icons.badge_outlined,
                'History',
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EmployeeListScreen(),
                    ),
                  );
                },
              ),
              _quickActionBtn(
                Icons.calendar_today_outlined,
                'Calendar',
                () => widget.onTabChange?.call(1),
              ),
              _quickActionBtn(
                Icons.check_circle_outline_rounded,
                'Overtime',
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OvertimeReportScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickActionBtn(IconData icon, String label, VoidCallback onTap) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 56) / 3, // Precise 3-column split with spacing
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFF4B5563), size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4B5563),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

