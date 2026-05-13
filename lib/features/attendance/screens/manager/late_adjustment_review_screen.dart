import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/widgets/notification_action.dart';

class LateAdjustmentReviewScreen extends StatefulWidget {
  const LateAdjustmentReviewScreen({super.key});

  @override
  State<LateAdjustmentReviewScreen> createState() =>
      _LateAdjustmentReviewScreenState();
}

class _LateAdjustmentReviewScreenState
    extends State<LateAdjustmentReviewScreen> {
  String _filter = 'Pending';
  final _filters = ['Pending', 'Approved', 'Denied'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text('Late Adjustments',
            style: AppTheme.h1.copyWith(fontSize: 18)),
        actions: [
          NotificationAction(isManager: true),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: _filters.map((f) {
                final isActive = _filter == f;
                Color activeColor = AppTheme.primary;
                if (f == 'Approved') activeColor = AppTheme.success;
                if (f == 'Denied') activeColor = AppTheme.danger;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isActive
                            ? activeColor.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive ? activeColor : AppTheme.divider,
                          width: isActive ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        f,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isActive ? activeColor : AppTheme.textHint,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Request List
          Expanded(child: _buildRequestList()),
        ],
      ),
    );
  }

  Widget _buildRequestList() {
    final statusValue = _filter == 'Pending'
        ? 'pending'
        : _filter == 'Approved'
            ? 'approved'
            : 'denied';

    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.allAttendanceRecordsCol.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filter and sort in-memory to avoid all collectionGroup index requirements
        final allRequests = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['remarkStatus'] == statusValue;
        }).toList()
        ..sort((a, b) {
          final aDate = (a.data() as Map<String, dynamic>)['date'] as Timestamp?;
          final bDate = (b.data() as Map<String, dynamic>)['date'] as Timestamp?;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });
        if (allRequests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_edu_rounded,
                    size: 72, color: AppTheme.textHint.withOpacity(0.4)),
                const SizedBox(height: 16),
                Text(
                  'No ${_filter.toLowerCase()} requests',
                  style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Adjustment requests from employees will appear here.',
                  style:
                      TextStyle(fontSize: 13, color: AppTheme.textHint),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          itemCount: allRequests.length,
          itemBuilder: (context, index) {
            final doc = allRequests[index];
            final data = doc.data() as Map<String, dynamic>;
            final userName = data['userName'] ?? 'Employee';
            final remark = data['remark'] ?? 'No reason given';
            final recordDate = data['recordDate'] ?? '';
            final requestTime = data['requestTime'] as Timestamp?;
            final checkIn = data['checkIn'] as Timestamp?;
            final adjustedCheckIn = data['adjustedCheckIn'] as Timestamp?;
            final reviewNote = data['reviewNote'] ?? '';
            final remarkStatus = data['remarkStatus'] ?? 'pending';

            String timeAgo = '';
            if (requestTime != null) {
              final diff =
                  DateTime.now().difference(requestTime.toDate());
              if (diff.inMinutes < 60) {
                timeAgo = '${diff.inMinutes}m ago';
              } else if (diff.inHours < 24) {
                timeAgo = '${diff.inHours}h ago';
              } else {
                timeAgo =
                    DateFormat('MMM d').format(requestTime.toDate());
              }
            }

            return _requestCard(
              doc: doc,
              userName: userName,
              remark: remark,
              recordDate: recordDate,
              timeAgo: timeAgo,
              checkIn: checkIn,
              adjustedCheckIn: adjustedCheckIn,
              reviewNote: reviewNote,
              remarkStatus: remarkStatus,
            );
          },
        );
      },
    );
  }

  Widget _requestCard({
    required QueryDocumentSnapshot doc,
    required String userName,
    required String remark,
    required String recordDate,
    required String timeAgo,
    required Timestamp? checkIn,
    required Timestamp? adjustedCheckIn,
    required String reviewNote,
    required String remarkStatus,
  }) {
    Color statusColor = AppTheme.warning;
    Color statusBg = AppTheme.warningLight;
    String statusLabel = 'PENDING';
    if (remarkStatus == 'approved') {
      statusColor = AppTheme.success;
      statusBg = AppTheme.successLight;
      statusLabel = 'APPROVED';
    } else if (remarkStatus == 'denied') {
      statusColor = AppTheme.danger;
      statusBg = AppTheme.dangerLight;
      statusLabel = 'DENIED';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primarySurface,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'E',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        color: AppTheme.primary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userName,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    Text('Date: $recordDate  •  $timeAgo',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textHint)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(10)),
                child: Text(statusLabel,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor)),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Reason
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.chat_bubble_outline_rounded,
                  size: 16, color: AppTheme.textHint),
              const SizedBox(width: 8),
              Expanded(
                child: Text(remark,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.4)),
              ),
            ],
          ),

          if (checkIn != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.login_rounded,
                    size: 16, color: AppTheme.textHint),
                const SizedBox(width: 8),
                Text(
                  'Original Check-In: ${DateFormat('hh:mm a').format(checkIn.toDate())}',
                  style:
                      TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],

          if (adjustedCheckIn != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    size: 16, color: AppTheme.success),
                const SizedBox(width: 8),
                Text(
                  'Adjusted to: ${DateFormat('hh:mm a').format(adjustedCheckIn.toDate())}',
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.success,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],

          if (reviewNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_rounded,
                      size: 14, color: AppTheme.textHint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Manager: "$reviewNote"',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ),
                ],
              ),
            ),
          ],

          // Action Buttons (only for pending)
          if (remarkStatus == 'pending') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showDenyDialog(doc),
                    icon: const Icon(Icons.close_rounded,
                        size: 16, color: AppTheme.danger),
                    label: const Text('Deny',
                        style: TextStyle(
                            color: AppTheme.danger, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.danger),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showApproveDialog(doc, checkIn),
                    icon: const Icon(Icons.check_rounded,
                        size: 16, color: Colors.white),
                    label: const Text('Approve',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showApproveDialog(
      QueryDocumentSnapshot doc, Timestamp? originalCheckIn) {
    final data = doc.data() as Map<String, dynamic>;
    final recordDate = data['recordDate'] ?? '';
    TimeOfDay selectedTime = originalCheckIn != null
        ? TimeOfDay.fromDateTime(originalCheckIn.toDate())
        : const TimeOfDay(hour: 9, minute: 0);
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            border: const Border.fromBorderSide(const BorderSide(color: Color(0xFFF0F1F3), width: 1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Approve Request',
                      style: AppTheme.h2.copyWith(
                          fontSize: 20, fontWeight: FontWeight.w600)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Set the approved check-in time for this employee.',
                style: TextStyle(fontSize: 14, color: AppTheme.textHint),
              ),
              const SizedBox(height: 20),
              // Time Picker Row
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.successLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppTheme.success.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        color: AppTheme.success, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Approved Check-In Time',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.success,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(
                            selectedTime.format(context),
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                          builder: (context, child) => Theme(
                            data: ThemeData.light().copyWith(
                              colorScheme: const ColorScheme.light(
                                  primary: AppTheme.success),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) {
                          setModalState(() => selectedTime = picked);
                        }
                      },
                      child: const Text('Change',
                          style: TextStyle(
                              color: AppTheme.success,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                style: AppTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Add a review note (optional)...',
                  hintStyle:
                      TextStyle(color: AppTheme.textHint.withOpacity(0.6)),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _approveRequest(
                      doc, recordDate, selectedTime, noteController.text.trim());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  minimumSize: const Size(double.infinity, 54),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Confirm Approval',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDenyDialog(QueryDocumentSnapshot doc) {
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
          border: const Border.fromBorderSide(const BorderSide(color: Color(0xFFF0F1F3), width: 1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Deny Request',
                    style: AppTheme.h2.copyWith(
                        fontSize: 20, fontWeight: FontWeight.w600)),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Provide a reason for denying this adjustment request.',
              style: TextStyle(fontSize: 14, color: AppTheme.textHint),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: noteController,
              maxLines: 3,
              style: AppTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Reason for denial (e.g. Insufficient reason)...',
                hintStyle:
                    TextStyle(color: AppTheme.textHint.withOpacity(0.6)),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _denyRequest(doc, noteController.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger,
                minimumSize: const Size(double.infinity, 54),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Confirm Denial',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveRequest(
    QueryDocumentSnapshot doc,
    String? recordDate,
    TimeOfDay approvedTime,
    String note,
  ) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      
      // Fallback for userId if missing in fields
      String? employeeEmail = data['userEmail'] as String?;
      final pathParts = doc.reference.path.split('/');
      if (employeeEmail == null && pathParts.length >= 4 && pathParts[2] == 'users') {
        employeeEmail = pathParts[3];
      }
      final String employeeIdForNotif = (data['userId'] as String?) ?? employeeEmail ?? 'unknown';
      
      // Fallback for recordDate if missing in fields
      if (recordDate == null || recordDate.isEmpty) {
        if (pathParts.length >= 6) {
          recordDate = pathParts[5];
        } else {
          recordDate = doc.id;
        }
      }

      if (employeeEmail == null) {
        throw 'Could not identify employee email from this record.';
      }

      // Fetch the employee's name for consistent notifications
      String userName = data['userName'] as String? ?? 'Employee';
      if (userName == 'Employee') {
        final employeeDoc = await FirestoreService.usersCol
            .where('uid', isEqualTo: employeeIdForNotif).limit(1).get();
        if (employeeDoc.docs.isNotEmpty) {
          userName = employeeDoc.docs.first.data()?['name'] ?? userName;
        }
      }

      // Build the approved DateTime from the recordDate + selected time
      // Try parsing recordDate (format: yyyy-MM-dd)
      DateTime recordDt;
      try {
        final dateParts = recordDate.split('-');
        if (dateParts.length == 3) {
          recordDt = DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
          );
        } else {
          // If split fails, try standard parsing or fallback to document ID
          recordDt = DateTime.tryParse(recordDate) ?? 
                    DateTime.tryParse(doc.id) ?? 
                    DateTime.now();
        }
      } catch (_) {
        // Ultimate fallback to today if anything goes wrong
        recordDt = DateTime.now();
      }

      final approvedDt = DateTime(
        recordDt.year,
        recordDt.month,
        recordDt.day,
        approvedTime.hour,
        approvedTime.minute,
      );

      // Update the attendance record using the direct reference
      await doc.reference.update({
        'remarkStatus': 'approved',
        'isAdjustmentRequest': false, // No longer a pending request
        'adjustedCheckIn': Timestamp.fromDate(approvedDt),
        'checkIn': Timestamp.fromDate(approvedDt), // overwrite check-in
        'reviewNote': note,
        'reviewedAt': FieldValue.serverTimestamp(),
        'userName': userName, // ensure name is saved/updated
      });

      // Notify the employee
      await FirestoreService.userNotificationsCol(employeeEmail!).add({
        'companyId': FirestoreService.companyId,
        'userId': employeeIdForNotif,
        'title': 'Adjustment Approved ✅',
        'body':
            'Hi $userName, your late adjustment for $recordDate has been approved. Check-in set to ${approvedTime.format(context)}.',
        'type': 'adjustment_approved',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Request approved and check-in time updated.',
                style: TextStyle(fontWeight: FontWeight.w700)),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _denyRequest(QueryDocumentSnapshot doc, String note) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      
      // Fallback for userId if missing in fields
      // Identify the employee (email is used as document ID in /users/{email})
      String? employeeEmail = data['userEmail'] as String?;
      final pathParts = doc.reference.path.split('/');
      if (employeeEmail == null && pathParts.length >= 4 && pathParts[2] == 'users') {
        employeeEmail = pathParts[3];
      }
      final String employeeIdForNotif = (data['userId'] as String?) ?? employeeEmail ?? 'unknown';

      // Fallback for recordDate if missing in fields
      String? recordDate = data['recordDate'] as String?;
      if (recordDate == null || recordDate.isEmpty) {
        if (pathParts.length >= 6) {
          recordDate = pathParts[5];
        } else {
          recordDate = doc.id;
        }
      }

      if (employeeEmail == null) throw 'Could not identify employee.';

      // Get user name if missing
      String userName = data['userName'] as String? ?? 'Employee';
      if (userName == 'Employee') {
        final employeeDoc = await FirestoreService.usersCol
            .where('uid', isEqualTo: employeeIdForNotif).limit(1).get();
        if (employeeDoc.docs.isNotEmpty) {
          userName = employeeDoc.docs.first.data()?['name'] ?? userName;
        }
      }

      await doc.reference.update({
        'remarkStatus': 'denied',
        'isAdjustmentRequest': false, // No longer a pending request
        'reviewNote': note,
        'reviewedAt': FieldValue.serverTimestamp(),
        'userName': userName,
      });

      // Notify the employee
      await FirestoreService.userNotificationsCol(employeeEmail!).add({
        'companyId': FirestoreService.companyId,
        'userId': employeeIdForNotif,
        'title': 'Adjustment Request Denied ❌',
        'body': note.isNotEmpty
            ? 'Your adjustment request for $recordDate was denied: "$note"'
            : 'Your adjustment request for $recordDate was denied by the manager.',
        'type': 'adjustment_denied',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Request denied.',
                style: TextStyle(fontWeight: FontWeight.w700)),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }
}
