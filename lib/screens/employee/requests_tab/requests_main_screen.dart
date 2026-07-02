import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:attendance_app/utils/firestore_service.dart';
import 'request_detail_screen.dart';
import 'request_correction_form.dart';

class RequestsMainScreen extends StatefulWidget {
  const RequestsMainScreen({super.key});
  @override
  State<RequestsMainScreen> createState() => _RequestsMainScreenState();
}

class _RequestsMainScreenState extends State<RequestsMainScreen> {
  final _user = FirebaseAuth.instance.currentUser;

  Stream<List<Map<String, dynamic>>> _buildStream() {
    final email = _user?.email ?? '';
    final correctionsStream = FirebaseFirestore.instance
        .collection('approved_companies')
        .doc(FirestoreService.companyId)
        .collection('attendance_corrections')
        .where('userId', isEqualTo: email)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return correctionsStream.asyncMap((corrSnap) async {
      final leaveSnap = await FirestoreService.userLeaveRequestsCol(email)
          .orderBy('createdAt', descending: true)
          .get();

      final List<Map<String, dynamic>> items = [];

      for (final doc in corrSnap.docs) {
        final d = doc.data();
        items.add({
          'id': doc.id,
          'type': 'Attendance Correction',
          'typeCode': 'ATT',
          'status': d['status'] ?? 'pending',
          'submittedAt': d['createdAt'],
          'requestedDate': d['attendanceDate'],
          'reason': d['reason'] ?? '',
          'correctedCheckIn': d['correctedCheckIn'],
          'correctedCheckOut': d['correctedCheckOut'],
          'updatedAt': d['updatedAt'] ?? d['createdAt'],
          '_sortTs': d['createdAt'],
        });
      }

      for (final doc in leaveSnap.docs) {
        final d = doc.data();
        final lType = d['leaveType'] as String? ?? '';
        items.add({
          'id': doc.id,
          'type': lType == 'wfh' ? 'Work From Home' : (lType.isNotEmpty ? lType : 'Leave'),
          'typeCode': lType == 'wfh' ? 'WFH' : 'LVE',
          'status': d['status'] ?? 'pending',
          'submittedAt': d['createdAt'],
          'requestedDate': d['startDate'],
          'reason': d['reason'] ?? '',
          'updatedAt': d['updatedAt'] ?? d['createdAt'],
          '_sortTs': d['createdAt'],
        });
      }

      items.sort((a, b) {
        final ta = a['_sortTs'] as Timestamp?;
        final tb = b['_sortTs'] as Timestamp?;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });

      return items;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _buildStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF5C5CFF)));
          }
          final items = snap.data ?? [];
          if (items.isEmpty) return _buildEmpty();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _RequestCard(
              item: items[i],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RequestDetailScreen(item: items[i])),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRequestTypeSheet(),
        backgroundColor: const Color(0xFF5C5CFF),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Request', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(color: Color(0xFFEEF2FF), shape: BoxShape.circle),
            child: const Icon(Icons.inbox_outlined, color: Color(0xFF5C5CFF), size: 36),
          ),
          const SizedBox(height: 20),
          const Text('No Requests Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
          const SizedBox(height: 8),
          const Text('Your attendance correction and\nWFH requests will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5)),
        ],
      ),
    );
  }

  void _showRequestTypeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Request',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
            const SizedBox(height: 4),
            const Text('Choose the type of request',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 20),
            _SheetTile(
              icon: Icons.access_time_rounded,
              color: const Color(0xFF5C5CFF),
              title: 'Attendance Correction',
              subtitle: 'Fix incorrect check-in or check-out time',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const RequestCorrectionForm()));
              },
            ),
            const SizedBox(height: 12),
            _SheetTile(
              icon: Icons.home_work_outlined,
              color: const Color(0xFF10B981),
              title: 'Work From Home',
              subtitle: 'Request approval to work remotely',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('WFH request coming soon'),
                    backgroundColor: Color(0xFF5C5CFF)));
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// --- Request Card -------------------------------------------------------------

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _RequestCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = item['status'] as String? ?? 'pending';
    final type = item['type'] as String? ?? '';
    final typeCode = item['typeCode'] as String? ?? 'ATT';
    final submittedTs = item['submittedAt'] as Timestamp?;
    final requestedTs = item['requestedDate'] as Timestamp?;
    final submittedStr = submittedTs != null ? DateFormat('dd MMM yyyy').format(submittedTs.toDate()) : '--';
    final requestedStr = requestedTs != null ? DateFormat('dd MMM yyyy').format(requestedTs.toDate()) : '--';
    final shortId = '$typeCode-${submittedTs?.toDate().year ?? DateTime.now().year}-${item['id'].toString().substring(0, 3).toUpperCase()}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(type, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827)))),
                _StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 4),
            Text('ID: $shortId', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            _InfoRow(label: 'Submitted:', value: submittedStr),
            const SizedBox(height: 4),
            _InfoRow(label: 'Requested Date:', value: requestedStr),
            const SizedBox(height: 4),
            const _InfoRow(label: 'Manager:', value: 'Rahul Mehta', bold: true),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onTap,
              child: const Row(
                children: [
                  Text('View Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF5C5CFF))),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 16, color: Color(0xFF5C5CFF)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _InfoRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(fontSize: 12, color: const Color(0xFF111827), fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
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

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SheetTile({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF), size: 18),
          ],
        ),
      ),
    );
  }
}
