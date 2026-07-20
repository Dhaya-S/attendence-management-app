import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';

class EmployeeLeaveSummaryScreen extends StatefulWidget {
  const EmployeeLeaveSummaryScreen({super.key});
  @override
  State<EmployeeLeaveSummaryScreen> createState() =>
      _EmployeeLeaveSummaryScreenState();
}

class _EmployeeLeaveSummaryScreenState
    extends State<EmployeeLeaveSummaryScreen> {
  final _userEmail = FirebaseAuth.instance.currentUser?.email ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
        title: const Text(
          'Leave Summary',
          style: TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 18,
              fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFF3F4F6), height: 1.0),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
          stream: FirestoreService.userLeaveRequestsCol(_userEmail).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());

            final leaveRequests = snapshot.data!.docs;
            final now = DateTime.now();

            final int totalAnnual = AppSession().paidLeavesPerYear > 0
                ? AppSession().paidLeavesPerYear
                : 14;
            final int totalSick = 7;
            final int totalComp = 2;

            int usedAnnual = 0;
            int usedSick = 0;
            int usedComp = 0;

            for (var doc in leaveRequests) {
              final data = doc.data() as Map<String, dynamic>;
              if (data['status'] == 'approved') {
                final start = (data['fromDate'] as Timestamp?)?.toDate();
                if (start != null && start.year == now.year) {
                  final int days =
                      (data['durationInDays'] as num?)?.toInt() ?? 0;
                  final type = data['leaveType'] as String? ?? '';
                  if (type.contains('Sick')) {
                    usedSick += days;
                  } else if (type.contains('Comp') || type.contains('Off')) {
                    usedComp += days;
                  } else {
                    usedAnnual += days;
                  }
                }
              }
            }

            final remainingAnnual =
                (totalAnnual - usedAnnual).clamp(0, totalAnnual);
            final remainingSick = (totalSick - usedSick).clamp(0, totalSick);
            final remainingComp = (totalComp - usedComp).clamp(0, totalComp);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildLeaveCard(
                    title: 'Annual Leave',
                    remaining: remainingAnnual,
                    total: totalAnnual,
                    color: const Color(0xFF10B981),
                  ),
                  const SizedBox(height: 16),
                  _buildLeaveCard(
                    title: 'Sick Leave',
                    remaining: remainingSick,
                    total: totalSick,
                    color: const Color(
                        0xFF2563EB), // Using standard blue to match the screenshot
                  ),
                  const SizedBox(height: 16),
                  _buildLeaveCard(
                    title: 'Comp Off',
                    remaining: remainingComp,
                    total: totalComp,
                    color: const Color(0xFF8B5CF6),
                  ),
                ],
              ),
            );
          }),
    );
  }

  Widget _buildLeaveCard({
    required String title,
    required int remaining,
    required int total,
    required Color color,
  }) {
    final used = total - remaining;
    final progress = total > 0 ? used / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              Text(
                '$remaining days remaining',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFF3F4F6),
              color: color,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$total total',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}
