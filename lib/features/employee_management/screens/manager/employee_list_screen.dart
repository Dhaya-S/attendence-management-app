import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/widgets/notification_action.dart';
import 'package:attendance_app/features/employee_management/screens/manager/employee_detail_screen.dart';
import 'package:attendance_app/features/employee_management/screens/manager/add_employee_screen.dart';
import 'package:attendance_app/widgets/live_attendance_builder.dart';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'All';
  final _filters = ['All', 'Present', 'Late', 'Leave', 'Absent'];

  String get todayDocId {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  late final Stream<QuerySnapshot> _usersStream = FirestoreService.companyUsersQuery.snapshots();
  late final Stream<QuerySnapshot> _leaveStream = FirestoreService.companyLeaveRequestsQuery
      .where('status', isEqualTo: 'approved')
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Employee List',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: const [
          NotificationAction(isManager: true),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AddEmployeeScreen()));
        },
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
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

          final identifiers = <String>[
            ...allUsers.map((u) => u.id), // All Emails
            ...uidToEmail.keys, // All UIDs
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
                    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                    for (var doc in leaveSnapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final userId = data['userId'] as String?; // This is UID from Firestore
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
                            // Map leave data to both UID and Email if possible, or just Email for UI lookup
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
                      // Search bar
                      Container(
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
                      ),

                      // Filter chips
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _filters.map((f) {
                              final isActive = _selectedFilter == f;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedFilter = f),
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
                      ),

                      // Employee list
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
      final isOnLeave = leaveData[userId] != null;

      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Present') return att != null;
      if (_selectedFilter == 'Late') {
        if (att == null) return false;
        final checkInTs = att['checkIn'] as Timestamp?;
        if (checkInTs == null) return false;
        final checkIn = checkInTs.toDate();
        final lateThreshold = DateTime(checkIn.year, checkIn.month, checkIn.day, 9, 30);
        return checkIn.isAfter(lateThreshold);
      }
      if (_selectedFilter == 'Leave') return isOnLeave;
      if (_selectedFilter == 'Absent') return att == null && !isOnLeave;
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

        if (att != null) {
          final workMode = att['workMode'] as String?;
          if (workMode == 'wfh') {
            status = 'WFH';
            statusColor = const Color(0xFF5C5CFF);
          } else {
            status = 'Present';
            statusColor = AppTheme.success;
          }
          
          final checkInTs = att['checkIn'] as Timestamp?;
          if (checkInTs != null) {
            final checkIn = checkInTs.toDate();
            // Assuming 9:30 AM as late threshold
            final lateThreshold = DateTime(checkIn.year, checkIn.month, checkIn.day, 9, 30);
            if (checkIn.isAfter(lateThreshold) && status != 'WFH') {
              status = 'Late';
              statusColor = AppTheme.warning;
            }
          }
        } else if (leave != null) {
          status = 'On Leave';
          statusColor = AppTheme.primary;
        }

        final workMode = att?['workMode'] as String?;

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
                        color: const Color(0xFF5C5CFF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.home_work_rounded, size: 10, color: Color(0xFF5C5CFF)),
                          SizedBox(width: 4),
                          Text(
                            'WFH',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF5C5CFF),
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
