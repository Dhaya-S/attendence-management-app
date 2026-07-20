import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/date_range_selection_modal.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';

class AdminLeaveTab extends StatefulWidget {
  const AdminLeaveTab({super.key});

  @override
  State<AdminLeaveTab> createState() => _AdminLeaveTabState();
}

class _AdminLeaveTabState extends State<AdminLeaveTab> {
  final user = FirebaseAuth.instance.currentUser;
  late Stream<QuerySnapshot> _leaveRequestsStream;

  String selectedType = 'Sick Leave';
  String leaveDuration = 'Full Day';
  DateTime fromDate = DateTime.now().add(const Duration(days: 1));
  DateTime toDate = DateTime.now().add(const Duration(days: 1));
  final TextEditingController reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _leaveRequestsStream = FirestoreService.userLeaveRequestsCol(user?.email ?? '')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: Navigator.canPop(context) ? IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ) : null,
        title: Text('Leave Management', style: AppTheme.h1.copyWith(fontSize: 18)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _leaveRequestsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
             return Center(child: Text('Error: ${snapshot.error}'));
          }

          // Sort in-memory
          final docs = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final aDate = (a.data() as Map<String, dynamic>)['requestDate'] as Timestamp?;
              final bDate = (b.data() as Map<String, dynamic>)['requestDate'] as Timestamp?;
              if (aDate == null) return 1;
              if (bDate == null) return -1;
              return bDate.compareTo(aDate);
            });

          final requests = docs;
          final used = _calculateUsedLeaves(requests);

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: FadeInUp(
              duration: const Duration(milliseconds: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBalanceHeader(used),
                  const SizedBox(height: 24),
                  _buildApplyLeaveSection(),
                  const SizedBox(height: 24),
                  _buildLeaveDurationSection(),
                  const SizedBox(height: 24),
                  _buildReasonSection(),
                  const SizedBox(height: 32),
                  _buildSubmitButton(),
                  const SizedBox(height: 40),
                  _buildRecentTable(requests),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  int _calculateUsedLeaves(List<QueryDocumentSnapshot> requests) {
    int total = 0;
    final now = DateTime.now();
    for (var doc in requests) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['leaveType'] == 'Paid Leave' && data['status'] == 'approved') {
        final start = (data['fromDate'] as Timestamp?)?.toDate();
        if (start != null && start.year == now.year) {
          total += (data['durationInDays'] as num?)?.toInt() ?? 0;
        }
      }
    }
    return total;
  }

  Widget _buildBalanceHeader(int used) {
    final int total = AppSession().paidLeavesPerYear;
    final int remaining = total - used;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               _balanceCol('PAID LEAVE', total.toString()),
               _balanceCol('USED', used.toString()),
               _balanceCol('REMAINING', remaining.toString()),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0,
            backgroundColor: AppTheme.primary.withOpacity(0.1),
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(4),
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  Widget _balanceCol(String label, String val) {
    return Column(
      children: [
        Text(label, style: AppTheme.label.copyWith(fontSize: 10)),
        const SizedBox(height: 4),
        Text(val, style: AppTheme.h1.copyWith(fontSize: 20)),
      ],
    );
  }

  Widget _buildApplyLeaveSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('LEAVE TYPE', style: AppTheme.label.copyWith(fontSize: 10)),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: [
            _typeCard('Sick Leave', Icons.medical_services_outlined, selectedType == 'Sick Leave'),
            _typeCard('Casual Leave', Icons.event_available_outlined, selectedType == 'Casual Leave'),
            _typeCard('Work From Home', Icons.home_work_outlined, selectedType == 'Work From Home'),
            _typeCard('Paid Leave', Icons.payments_outlined, selectedType == 'Paid Leave'),
          ],
        ),
      ],
    );
  }

  Widget _typeCard(String label, IconData icon, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => selectedType = label),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.divider),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : AppTheme.textMuted, size: 18),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppTheme.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveDurationSection() {
    return GestureDetector(
      onTap: () async {
        final result = await showModalBottomSheet<Map<String, DateTime>>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => DateRangeSelectionModal(initialStart: fromDate, initialEnd: toDate),
        );
        if (result != null) {
          setState(() {
            fromDate = result['start']!;
            toDate = result['end']!;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('DURATION', style: AppTheme.label.copyWith(fontSize: 10)),
                _durationChip('Full Day'),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _dateTile('START DATE', fromDate, true)),
                const SizedBox(width: 12),
                Expanded(child: _dateTile('END DATE', toDate, false)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _durationChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
      child: Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold)),
    );
  }

  Widget _dateTile(String label, DateTime date, bool isStart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.label.copyWith(fontSize: 9)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
          child: Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(DateFormat('MMM dd, yyyy').format(date), style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReasonSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('REASON', style: AppTheme.label.copyWith(fontSize: 10)),
          const SizedBox(height: 12),
          TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Enter reason for leave...',
              border: InputBorder.none,
              hintStyle: TextStyle(fontSize: 13, color: AppTheme.textHint),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildRecentTable(List<QueryDocumentSnapshot> requests) {
    if (requests.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RECENT REQUESTS', style: AppTheme.label.copyWith(fontSize: 10)),
        const SizedBox(height: 16),
        ...requests.take(3).map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final String statusText = (data['status'] ?? 'PENDING').toString().toUpperCase();
          final Color statusColor = statusText == 'APPROVED' ? AppTheme.success : statusText == 'PENDING' ? AppTheme.warning : AppTheme.danger;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration(),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(data['leaveType'] ?? 'Leave Request', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      data['fromDate'] != null && data['fromDate'] is Timestamp
                        ? DateFormat('MMM dd').format((data['fromDate'] as Timestamp).toDate())
                        : 'N/A', 
                      style: AppTheme.bodySmall
                    ),
                    const Icon(Icons.arrow_forward_rounded, size: 12, color: AppTheme.textHint),
                    Text(
                      data['toDate'] != null && data['toDate'] is Timestamp
                        ? DateFormat('MMM dd').format((data['toDate'] as Timestamp).toDate())
                        : 'N/A', 
                      style: AppTheme.bodySmall
                    ),
                    const Spacer(),
                    Text('${data['durationInDays'] ?? 0} Days', style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitLeaveRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isSubmitting 
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text('SUBMIT REQUEST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Future<void> _submitLeaveRequest() async {
    if (reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide a reason')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (selectedType == 'Paid Leave') {
        final now = DateTime.now();
        
        // Simplified query to avoid index requirement
        final leaves = await FirestoreService.userLeaveRequestsCol(user?.email ?? '')
            .where('leaveType', isEqualTo: 'Paid Leave')
            .get();

        int currentYearUsed = 0;
        for (var doc in leaves.docs) {
          final d = doc.data();
          if (d['status'] != 'rejected') {
            final fromDateValue = d['fromDate'];
            if (fromDateValue != null && fromDateValue is Timestamp) {
              final date = fromDateValue.toDate();
              if (date.year == now.year) {
                currentYearUsed += (d['durationInDays'] as num?)?.toInt() ?? 0;
              }
            }
          }
        }
        
        final requestedDays = toDate.difference(fromDate).inDays + 1;
        final limit = AppSession().paidLeavesPerYear;

        if (currentYearUsed + requestedDays > limit) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('You only have $limit Paid Leaves per year. This request exceeds your remaining balance ($currentYearUsed used).'),
              backgroundColor: AppTheme.danger,
            ));
          }
          setState(() => _isSubmitting = false);
          return;
        }
      }

      final userQuery = await FirestoreService.usersCol
          .where('email', isEqualTo: user?.email ?? '')
          .limit(1)
          .get();
      final userData = userQuery.docs.isNotEmpty ? userQuery.docs.first.data() : {};
      final userName = userData['name'] ?? 'Employee';
      final department = userData['department'] ?? 'General';

      final requestedDays = toDate.difference(fromDate).inDays + 1;
      await FirestoreService.userLeaveRequestsCol(user?.email ?? '').add({
        'companyId': FirestoreService.companyId,
        'userId': user?.uid,
        'userName': userName,
        'department': department,
        'leaveType': selectedType,
        'fromDate': Timestamp.fromDate(fromDate),
        'toDate': Timestamp.fromDate(toDate),
        'durationInDays': requestedDays,
        'reason': reasonController.text.trim(),
        'status': 'pending',
        'requestDate': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showSuccessDialog();
        reasonController.clear();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => ElasticIn(
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 64),
              const SizedBox(height: 24),
              Text('Request Submitted!', style: AppTheme.h2),
              const SizedBox(height: 12),
              const Text('Your leave request has been sent for approval.', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext); // Pops the dialog
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context); // Pops the pushed screen
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Great!', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
