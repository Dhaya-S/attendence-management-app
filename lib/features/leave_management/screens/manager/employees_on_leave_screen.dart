import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';

class EmployeesOnLeaveScreen extends StatefulWidget {
  const EmployeesOnLeaveScreen({super.key});

  @override
  State<EmployeesOnLeaveScreen> createState() => _EmployeesOnLeaveScreenState();
}

class _EmployeesOnLeaveScreenState extends State<EmployeesOnLeaveScreen> {
  String _selectedFilter = 'All';
  final _filters = ['All', 'Approved', 'Pending'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Employees On Leave',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Leave Overview
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LEAVE OVERVIEW',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textHint,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: FirestoreService.companyLeaveRequestsQuery
                      .where('status', isEqualTo: 'approved')
                      .snapshots(),
                  builder: (context, snapshot) {
                    int onLeave = 0;
                    if (snapshot.hasData) {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      for (var doc in snapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final fromVal = data['fromDate'];
                        final toVal = data['toDate'];
                        if (fromVal != null && fromVal is Timestamp && 
                            toVal != null && toVal is Timestamp) {
                          final from = fromVal.toDate();
                          final to = toVal.toDate();
                          if (!today.isBefore(
                                  DateTime(from.year, from.month, from.day)) &&
                              !today
                                  .isAfter(DateTime(to.year, to.month, to.day))) {
                            onLeave++;
                          }
                        }
                      }
                    }
                    return Text(
                      'Total Employees on Leave: $onLeave',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((f) {
                      final isActive = _selectedFilter == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedFilter = f),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color:
                                  isActive ? AppTheme.primary : AppTheme.surface,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSM),
                            ),
                            child: Text(
                              f,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color:
                                    isActive ? Colors.white : AppTheme.textMuted,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirestoreService.companyLeaveRequestsQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Filter and Sort in-memory to avoid index requirement
                final docs = snapshot.data!.docs.where((doc) {
                  if (_selectedFilter == 'All') return true;
                  final data = doc.data() as Map<String, dynamic>;
                  return (data['status'] ?? '').toString().toLowerCase() == _selectedFilter.toLowerCase();
                }).toList()
                  ..sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aAt = aData['appliedAt'] as Timestamp?;
                    final bAt = bData['appliedAt'] as Timestamp?;
                    if (aAt == null) return 1;
                    if (bAt == null) return -1;
                    return bAt.compareTo(aAt);
                  });

                if (docs.isEmpty) {
                  return Center(
                    child: Text('No leave records',
                        style: TextStyle(color: AppTheme.textMuted)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data()
                        as Map<String, dynamic>;
                    return _leaveItem(data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaveItem(Map<String, dynamic> data) {
    final name = data['userName'] ?? 'Employee';
    final leaveType = data['leaveType'] ?? 'Leave';
    final from = data['fromDate'] as Timestamp?;
    final to = data['toDate'] as Timestamp?;
    final status = data['status'] ?? 'pending';

    int days = 0;
    if (from != null && to != null) {
      final fromDate = from.toDate();
      final toDate = to.toDate();
      days = toDate.difference(fromDate).inDays + 1;
    }

    Color statusColor;
    switch (status) {
      case 'approved':
        statusColor = AppTheme.success;
        break;
      case 'rejected':
        statusColor = AppTheme.danger;
        break;
      default:
        statusColor = AppTheme.warning;
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
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primarySurface,
            child: Text(
              name.toString().substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        leaveType.toString(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (from != null)
                      Text(
                        '${DateFormat('MMM dd').format(from.toDate())} - ${DateFormat('dd').format(to?.toDate() ?? from.toDate())}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$days Day${days > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toString().toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
