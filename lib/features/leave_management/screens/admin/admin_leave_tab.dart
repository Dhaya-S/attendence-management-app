import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:attendance_app/theme/app_theme.dart';
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
  String _selectedFilter = 'All';

  final int maxAnnual = 18;
  final int maxSick = 7;
  final int maxCasual = 5;

  @override
  void initState() {
    super.initState();
    _leaveRequestsStream = FirestoreService.leaveRequestsCol.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = (user?.email ?? AppSession().email ?? '').toLowerCase();
    return StreamBuilder<QuerySnapshot>(
      stream: _leaveRequestsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        // Filter by email client-side to support all field name variants
        final currentCompanyId = AppSession().companyId;
        final allDocs = snapshot.data?.docs ?? [];
        final docs = allDocs.where((doc) {
          if (!FirestoreService.isDocInCurrentCompany(doc)) {
            return false;
          }
          final d = doc.data() as Map<String, dynamic>;
          final e1 = (d['applicantEmail'] ?? '').toString().toLowerCase();
          final e2 = (d['employeeEmail'] ?? '').toString().toLowerCase();
          final e3 = (d['email'] ?? '').toString().toLowerCase();
          return e1 == userEmail || e2 == userEmail || e3 == userEmail;
        }).toList();

        DateTime? parseDate(dynamic d) {
          if (d is Timestamp) return d.toDate();
          if (d is DateTime) return d;
          if (d is String) return DateTime.tryParse(d);
          return null;
        }

        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          
          final aDate = parseDate(aData['fromDate'] ?? aData['from']);
          final bDate = parseDate(bData['fromDate'] ?? bData['from']);
          
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });

        int usedAnnual = _calculateUsed(docs, 'Annual');
        int usedSick = _calculateUsed(docs, 'Sick');
        int usedCasual = _calculateUsed(docs, 'Casual');

        // Filter the list for the history section
        List<QueryDocumentSnapshot> filteredDocs = docs;
        if (_selectedFilter != 'All') {
          final target = _selectedFilter.toLowerCase().replaceAll(' leave', '').trim();
          filteredDocs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final type = (data['leaveType'] ?? data['type'] ?? data['category'] ?? '').toString().toLowerCase();
            if (type.contains(target)) return true;
            if ((type.isEmpty || type == 'leave') && target == 'annual') return true;
            return false;
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

  int _calculateUsed(List<QueryDocumentSnapshot> docs, String typeKeyword) {
    int total = 0;
    final currentYear = DateTime.now().year;
    final target = typeKeyword.toLowerCase();

    int calculateWorkingDays(DateTime from, DateTime to) {
      final start = DateTime(from.year, from.month, from.day);
      final end = DateTime(to.year, to.month, to.day);
      int count = 0;
      DateTime current = start;
      while (!current.isAfter(end)) {
        if (current.weekday != DateTime.saturday && current.weekday != DateTime.sunday) {
          count++;
        }
        current = current.add(const Duration(days: 1));
      }
      return count;
    }

    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      if (d is Timestamp) return d.toDate();
      if (d is DateTime) return d;
      if (d is String) return DateTime.tryParse(d);
      return null;
    }

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final leaveType = (data['leaveType'] ?? data['type'] ?? 'Annual Leave').toString().toLowerCase();
      final status = (data['status'] ?? '').toString().toLowerCase();
      
      bool matches = leaveType.contains(target);
      if (!matches && (leaveType == 'leave' || leaveType.isEmpty)) {
        if (target == 'annual') matches = true;
      }

      if (matches && status == 'approved') {
        final start = parseDate(data['fromDate'] ?? data['from'] ?? data['startDate']);
        final end = parseDate(data['toDate'] ?? data['to'] ?? data['endDate']);

        if (start == null || start.year == currentYear) {
          int days = 1;
          if (start != null && end != null) {
            days = calculateWorkingDays(start, end);
          } else {
            days = ((data['durationInDays'] ?? data['days']) as num?)?.toInt() ?? 1;
          }
          total += days;
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
    String leaveType = (data['leaveType'] ?? data['type'] ?? data['category'] ?? '').toString();
    if (leaveType.isEmpty || leaveType.toLowerCase() == 'leave') {
      final r = (data['reason'] ?? '').toString();
      if (r.isNotEmpty && r.length < 25) {
        leaveType = '${r[0].toUpperCase()}${r.substring(1)} Leave';
      } else {
        leaveType = 'Casual Leave';
      }
    }

    final reason = (data['reason'] ?? '').toString();
    final applicant = (data['applicantName'] ?? data['employee'] ?? data['userName'] ?? '').toString();
    final status = (data['status'] as String? ?? 'pending').toLowerCase();
    
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

    String dateRangeStr = '';
    DateTime? parseDate(dynamic d) {
      if (d is Timestamp) return d.toDate();
      if (d is DateTime) return d;
      if (d is String) return DateTime.tryParse(d);
      return null;
    }

    final fromDate = parseDate(data['fromDate'] ?? data['from']);
    final toDate = parseDate(data['toDate'] ?? data['to']);
    final duration = ((data['durationInDays'] ?? data['days']) as num?)?.toInt() ?? 1;
    
    if (fromDate != null) {
      final fromStr = DateFormat('MMM d, yyyy').format(fromDate);
      if (toDate != null) {
        if (fromDate.year == toDate.year && fromDate.month == toDate.month && fromDate.day == toDate.day) {
          dateRangeStr = '$fromStr · $duration day${duration > 1 ? 's' : ''}';
        } else {
          final toStr = DateFormat('MMM d, yyyy').format(toDate);
          dateRangeStr = '$fromStr → $toStr · $duration day${duration > 1 ? 's' : ''}';
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
                const SizedBox(height: 4),
                Text(
                  dateRangeStr,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (applicant.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Applicant: $applicant',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
                  ),
                ],
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Reason: "$reason"',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563), fontStyle: FontStyle.italic),
                  ),
                ],
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
