import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';

class AdminLeaveTab extends StatefulWidget {
  const AdminLeaveTab({super.key});

  @override
  State<AdminLeaveTab> createState() => _AdminLeaveTabState();
}

class _AdminLeaveTabState extends State<AdminLeaveTab> {
  final user = FirebaseAuth.instance.currentUser;
  late Stream<QuerySnapshot> _leaveRequestsStream;
  String _selectedFilter = 'All';

  final int maxAnnual = 18;
  final int maxSick = 7;
  final int maxCasual = 5;

  @override
  void initState() {
    super.initState();
    _leaveRequestsStream =
        FirestoreService.userLeaveRequestsCol(user?.email ?? '').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _leaveRequestsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data!.docs.toList();
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          
          final aDate = aData['fromDate'] as Timestamp?;
          final bDate = bData['fromDate'] as Timestamp?;
          
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });

        int usedAnnual = _calculateUsed(docs, 'Annual Leave');
        int usedSick = _calculateUsed(docs, 'Sick Leave');
        int usedCasual = _calculateUsed(docs, 'Casual Leave');

        // Filter the list for the history section
        List<QueryDocumentSnapshot> filteredDocs = docs;
        if (_selectedFilter != 'All') {
          filteredDocs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final type = data['leaveType'] as String? ?? '';
            return type == _selectedFilter;
          }).toList();
        }

        return Container(
          color: const Color(0xFFF4F6F9),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: FadeInUp(
              duration: const Duration(milliseconds: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LEAVE BALANCE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6B7280),
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildBalanceCard(
                          used: usedAnnual,
                          max: maxAnnual,
                          title: 'Annual',
                          bgColor: const Color(0xFFEEF2FF),
                          primaryColor: const Color(0xFF5C5CFF),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildBalanceCard(
                          used: usedSick,
                          max: maxSick,
                          title: 'Sick',
                          bgColor: const Color(0xFFF0F9FF),
                          primaryColor: const Color(0xFF1E40AF),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildBalanceCard(
                          used: usedCasual,
                          max: maxCasual,
                          title: 'Casual',
                          bgColor: const Color(0xFFFDF4FF),
                          primaryColor: const Color(0xFFD946EF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'LEAVE HISTORY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6B7280),
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildFilterChip('All'),
                        _buildFilterChip('Annual Leave'),
                        _buildFilterChip('Sick Leave'),
                        _buildFilterChip('Casual Leave'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Empty space placeholder
                  Row(
                    children: [
                      Expanded(child: Container(height: 32, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)))),
                      const SizedBox(width: 12),
                      Expanded(child: Container(height: 32, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  if (filteredDocs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No leaves found',
                          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                        ),
                      ),
                    )
                  else
                    ...filteredDocs.map((doc) => _buildLeaveHistoryCard(doc)),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  int _calculateUsed(List<QueryDocumentSnapshot> docs, String type) {
    int total = 0;
    final currentYear = DateTime.now().year;
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['leaveType'] == type && data['status']?.toString().toLowerCase() == 'approved') {
        final start = (data['fromDate'] as Timestamp?)?.toDate();
        if (start != null && start.year == currentYear) {
          total += (data['durationInDays'] as num?)?.toInt() ?? 0;
        }
      }
    }
    return total;
  }

  Widget _buildBalanceCard({
    required int used,
    required int max,
    required String title,
    required Color bgColor,
    required Color primaryColor,
  }) {
    final remaining = max - used;
    final double progress = max > 0 ? (used / max).clamp(0.0, 1.0) : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            used.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: primaryColor,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'of $max',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: primaryColor.withOpacity(0.2),
              color: primaryColor,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$remaining remaining',
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5C5CFF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF5C5CFF) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaveHistoryCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final leaveType = data['leaveType'] as String? ?? 'Leave';
    final status = (data['status'] as String? ?? 'pending').toLowerCase();
    
    // Status UI Configuration
    Color statusBgColor = const Color(0xFFF3F4F6);
    Color statusTextColor = const Color(0xFF6B7280);
    String statusText = 'Pending';
    
    if (status == 'approved') {
      statusBgColor = const Color(0xFFECFDF5);
      statusTextColor = const Color(0xFF10B981);
      statusText = 'Approved';
    } else if (status == 'rejected') {
      statusBgColor = const Color(0xFFFEF2F2);
      statusTextColor = const Color(0xFFEF4444);
      statusText = 'Rejected';
    }

    // Date formatting
    String dateRangeStr = '';
    final fromTimestamp = data['fromDate'] as Timestamp?;
    final toTimestamp = data['toDate'] as Timestamp?;
    final duration = (data['durationInDays'] as num?)?.toInt() ?? 1;
    
    if (fromTimestamp != null) {
      final fromDate = fromTimestamp.toDate();
      final fromStr = DateFormat('MMM d, yyyy').format(fromDate);
      
      if (toTimestamp != null) {
        final toDate = toTimestamp.toDate();
        // If same day
        if (fromDate.year == toDate.year && fromDate.month == toDate.month && fromDate.day == toDate.day) {
          dateRangeStr = '$fromStr · $duration day${duration > 1 ? 's' : ''}';
        } else {
          final toStr = DateFormat('MMM d, yyyy').format(toDate);
          dateRangeStr = '$fromStr \u2192 $toStr · $duration day${duration > 1 ? 's' : ''}';
        }
      } else {
        dateRangeStr = '$fromStr · $duration day${duration > 1 ? 's' : ''}';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leaveType,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  dateRangeStr,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusBgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: statusTextColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
