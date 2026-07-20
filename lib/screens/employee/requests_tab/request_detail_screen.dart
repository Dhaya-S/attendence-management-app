import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'request_correction_form.dart';

/// Screen 2 â€” Request Detail (matches center panel in mockup)
class RequestDetailScreen extends StatelessWidget {
  final Map<String, dynamic> item;
  const RequestDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final status = item['status'] as String? ?? 'pending';
    final type = item['type'] as String? ?? '';
    final typeCode = item['typeCode'] as String? ?? 'ATT';
    final submittedTs = item['submittedAt'] as Timestamp?;
    final requestedTs = item['requestedDate'] as Timestamp?;
    final updatedTs = item['updatedAt'] as Timestamp?;
    final reason = item['reason'] as String? ?? '';

    final submittedStr = submittedTs != null ? DateFormat('dd MMM yyyy').format(submittedTs.toDate()) : '--';
    final requestedStr = requestedTs != null ? DateFormat('dd MMM yyyy').format(requestedTs.toDate()) : '--';
    final updatedStr = updatedTs != null ? DateFormat('dd MMM yyyy').format(updatedTs.toDate()) : '--';
    final shortId = '$typeCode-${submittedTs?.toDate().year ?? DateTime.now().year}-${item['id'].toString().substring(0, 3).toUpperCase()}';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF3F4F6), height: 1),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF4B5563)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Request Detail',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.description_outlined, color: Color(0xFF5C5CFF), size: 20),
          )
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(type,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                      const SizedBox(height: 4),
                      Text('ID: $shortId',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
                    ],
                  ),
                  _StatusBadge(status: status),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Detail rows card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: Column(
                children: [
                  _DetailRow(label: 'Submission Date', value: submittedStr),
                  const Divider(height: 24, color: Color(0xFFF3F4F6)),
                  _DetailRow(label: 'Requested Date', value: requestedStr),
                  const Divider(height: 24, color: Color(0xFFF3F4F6)),
                  const _DetailRow(label: 'Reporting Manager', value: 'Rahul Mehta', bold: true),
                  const Divider(height: 24, color: Color(0xFFF3F4F6)),
                  _DetailRow(label: 'Last Updated', value: updatedStr),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Reason card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('REASON',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 0.8)),
                  const SizedBox(height: 12),
                  Text(
                    reason.isNotEmpty ? reason : 'No reason provided.',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF374151), height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Approval flow card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('APPROVAL FLOW',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 0.8)),
                  const SizedBox(height: 16),
                  _ApprovalStep(
                    label: 'Manager Review',
                    sublabel: 'Rahul Mehta',
                    statusNote: _managerNote(status),
                    dotColor: _managerDotColor(status),
                    isActive: true,
                  ),
                  const SizedBox(height: 16),
                  _ApprovalStep(
                    label: 'HR Approval',
                    sublabel: 'HR Support Team',
                    statusNote: _hrNote(status),
                    dotColor: _hrDotColor(status),
                    isActive: status == 'approved',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons (only for pending)
            if (status == 'pending') ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => RequestCorrectionForm(editItem: item)),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF5C5CFF),
                        side: const BorderSide(color: Color(0xFF5C5CFF)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmWithdraw(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Withdraw', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  String _managerNote(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return 'Approved';
      case 'rejected': return 'Rejected';
      default: return 'Pending Manager Review';
    }
  }

  Color _managerDotColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return const Color(0xFF10B981);
      case 'rejected': return const Color(0xFFEF4444);
      default: return const Color(0xFFF97316);
    }
  }

  String _hrNote(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return 'Auto-approved HR';
      default: return 'Waiting for manager';
    }
  }

  Color _hrDotColor(String status) {
    return status == 'approved' ? const Color(0xFF10B981) : const Color(0xFFD1D5DB);
  }

  void _confirmWithdraw(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Withdraw Request', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to withdraw this request?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseFirestore.instance
                    .collection('organizations')
                    .doc(_getCompanyId())
                    .collection('attendance_corrections')
                    .doc(item['id'])
                    .delete();
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Withdraw', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  String _getCompanyId() {
    return 'HIPRO7o5dE67YH0OIra7'; // Fallback company ID, actually we can just use AppSession
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _DetailRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                color: const Color(0xFF111827),
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600)),
      ],
    );
  }
}

class _ApprovalStep extends StatelessWidget {
  final String label;
  final String sublabel;
  final String statusNote;
  final Color dotColor;
  final bool isActive;

  const _ApprovalStep({
    required this.label,
    required this.sublabel,
    required this.statusNote,
    required this.dotColor,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 3),
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
            const SizedBox(height: 2),
            Text(sublabel, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            const SizedBox(height: 2),
            Text(statusNote, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
          ],
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg; Color fg; String label;
    switch (status.toLowerCase()) {
      case 'approved': bg = const Color(0xFFECFDF5); fg = const Color(0xFF10B981); label = 'Approved'; break;
      case 'rejected': bg = const Color(0xFFFEF2F2); fg = const Color(0xFFEF4444); label = 'Rejected'; break;
      default: bg = const Color(0xFFFFF7ED); fg = const Color(0xFFF97316); label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}
