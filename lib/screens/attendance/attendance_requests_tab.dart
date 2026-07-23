import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/screens/attendance/attendance_request_detail_screen.dart';
import 'package:attendance_app/screens/attendance/attendance_correction_form_screen.dart';

/// Requests tab â€” Shows attendance correction / WFH requests with status badges.
/// For employees: shows their own requests.
/// For managers/admins: shows all pending requests they need to act on +
/// their own requests.
class AttendanceRequestsTab extends StatefulWidget {
  const AttendanceRequestsTab({super.key});

  @override
  State<AttendanceRequestsTab> createState() => _AttendanceRequestsTabState();
}

class _AttendanceRequestsTabState extends State<AttendanceRequestsTab> {
  final _user = FirebaseAuth.instance.currentUser;
  String get _role => AppSession().role?.toLowerCase() ?? 'employee';

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildRequestsList(),
        // FAB
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton(
            onPressed: _showNewRequestSheet,
            backgroundColor: AppTheme.primary,
            elevation: 4,
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestsList() {
    // For employee: query their own leave_requests sub-collection
    // For manager/admin: query all leave_requests via collection group
    final Stream<QuerySnapshot> stream;
    if (_role == 'employee') {
      stream = FirestoreService.userLeaveRequestsCol(_user?.email ?? '')
          .snapshots();
    } else {
      stream = FirestoreService.allLeaveRequestsQuery
          .snapshots();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Leave Requests Stream Error: ${snapshot.error}');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text('Error loading requests:\n${snapshot.error}', 
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.danger)),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary));
        }

        // Also check for attendance correction requests
        return StreamBuilder<QuerySnapshot>(
          stream: _getAttendanceCorrectionStream(),
          builder: (context, correctionSnap) {
            final leaveReqs = snapshot.data!.docs;
            final correctionReqs = correctionSnap.data?.docs ?? [];

            // Merge and sort by date
            final allRequests = <_RequestItem>[];

            for (final doc in leaveReqs) {
              final data = doc.data() as Map<String, dynamic>;
              final senderRole = (data['senderRole'] ?? 'employee').toString().toLowerCase();
              final isOwn = data['userId'] == _user?.uid || data['userEmail'] == _user?.email;
              
              if (_role == 'manager' && senderRole != 'employee' && !isOwn) {
                continue;
              }

              final reqType = _getRequestType(data);

              allRequests.add(_RequestItem(
                id: doc.id,
                reference: doc.reference,
                type: reqType,
                status: (data['status'] ?? 'pending').toString().toLowerCase(),
                submittedAt: data['submittedAt'] as Timestamp? ?? data['requestDate'] as Timestamp?,
                requestedDate: data['requestedDate'] as Timestamp? ??
                    data['startDate'] as Timestamp? ?? data['fromDate'] as Timestamp?,
                managerName: data['managerName'] as String? ?? data['approvedBy'] as String?,
                data: data,
              ));
            }

            for (final doc in correctionReqs) {
              final data = doc.data() as Map<String, dynamic>;
              final senderRole = (data['senderRole'] ?? 'employee').toString().toLowerCase();
              final isOwn = data['userId'] == _user?.uid || data['userEmail'] == _user?.email;
              
              if (_role == 'manager' && senderRole != 'employee' && !isOwn) {
                continue;
              }

              allRequests.add(_RequestItem(
                id: doc.id,
                reference: doc.reference,
                type: 'Attendance Correction',
                status: (data['status'] ?? 'pending').toString().toLowerCase(),
                submittedAt: data['submittedAt'] as Timestamp? ??
                    data['createdAt'] as Timestamp? ?? data['requestDate'] as Timestamp?,
                requestedDate: data['date'] as Timestamp? ?? data['checkInTime'] as Timestamp?,
                managerName: data['managerName'] as String?,
                data: data,
              ));
            }

            // Sort by submitted date descending
            allRequests.sort((a, b) {
              final aTime = a.submittedAt?.toDate() ?? DateTime(2000);
              final bTime = b.submittedAt?.toDate() ?? DateTime(2000);
              return bTime.compareTo(aTime);
            });

            if (allRequests.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              physics: const BouncingScrollPhysics(),
              itemCount: allRequests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _requestCard(allRequests[index]),
            );
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getAttendanceCorrectionStream() {
    // Try to get overtime requests which may contain correction requests
    try {
      if (_role == 'employee') {
        return FirestoreService.userOvertimeRequestsCol(_user?.email ?? '')
            .snapshots();
      } else {
        return FirestoreService.allOvertimeRequestsQuery.snapshots();
      }
    } catch (_) {
      return const Stream.empty();
    }
  }

  String _getRequestType(Map<String, dynamic> data) {
    final type = (data['type'] ?? data['leaveType'] ?? '').toString();
    if (type.toLowerCase().contains('wfh') ||
        type.toLowerCase().contains('work_from_home')) {
      return 'Work From Home';
    }
    if (type.toLowerCase().contains('correction')) {
      return 'Attendance Correction';
    }
    return type.isNotEmpty ? type : 'Leave Request';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inbox_rounded,
                size: 48, color: AppTheme.primary.withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          const Text('No Requests Yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Text('Tap + to create a new request',
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // â”€â”€â”€ Request Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _requestCard(_RequestItem req) {
    final statusInfo = _getStatusInfo(req.status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.divider.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(req.type,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: statusInfo.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusInfo.label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusInfo.color)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('ID: ${req.id.length > 16 ? req.id.substring(0, 16) : req.id}',
              style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),

          // Details
          _detailRow(
              'Submitted',
              req.submittedAt != null
                  ? DateFormat('dd MMM yyyy').format(req.submittedAt!.toDate())
                  : 'N/A'),
          const SizedBox(height: 4),
          _detailRow(
              'Requested Date',
              req.requestedDate != null
                  ? DateFormat('dd MMM yyyy')
                      .format(req.requestedDate!.toDate())
                  : 'N/A'),
          if (req.managerName != null && req.managerName!.isNotEmpty) ...[
            const SizedBox(height: 4),
            _detailRow('Manager', req.managerName!),
          ],
          const SizedBox(height: 12),

          // View details link
          GestureDetector(
            onTap: () => _viewRequestDetail(req),
            child: Row(
              children: [
                Text('View Details',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary)),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    size: 16, color: AppTheme.primary),
              ],
            ),
          ),

          // Manager/Admin: show approve/reject buttons for pending requests
          if (_role != 'employee' && req.status == 'pending') ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleRequestAction(req, 'rejected'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                      side: BorderSide(color: AppTheme.danger.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Reject',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleRequestAction(req, 'approved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Approve',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      children: [
        Text('$label:  ',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMuted)),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
        ),
      ],
    );
  }

  _StatusDisplayInfo _getStatusInfo(String status) {
    switch (status) {
      case 'approved':
        return _StatusDisplayInfo('Approved', AppTheme.success);
      case 'rejected':
        return _StatusDisplayInfo('Rejected', AppTheme.danger);
      default:
        return _StatusDisplayInfo('Pending', AppTheme.warning);
    }
  }

  void _viewRequestDetail(_RequestItem req) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceRequestDetailScreen(
          reference: req.reference,
          title: req.type,
        ),
      ),
    );
  }

  Future<void> _handleRequestAction(_RequestItem req, String newStatus) async {
    try {
      // Update the request document
      // The actual path depends on how the request was stored
      final email = req.data['userId'] as String? ??
          req.data['employeeEmail'] as String? ??
          _user?.email ??
          '';
      await FirestoreService.userLeaveRequestsCol(email)
          .doc(req.id)
          .update({
        'status': newStatus,
        'approvedBy': AppSession().userName ?? AppSession().email,
        'approvedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Request ${newStatus == 'approved' ? 'approved' : 'rejected'}'),
          backgroundColor:
              newStatus == 'approved' ? AppTheme.success : AppTheme.danger,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.danger,
        ));
      }
    }
  }

  void _showNewRequestSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('New Request',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 20),
            _requestTypeOption(
              icon: Icons.edit_calendar_rounded,
              title: 'Attendance Correction',
              subtitle: 'Correct missed or wrong attendance',
              color: AppTheme.warning,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AttendanceCorrectionFormScreen()),
                );
              },
            ),
            const SizedBox(height: 10),
            _requestTypeOption(
              icon: Icons.home_work_rounded,
              title: 'Work From Home',
              subtitle: 'Request to work from home',
              color: const Color(0xFF8B5CF6),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _requestTypeOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.divider),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppTheme.textHint, size: 20),
          ],
        ),
      ),
    );
  }
}

class _RequestItem {
  final String id;
  final DocumentReference reference;
  final String type;
  final String status;
  final Timestamp? submittedAt;
  final Timestamp? requestedDate;
  final String? managerName;
  final Map<String, dynamic> data;

  const _RequestItem({
    required this.id,
    required this.reference,
    required this.type,
    required this.status,
    this.submittedAt,
    this.requestedDate,
    this.managerName,
    required this.data,
  });
}

class _StatusDisplayInfo {
  final String label;
  final Color color;
  const _StatusDisplayInfo(this.label, this.color);
}
