import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/widgets/notification_action.dart';

class OvertimeReportScreen extends StatefulWidget {
  const OvertimeReportScreen({super.key});

  @override
  State<OvertimeReportScreen> createState() => _OvertimeReportScreenState();
}

class _OvertimeReportScreenState extends State<OvertimeReportScreen> {
  DateTime _selectedMonth = DateTime.now();
  bool _showAll = false;
  late final Stream<QuerySnapshot> _usersStream = FirestoreService.companyUsersQuery.snapshots();
  late final Stream<QuerySnapshot> _recordsStream =
      FirestoreService.allAttendanceRecordsCol.snapshots();

  @override
  void initState() {
    super.initState();
  }

  static const Color _indigo = Color(0xFF6366F1);
  static const Color _slate = Color(0xFF1E293B);

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
  }

  String get _monthString => DateFormat('MMMM yyyy').format(_selectedMonth);

  double _calculateOvertime(Map<String, dynamic> record) {
    final checkIn = record['checkIn'] as Timestamp?;
    final checkOut = record['checkOut'] as Timestamp?;
    
    if (checkIn == null || checkOut == null) return 0.0;

    final duration = checkOut.toDate().difference(checkIn.toDate());
    final hoursWorked = duration.inMinutes / 60.0;
    
    // Dynamic standard hours from company shift settings
    final sParts = AppSession().shiftStartTime.split(':');
    final eParts = AppSession().shiftEndTime.split(':');
    final startH = int.parse(sParts[0]) + int.parse(sParts[1]) / 60.0;
    final endH = int.parse(eParts[0]) + int.parse(eParts[1]) / 60.0;
    final standardHours = endH - startH;
    
    if (hoursWorked > standardHours) {
      return hoursWorked - standardHours;
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _slate, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Monthly Overtime',
          style: TextStyle(color: _slate, fontSize: 18, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        actions: [
          NotificationAction(isManager: true),
          SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          _buildMonthSelector(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _usersStream,
              builder: (context, usersSnapshot) {
                if (!usersSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = usersSnapshot.data!.docs;
                final employeeMap = <String, Map<String, dynamic>>{};
                for (var u in users) {
                  final data = u.data() as Map<String, dynamic>;
                  final role = (data['role'] ?? 'employee').toString().toLowerCase();
                  if (role == 'employee') {
                    employeeMap[u.id] = data;
                  }
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: _recordsStream,
                  builder: (context, recordsSnapshot) {
                    if (!recordsSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Calculate overtime per user
                    Map<String, double> overtimeMap = {};
                    Map<String, int> sessionCount = {};
                    Map<String, Map<String, dynamic>> fallbackUserInfo = {};

                    for (var recordDoc in recordsSnapshot.data!.docs) {
                      final data = recordDoc.data() as Map<String, dynamic>;
                      final dateTs = data['date'] as Timestamp?;
                      if (dateTs == null) continue;

                      final date = dateTs.toDate();
                      if (date.isBefore(firstDay) || date.isAfter(lastDay)) continue;

                      final uid = data['userId'] ?? data['uid'] ?? recordDoc.reference.parent.parent?.id;
                      if (uid == null) continue;

                      // Only consider overtime if we either know they are an employee or the record says so
                      final isKnownEmployee = employeeMap.containsKey(uid);
                      
                      double ot = _calculateOvertime(data);
                      if (ot > 0 && (isKnownEmployee || data['userName'] != null)) {
                        overtimeMap[uid] = (overtimeMap[uid] ?? 0) + ot;
                        sessionCount[uid] = (sessionCount[uid] ?? 0) + 1;
                        
                        if (!isKnownEmployee && data['userName'] != null) {
                          fallbackUserInfo[uid] = {
                            'name': data['userName'],
                            'imageUrl': data['userAvatar'],
                            'role': 'Employee',
                          };
                        }
                      }
                    }

                    List<Map<String, dynamic>> employeeList = [];
                    for (var uid in overtimeMap.keys) {
                      final totalOT = overtimeMap[uid] ?? 0.0;
                      final userData = employeeMap[uid] ?? fallbackUserInfo[uid];
                      
                      if (userData != null) {
                        employeeList.add({
                          'uid': uid,
                          'name': userData['name'] ?? 'Employee',
                          'role': userData['designation'] ?? userData['role'] ?? 'Employee',
                          'imageUrl': userData['profileImageUrl'] ?? userData['imageUrl'],
                          'totalOT': totalOT,
                          'counts': sessionCount[uid] ?? 0,
                        });
                      }
                    }

                    // Sort by overtime descending
                    employeeList.sort((a, b) => (b['totalOT'] as double).compareTo(a['totalOT'] as double));

                    final displayList = _showAll ? employeeList : employeeList.take(3).toList();

                    return Column(
                      children: [
                        if (employeeList.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(40.0),
                            child: Center(
                              child: Text(
                                'No overtime recorded for this month.',
                                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        if (employeeList.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _showAll ? 'All Employees with Overtime' : 'Top Employees in Overtime',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF6B7280),
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            itemCount: displayList.length,
                            itemBuilder: (context, index) {
                              final item = displayList[index];
                              return _buildOvertimeCard(item['name'], item['role'], item['imageUrl'], item['totalOT'], item['counts'], index + 1);
                            },
                          ),
                        ),
                        if (employeeList.length > 3)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: TextButton(
                                onPressed: () => setState(() => _showAll = !_showAll),
                                child: Text(
                                  _showAll ? 'Show Less' : 'See All',
                                  style: const TextStyle(color: _indigo, fontWeight: FontWeight.w700),
                                ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, color: _indigo),
            onPressed: _previousMonth,
          ),
          Text(
            _monthString,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _slate),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, color: _indigo),
            onPressed: _nextMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildOvertimeCard(String name, String role, String? imageUrl, double totalHours, int sessions, int rank) {
    Color medalColor;
    IconData? medalIcon;
    if (rank == 1) {
      medalColor = const Color(0xFFFFD700); // Gold
      medalIcon = Icons.emoji_events;
    } else if (rank == 2) {
      medalColor = const Color(0xFFC0C0C0); // Silver
      medalIcon = Icons.military_tech;
    } else if (rank == 3) {
      medalColor = const Color(0xFFCD7F32); // Bronze
      medalIcon = Icons.military_tech;
    } else {
      medalColor = Colors.transparent;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: medalColor != Colors.transparent ? Border.all(color: medalColor, width: 2) : Border.all(color: AppTheme.primary.withOpacity(0.2), width: 2),
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
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              if (medalIcon != null)
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(medalIcon, color: medalColor, size: 18),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  role,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          // Right-side overtime stats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.schedule,
                  size: 12,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${totalHours.toStringAsFixed(1)}h',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
