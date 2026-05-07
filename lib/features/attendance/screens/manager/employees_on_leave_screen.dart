import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/utils/firestore_service.dart';

class EmployeesOnLeaveScreen extends StatefulWidget {
  const EmployeesOnLeaveScreen({super.key});

  @override
  State<EmployeesOnLeaveScreen> createState() => _EmployeesOnLeaveScreenState();
}

class _EmployeesOnLeaveScreenState extends State<EmployeesOnLeaveScreen> {
  static const Color _indigo = Color(0xFF6366F1);
  static const Color _slate = Color(0xFF1E293B);
  
  String _selectedStatus = 'All'; // All, Approved, Pending

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text('Employees On Leave', style: TextStyle(color: Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.leaveRequestsCol.snapshots(),
        builder: (context, leaveSnap) {
          if (!leaveSnap.hasData) return const Center(child: CircularProgressIndicator());
          
          final docs = leaveSnap.data!.docs;
          DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

          Map<String, int> leaveCounts = {
            'Casual': 0,
            'Sick': 0,
            'WFH': 0,
            'Paid': 0
          };

          List<Map<String, dynamic>> leaveList = [];

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final fromTs = data['fromDate'] as Timestamp?;
            final toTs = data['toDate'] as Timestamp?;
            if (fromTs == null || toTs == null) continue;
            
            DateTime start = DateTime(fromTs.toDate().year, fromTs.toDate().month, fromTs.toDate().day);
            DateTime end = DateTime(toTs.toDate().year, toTs.toDate().month, toTs.toDate().day);

            // Check if leave is relevant (current or upcoming in this month)
            // Just show all active and future for now to mimic proper filtering, 
            // but for stats, count active ones (or approved ones active today)
            bool isActiveToday = !today.isBefore(start) && !today.isAfter(end);
            String status = (data['status']?.toString() ?? 'Pending');
            String type = data['leaveType']?.toString() ?? 'Casual Leave';
            
            if (isActiveToday && status.toLowerCase() == 'approved') {
              if (type.contains('Casual')) leaveCounts['Casual'] = leaveCounts['Casual']! + 1;
              else if (type.contains('Sick')) leaveCounts['Sick'] = leaveCounts['Sick']! + 1;
              else if (type.contains('Work From Home') || type.contains('WFH')) leaveCounts['WFH'] = leaveCounts['WFH']! + 1;
              else leaveCounts['Paid'] = leaveCounts['Paid']! + 1;
            }

            // Filter for the list based on selected tab
            if (_selectedStatus != 'All' && status.toLowerCase() != _selectedStatus.toLowerCase()) continue;
            
            // Limit to leaves that overlap with this month for the list
            if (end.month != today.month && start.month != today.month) continue;

            leaveList.add({
              'name': data['userName'] ?? 'Employee',
              'type': type,
              'status': status,
              'days': end.difference(start).inDays + 1,
              'start': start,
              'end': end,
              'isActiveToday': isActiveToday,
            });
          }

          leaveList.sort((a, b) => b['start'].compareTo(a['start']));

          int totalActive = leaveCounts.values.fold(0, (sum, val) => sum + val);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _buildFilters(),
                const SizedBox(height: 24),
                _buildLeaveOverview(totalActive, leaveCounts),
                const SizedBox(height: 24),
                _buildStatusTabs(),
                const SizedBox(height: 24),
                ...leaveList.map((leave) => _buildLeaveRow(leave)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilters() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildFilterChip('THIS MONTH', isActive: true),
        _buildFilterChip('LEAVE TYPE', isActive: false),
        _buildFilterChip('DEPARTMENT', isActive: false),
      ],
    );
  }

  Widget _buildFilterChip(String label, {required bool isActive}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? _indigo : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isActive ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: isActive ? Colors.white : Colors.grey[500],
        ),
      ),
    );
  }

  Widget _buildLeaveOverview(int totalActive, Map<String, int> counts) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LEAVE OVERVIEW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey[400], letterSpacing: 1)),
          const SizedBox(height: 8),
          Text('Total Employees on\nLeave: $totalActive', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _slate, height: 1.2)),
          const SizedBox(height: 24),
          // Progress bar
          if (totalActive > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  if (counts['Casual']! > 0) Expanded(flex: counts['Casual']!, child: Container(height: 8, color: const Color(0xFFFBBF24))),
                  if (counts['Sick']! > 0) Expanded(flex: counts['Sick']!, child: Container(height: 8, color: const Color(0xFFF43F5E))),
                  if (counts['WFH']! > 0) Expanded(flex: counts['WFH']!, child: Container(height: 8, color: const Color(0xFF6366F1))),
                  if (counts['Paid']! > 0) Expanded(flex: counts['Paid']!, child: Container(height: 8, color: const Color(0xFF10B981))),
                ],
              ),
            ),
          if (totalActive > 0) const SizedBox(height: 24),
          // Legend
          Row(
            children: [
              Expanded(child: _buildLegendItem('Casual (${counts['Casual']})', const Color(0xFFFBBF24))),
              Expanded(child: _buildLegendItem('Sick (${counts['Sick']})', const Color(0xFFF43F5E))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildLegendItem('WFH (${counts['WFH']})', const Color(0xFF6366F1))),
              Expanded(child: _buildLegendItem('Paid (${counts['Paid']})', const Color(0xFF10B981))),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.trending_up, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 8),
              Text('Peak leave observed on Friday', style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _slate)),
      ],
    );
  }

  Widget _buildStatusTabs() {
    return Row(
      children: ['All', 'Approved', 'Pending'].map((status) {
        bool isActive = _selectedStatus == status;
        return GestureDetector(
          onTap: () => setState(() => _selectedStatus = status),
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? _indigo.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isActive ? Colors.transparent : Colors.grey[200]!, width: 1),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isActive ? _indigo : Colors.grey[500],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLeaveRow(Map<String, dynamic> leave) {
    Color typeColor;
    String typeText = leave['type'].toString().toLowerCase();
    if (typeText.contains('casual')) typeColor = const Color(0xFFFBBF24);
    else if (typeText.contains('sick')) typeColor = const Color(0xFFF43F5E);
    else if (typeText.contains('wfh') || typeText.contains('work from home')) typeColor = const Color(0xFF6366F1);
    else typeColor = const Color(0xFF10B981);

    Color statusColor = leave['status'].toString().toLowerCase() == 'approved' ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    
    // Format date string
    String dateStr;
    if (leave['isActiveToday']) {
      dateStr = 'Today';
    } else {
      if (leave['days'] == 1) {
        dateStr = DateFormat('MMMM d').format(leave['start']);
      } else {
        dateStr = '${DateFormat('MMMM d').format(leave['start'])} - ${DateFormat('d').format(leave['end'])}';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              leave['name'][0].toUpperCase(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _slate),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(leave['name'], style: const TextStyle(fontWeight: FontWeight.w900, color: _slate, fontSize: 16)),
                const SizedBox(height: 2),
                Text('Employee', style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 6, height: 6, decoration: BoxDecoration(color: typeColor, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text(leave['type'], style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${leave['days']} Day${leave['days'] > 1 ? 's' : ''}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _slate)),
              const SizedBox(height: 4),
              Text(leave['status'].toString().toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 0.5)),
            ],
          ),
        ],
      ),
    );
  }
}
