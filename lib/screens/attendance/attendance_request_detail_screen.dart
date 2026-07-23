import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendance_app/screens/attendance/attendance_correction_form_screen.dart';

class AttendanceRequestDetailScreen extends StatelessWidget {
  final DocumentReference reference;
  final String title;

  const AttendanceRequestDetailScreen({
    super.key,
    required this.reference,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, color: AppTheme.textPrimary, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Request Detail',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined, color: AppTheme.primary),
            onPressed: () {},
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: reference.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }

          final doc = snapshot.data!;
          if (!doc.exists) {
            return const Center(child: Text('Request not found or deleted'));
          }

          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? 'pending').toString().toLowerCase();
          
          final submittedAt = data['submittedAt'] as Timestamp? ??
              data['requestDate'] as Timestamp? ??
              data['createdAt'] as Timestamp?;
          final requestedDate = data['requestedDate'] as Timestamp? ??
              data['startDate'] as Timestamp? ??
              data['fromDate'] as Timestamp? ??
              data['date'] as Timestamp? ??
              data['checkInTime'] as Timestamp?;
          
          final manager = data['managerName'] as String? ?? data['approvedBy'] as String? ?? 'Pending';
          final lastUpdated = data['approvedAt'] as Timestamp? ?? submittedAt;
          final reason = data['reason'] as String? ?? 'No reason provided';
          final isOwn = data['userId'] == FirebaseAuth.instance.currentUser?.uid ||
                        data['userEmail'] == FirebaseAuth.instance.currentUser?.email;
          final isPending = status == 'pending';

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderCard(data, status, doc.id),
                const SizedBox(height: 16),
                _buildInfoCard(submittedAt, requestedDate, manager, lastUpdated),
                const SizedBox(height: 16),
                _buildReasonCard(reason),
                const SizedBox(height: 16),
                _buildApprovalFlowCard(status, manager),
                const SizedBox(height: 24),
                if (isPending && isOwn) _buildActionButtons(context, data),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(Map<String, dynamic> data, String status, String id) {
    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'approved':
        statusColor = AppTheme.success;
        statusLabel = 'Approved';
        break;
      case 'rejected':
        statusColor = AppTheme.danger;
        statusLabel = 'Rejected';
        break;
      default:
        statusColor = AppTheme.warning;
        statusLabel = 'Pending';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('ID: ${id.length > 16 ? id.substring(0, 16).toUpperCase() : id.toUpperCase()}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Timestamp? submittedAt, Timestamp? requestedDate, String manager, Timestamp? lastUpdated) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          _infoRow('Submission Date', submittedAt != null ? DateFormat('dd MMM yyyy').format(submittedAt.toDate()) : 'N/A'),
          const SizedBox(height: 16),
          _infoRow('Requested Date', requestedDate != null ? DateFormat('dd MMM yyyy').format(requestedDate.toDate()) : 'N/A'),
          const SizedBox(height: 16),
          _infoRow('Reporting Manager', manager),
          const SizedBox(height: 16),
          _infoRow('Last Updated', lastUpdated != null ? DateFormat('dd MMM yyyy').format(lastUpdated.toDate()) : 'N/A'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMuted)),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
      ],
    );
  }

  Widget _buildReasonCard(String reason) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('REASON',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Text(reason,
              style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildApprovalFlowCard(String status, String manager) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('APPROVAL FLOW',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.5)),
          const SizedBox(height: 20),
          _buildTimelineNode(
            title: 'Manager Review',
            subtitle: manager,
            statusLabel: status == 'pending' ? 'Pending Manager Review' : (status == 'approved' ? 'Approved' : 'Rejected'),
            isLast: false,
            nodeColor: status == 'pending' ? AppTheme.warning : (status == 'approved' ? AppTheme.success : AppTheme.danger),
          ),
          _buildTimelineNode(
            title: 'HR Approval',
            subtitle: 'HR Support Team',
            statusLabel: status == 'pending' ? 'Waiting for manager' : (status == 'approved' ? 'Auto-approved HR' : 'Waiting for manager'),
            isLast: true,
            nodeColor: status == 'approved' ? AppTheme.textHint : AppTheme.textHint,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineNode({
    required String title,
    required String subtitle,
    required String statusLabel,
    required bool isLast,
    required Color nodeColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: nodeColor,
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: AppTheme.divider,
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textHint)),
                const SizedBox(height: 2),
                Text(statusLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textMuted)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, Map<String, dynamic> data) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AttendanceCorrectionFormScreen(
                    existingRef: reference,
                    existingData: data,
                    requestType: title,
                  ),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 8),
                Text('Edit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Withdraw Request'),
                  content: const Text('Are you sure you want to withdraw this request?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Withdraw', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                try {
                  await reference.delete();
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request withdrawn successfully.')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error withdrawing: $e')));
                  }
                }
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.danger,
              backgroundColor: AppTheme.danger.withOpacity(0.05),
              side: BorderSide(color: AppTheme.danger.withOpacity(0.2)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.close_rounded, size: 18),
                SizedBox(width: 8),
                Text('Withdraw', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
