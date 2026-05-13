import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';

class LeaveDetailScreen extends StatelessWidget {
  final DocumentReference leaveRef;
  final Map<String, dynamic> leaveData;

  const LeaveDetailScreen({
    super.key,
    required this.leaveRef,
    required this.leaveData,
  });

  @override
  Widget build(BuildContext context) {
    final name = leaveData['userName'] ?? 'Employee';
    final role = leaveData['department'] ?? 'Team';
    final reason = leaveData['reason'] ?? '';
    final leaveType = leaveData['leaveType'] ?? 'Leave';
    final from = leaveData['fromDate'] as Timestamp?;
    final to = leaveData['toDate'] as Timestamp?;
    final status = leaveData['status'] ?? 'pending';

    int days = 0;
    if (from != null && to != null) {
      days = to.toDate().difference(from.toDate()).inDays + 1;
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Leave Request Detail',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppTheme.primarySurface,
                    child: Text(
                      name.toString().substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name.toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    role.toString(),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.successLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '● Active',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Leave Details
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Leave Details',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _detailRow('Leave Type', leaveType.toString()),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Duration',
                                style: TextStyle(
                                    fontSize: 12, color: AppTheme.textHint)),
                            const SizedBox(height: 4),
                            Text(
                              from != null && to != null
                                  ? '${DateFormat('MMM dd, yyyy').format(from.toDate())} - ${DateFormat('MMM dd, yyyy').format(to.toDate())}'
                                  : 'No dates',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.infoLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$days Days',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.info,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Reason
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reason',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    reason.isNotEmpty ? reason : 'No reason provided',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const SizedBox(height: 24),

            // Actions (only for pending)
            if (status == 'pending')
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => _updateStatus(context, 'rejected'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.danger,
                          side: const BorderSide(color: AppTheme.danger),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMD),
                          ),
                        ),
                        child: const Text('Reject',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => _updateStatus(context, 'approved'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMD),
                          ),
                        ),
                        child: const Text('Approve Request',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary)),
      ],
    );
  }

  void _updateStatus(BuildContext context, String newStatus) async {
    try {
      await leaveRef.update({
        'status': newStatus,
        'reviewedAt': FieldValue.serverTimestamp(),
      });

      // Notify Employee
      String employeeEmail = leaveData['userEmail'] ?? '';
      if (employeeEmail.isEmpty) {
        // Robust fallback: extract email from path approved_companies/{cid}/users/{email}/leave_requests/{id}
        final parts = leaveRef.path.split('/');
        final usersIdx = parts.indexOf('users');
        if (usersIdx != -1 && usersIdx + 1 < parts.length) {
          employeeEmail = parts[usersIdx + 1];
        }
      }

      if (employeeEmail.isNotEmpty) {
        await FirestoreService.userNotificationsCol(employeeEmail).add({
          'companyId': FirestoreService.companyId,
          'userId': leaveData['userId'],
          'title': newStatus == 'approved' ? 'Leave Approved' : 'Leave Rejected',
          'body': 'Your ${leaveData['leaveType']} request has been $newStatus.',
          'type': newStatus == 'approved' ? 'leave_approved' : 'leave_rejected',
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Leave $newStatus'),
            backgroundColor:
                newStatus == 'approved' ? AppTheme.success : AppTheme.danger,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
