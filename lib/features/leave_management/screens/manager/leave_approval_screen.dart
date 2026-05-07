import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/widgets/notification_action.dart';
import 'package:attendance_app/features/leave_management/screens/manager/leave_detail_screen.dart';

class LeaveApprovalScreen extends StatefulWidget {
  const LeaveApprovalScreen({super.key});

  @override
  State<LeaveApprovalScreen> createState() => _LeaveApprovalScreenState();
}

class _LeaveApprovalScreenState extends State<LeaveApprovalScreen> {
  String _selectedTab = 'Pending';
  final _tabs = ['Pending', 'Approved', 'Rejected'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Leave Approvals',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          NotificationAction(isManager: true),
        ],
      ),
      body: Column(
        children: [
          // Tab filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: _tabs.map((t) {
                final isActive = _selectedTab == t;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? AppTheme.primary : AppTheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      ),
                      child: Text(
                        t,
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

          // List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirestoreService.allLeaveRequestsQuery
                  .where('status', isEqualTo: _selectedTab.toLowerCase())
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
                          const SizedBox(height: 16),
                          Text('Error loading requests', style: AppTheme.h3),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 64, color: AppTheme.textHint),
                        const SizedBox(height: 16),
                        Text(
                          'No ${_selectedTab.toLowerCase()} requests',
                          style: TextStyle(
                              fontSize: 16, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  );
                }

                // Sort in-memory to avoid index requirement
                final docs = snapshot.data!.docs.toList()
                  ..sort((a, b) {
                    final aDate = (a.data() as Map<String, dynamic>)['requestDate'] as Timestamp?;
                    final bDate = (b.data() as Map<String, dynamic>)['requestDate'] as Timestamp?;
                    if (aDate == null) return 1;
                    if (bDate == null) return -1;
                    return bDate.compareTo(aDate); // Sort descending
                  });

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _leaveCard(context, doc.reference, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaveCard(
      BuildContext context, DocumentReference docRef, Map<String, dynamic> data) {
    final name = data['userName'] ?? 'Employee';
    final role = data['department'] ?? 'Team';
    final reason = data['reason'] ?? '';
    final leaveType = data['leaveType'] ?? 'Leave';
    final from = data['fromDate'] as Timestamp?;
    final to = data['toDate'] as Timestamp?;
    final status = data['status'] ?? 'pending';

    Color typeColor;
    switch (leaveType.toString().toLowerCase()) {
      case 'sick leave':
        typeColor = AppTheme.info;
        break;
      case 'casual leave':
        typeColor = AppTheme.success;
        break;
      case 'annual leave':
        typeColor = AppTheme.warning;
        break;
      default:
        typeColor = AppTheme.primary;
    }

    int days = 0;
    if (from != null && to != null) {
      days = to.toDate().difference(from.toDate()).inDays + 1;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LeaveDetailScreen(leaveRef: docRef, leaveData: data),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          boxShadow: AppTheme.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.primarySurface,
                  child: Text(
                    name.toString().substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
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
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        role.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Leave type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                leaveType.toString().toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: typeColor,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Date & duration
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: AppTheme.textHint),
                const SizedBox(width: 4),
                Text(
                  from != null && to != null
                      ? '${DateFormat('MMM dd').format(from.toDate())} - ${DateFormat('MMM dd').format(to.toDate())} ($days Days)'
                      : 'No dates',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Reason
            Text(
              '"$reason"',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Approve/Reject buttons (only for pending)
            if (status == 'pending') ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: ElevatedButton(
                        onPressed: () => _updateLeaveStatus(docRef, 'approved', data),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSM),
                          ),
                        ),
                        child: const Text('Approve',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: OutlinedButton(
                        onPressed: () => _updateLeaveStatus(docRef, 'rejected', data),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.danger,
                          side: const BorderSide(color: AppTheme.danger),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSM),
                          ),
                        ),
                        child: const Text('Reject',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _updateLeaveStatus(DocumentReference docRef, String newStatus, Map<String, dynamic> data) async {
    try {
      // 1. First, update the leave request status
      await docRef.update({
        'status': newStatus,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Leave ${newStatus == 'approved' ? 'approved' : 'rejected'} successfully'),
            backgroundColor: newStatus == 'approved' ? AppTheme.success : AppTheme.danger,
          ),
        );
      }

      // 2. Separately try to notify the employee
      try {
        await FirestoreService.userNotificationsCol(data['userEmail'] ?? '').add({
          'companyId': FirestoreService.companyId,
          'userId': data['userId'],
          'title': newStatus == 'approved' ? 'Leave Approved' : 'Leave Rejected',
          'body': 'Your ${data['leaveType']} request has been ${newStatus}.',
          'type': newStatus == 'approved' ? 'leave_approved' : 'leave_rejected',
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (notifError) {
        debugPrint('Notification could not be sent: $notifError');
        // We don't show a blocking error here because the leave was already approved
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error: $e';
        if (e.toString().contains('permission-denied')) {
          errorMessage = 'Permission Denied: You do not have permission to update this leave request.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: AppTheme.danger),
        );
      }
    }
  }
}
