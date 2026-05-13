import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/widgets/notification_action.dart';
import 'package:attendance_app/features/employee_management/screens/manager/employee_detail_screen.dart';
import 'package:attendance_app/widgets/live_attendance_builder.dart';
import 'package:attendance_app/utils/app_session.dart';

class AttendanceStatusDetailScreen extends StatefulWidget {
  final String initialFilter;
  final DateTime? date;
  const AttendanceStatusDetailScreen({
    super.key, 
    required this.initialFilter, 
    this.date,
  });

  @override
  State<AttendanceStatusDetailScreen> createState() => _AttendanceStatusDetailScreenState();
}

class _AttendanceStatusDetailScreenState extends State<AttendanceStatusDetailScreen> {
  String _searchQuery = '';
  late String _currentFilter;

  late final Stream<QuerySnapshot> _usersStream = FirestoreService.companyUsersQuery.snapshots();
  late final Stream<QuerySnapshot> _leaveStream = FirestoreService
      .companyLeaveRequestsQuery
      .where('status', isEqualTo: 'approved')
      .snapshots();

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.initialFilter;
  }

  String get todayDocId {
    final d = widget.date ?? DateTime.now();
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _currentFilter == 'All' ? 'Employee List' : '$_currentFilter Employees',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          NotificationAction(isManager: true),
          SizedBox(width: 16),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _usersStream,
        builder: (context, usersSnapshot) {
          if (!usersSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final allUsers = usersSnapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final role = (data['role'] ?? 'employee').toString().toLowerCase();
            return role != 'manager';
          }).toList();
          final uidToEmail = <String, String>{};
          final emailToUid = <String, String>{};
          for (var doc in allUsers) {
            final data = doc.data() as Map<String, dynamic>;
            final uid = data['uid'] as String?;
            if (uid != null) {
              uidToEmail[uid] = doc.id;
              emailToUid[doc.id] = uid;
            }
          }

          final identifiers = [
            ...emailToUid.keys, // Emails
            ...emailToUid.values, // UIDs
          ];

          return LiveAttendanceBuilder(
            userIds: identifiers,
            dateId: todayDocId,
            builder: (context, records) {
              final attendanceData = <String, Map<String, dynamic>>{};
              for (var data in records) {
                final id = data['userId'] as String?;
                final email = uidToEmail[id] ?? id;
                if (email != null && data['checkIn'] != null) {
                  attendanceData[email] = data;
                }
              }

              return StreamBuilder<QuerySnapshot>(
                stream: _leaveStream,
                builder: (context, leaveSnapshot) {
                  final leaveData = <String, Map<String, dynamic>>{};

                  if (leaveSnapshot.hasData) {
                    final targetDate = widget.date ?? DateTime.now();
                    final today = DateTime(targetDate.year, targetDate.month, targetDate.day);
                    for (var doc in leaveSnapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final userId = data['userId'] as String?; // UID
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
                          if (!today.isBefore(DateTime(from.year, from.month, from.day)) && 
                              !today.isAfter(DateTime(to.year, to.month, to.day))) {
                            leaveData[userId] = data;
                            final email = uidToEmail[userId];
                            if (email != null) leaveData[email] = data;
                          }
                        }
                      } catch (e) {
                         debugPrint('Error parsing leave details: $e');
                      }
                    }
                  }

                  return Column(
                    children: [
                      _buildSearchBar(),
                      _buildFilterChips(),
                      Expanded(
                        child: _buildEmployeeList(allUsers, attendanceData, leaveData),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        ),
        child: TextField(
          onChanged: (v) => setState(() => _searchQuery = v),
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search, color: AppTheme.textHint, size: 20),
            hintText: 'Search employee...',
            hintStyle: TextStyle(color: AppTheme.textHint, fontSize: 14),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'Present', 'Late', 'Leave', 'Absent', 'WFH'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final isActive = _currentFilter == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _currentFilter = f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.primary : AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: Text(
                    f,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : AppTheme.textMuted,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmployeeList(
    List<QueryDocumentSnapshot> allUsers,
    Map<String, Map<String, dynamic>> attendanceData,
    Map<String, Map<String, dynamic>> leaveData,
  ) {
    final filteredUsers = allUsers.where((doc) {
      final userData = doc.data() as Map<String, dynamic>;
      final name = (userData['name'] ?? userData['email'] ?? '').toString().toLowerCase();
      if (!name.contains(_searchQuery.toLowerCase())) return false;

      final userId = doc.id;
      final att = attendanceData[userId];
      final leave = leaveData[userId];

      if (_currentFilter == 'All') return true;
      if (_currentFilter == 'Present') return att != null;
      if (_currentFilter == 'Late') {
        if (att == null) return false;
        final workMode = att['workMode'] as String?;
        if (workMode == 'wfh') return false;
        
        final checkInTs = att['checkIn'] as Timestamp?;
        if (checkInTs == null) return false;
        final checkIn = checkInTs.toDate();
        final remarkStatus = att['remarkStatus'] as String?;
        final sParts = AppSession().shiftStartTime.split(':');
        final lateThreshold = DateTime(checkIn.year, checkIn.month, checkIn.day,
            int.parse(sParts[0]), int.parse(sParts[1]))
            .add(Duration(minutes: AppSession().gracePeriod));
        return checkIn.isAfter(lateThreshold) && remarkStatus != 'approved';
      }
      if (_currentFilter == 'Leave') return leave != null;
      if (_currentFilter == 'Absent') return att == null && leave == null;
      if (_currentFilter == 'WFH') return att != null && att['workMode'] == 'wfh';
      return true;
    }).toList();

    if (filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: AppTheme.textHint),
            const SizedBox(height: 16),
            Text('No employees found', style: TextStyle(fontSize: 16, color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        final doc = filteredUsers[index];
        final userData = doc.data() as Map<String, dynamic>;
        final userId = doc.id;
        final att = attendanceData[userId];
        final leave = leaveData[userId];
        String status = 'Absent';
        Color statusColor = AppTheme.danger;
        String? workMode;

        if (att != null) {
          workMode = att['workMode'] as String?;
          if (workMode == 'wfh') {
            status = 'WFH';
            statusColor = const Color(0xFF6366F1);
          } else {
            status = 'Present';
            statusColor = AppTheme.success;
          }
          
          final checkInTs = att['checkIn'] as Timestamp?;
          if (checkInTs != null) {
            final checkIn = checkInTs.toDate();
          final sParts = AppSession().shiftStartTime.split(':');
          final lateThreshold = DateTime(checkIn.year, checkIn.month, checkIn.day,
              int.parse(sParts[0]), int.parse(sParts[1]))
              .add(Duration(minutes: AppSession().gracePeriod));
            if (checkIn.isAfter(lateThreshold) && status != 'WFH') {
              status = 'Late';
              statusColor = AppTheme.warning;
            }
          }
        } else if (leave != null) {
          status = 'On Leave';
          statusColor = AppTheme.primary;
        }

        return _employeeCard(context, userId, userData, status, statusColor, workMode);
      },
    );
  }

  Widget _employeeCard(BuildContext context, String docId, Map<String, dynamic> data, String status, Color statusColor, String? workMode) {
    final name = data['name'] ?? data['email']?.toString().split('@')[0] ?? 'Employee';
    final role = data['designation'] ?? data['role'] ?? 'Employee';
    final imageUrl = data['profileImageUrl'] as String?;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EmployeeDetailScreen(employeeId: docId, employeeData: data),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primary.withOpacity(0.2), width: 2),
              ),
              child: ClipOval(
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? (imageUrl.startsWith('http')
                        ? Image.network(imageUrl, fit: BoxFit.cover)
                        : Image.memory(base64Decode(imageUrl), fit: BoxFit.cover))
                    : Container(
                        color: AppTheme.primarySurface,
                        child: Center(
                          child: Text(
                            name.toString().substring(0, 1).toUpperCase(),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.primary),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.toString(),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                  Text(
                    role.toString(),
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  if (workMode == 'wfh')
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.home_work_rounded, size: 10, color: Color(0xFF6366F1)),
                          SizedBox(width: 4),
                          Text(
                            'WFH',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (status == 'Absent' || status == 'On Leave')
                    _BlinkingDot(color: statusColor)
                  else
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                  const SizedBox(width: 4),
                  Text(
                    status,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  final Color color;
  const _BlinkingDot({required this.color});

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
