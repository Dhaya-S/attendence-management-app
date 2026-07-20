import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/utils/firestore_service.dart';

class EmployeeHistoryScreen extends StatefulWidget {
  const EmployeeHistoryScreen({super.key});

  @override
  State<EmployeeHistoryScreen> createState() => _EmployeeHistoryScreenState();
}

class _EmployeeHistoryScreenState extends State<EmployeeHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('History', style: TextStyle(color: Color(0xFF111827), fontSize: 18, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF6366F1), 
          unselectedLabelColor: const Color(0xFF9CA3AF),
          indicatorColor: const Color(0xFF6366F1),
          indicatorWeight: 2,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          tabs: const [
            Tab(text: 'Tasks'),
            Tab(text: 'Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _TasksTab(),
          _RequestsTab(),
        ],
      ),
    );
  }
}

class _TasksTab extends StatefulWidget {
  const _TasksTab();
  @override
  State<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<_TasksTab> {
  String _selectedFilter = 'In Progress';
  final List<String> _filters = ['In Progress', 'Completed', 'History'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Chips
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: _filters.map((f) {
              final isSelected = f == _selectedFilter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedFilter = f),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      f,
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF4B5563),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        // List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirestoreService.tasksCol
                .where('assignedToEmail', isEqualTo: FirebaseAuth.instance.currentUser?.email)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
              }
              
              var docs = snapshot.data?.docs ?? [];
              
              // Filter logic based on status
              if (_selectedFilter == 'In Progress') {
                docs = docs.where((d) => (d.data() as Map)['status'] != 'Completed').toList();
              } else if (_selectedFilter == 'Completed') {
                docs = docs.where((d) => (d.data() as Map)['status'] == 'Completed').toList();
              }

              if (docs.isEmpty) {
                return const Center(child: Text('No tasks found.', style: TextStyle(color: Colors.grey)));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  return _buildTaskCard(data);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> data) {
    final title = data['title'] ?? 'Task';
    final priority = data['priority'] ?? 'High';
    final assignedBy = data['assignedByName'] ?? 'Manager';
    final progress = (data['progress'] ?? 65).toInt(); // Fallback to 65 for UI mock if missing
    final dueDate = data['dueDate'] as Timestamp?;
    
    String timeLeft = '2h 30m left'; // Fallback
    if (dueDate != null) {
      final diff = dueDate.toDate().difference(DateTime.now());
      if (diff.isNegative) {
        timeLeft = 'Overdue';
      } else if (diff.inDays > 0) {
        timeLeft = '${diff.inDays} days left';
      } else {
        timeLeft = '${diff.inHours}h ${diff.inMinutes % 60}m left';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF111827)))),
              Text(priority, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF111827))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 14, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 4),
              Text(assignedBy, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
              const SizedBox(width: 16),
              const Icon(Icons.access_time, size: 14, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 4),
              Text(timeLeft, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF3F4F6),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('$progress%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Continue Task', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestsTab extends StatefulWidget {
  const _RequestsTab();
  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab> {
  String _selectedFilter = 'Attendance';
  final List<String> _filters = ['Attendance', 'Leave', 'Work From Home'];

  Stream<List<Map<String, dynamic>>> _buildRequestsStream() {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    
    final correctionsStream = FirebaseFirestore.instance
        .collection('organizations')
        .doc(FirestoreService.companyId)
        .collection('attendance_corrections')
        .where('userId', isEqualTo: email)
        .snapshots();

    return correctionsStream.asyncMap((corrSnap) async {
      final leaveSnap = await FirestoreService.userLeaveRequestsCol(email).get();

      final List<Map<String, dynamic>> items = [];

      for (final doc in corrSnap.docs) {
        final d = doc.data();
        items.add({
          'id': doc.id,
          'type': 'Attendance Correction',
          'filterCategory': 'Attendance',
          'status': d['status'] ?? 'pending',
          'createdAt': d['createdAt'],
          'approvedBy': d['approvedByName'] ?? '-',
        });
      }

      for (final doc in leaveSnap.docs) {
        final d = doc.data();
        final lType = d['leaveType'] as String? ?? '';
        final isWfh = lType.toLowerCase() == 'wfh';
        
        items.add({
          'id': doc.id,
          'type': isWfh ? 'Work From Home' : 'Leave Request',
          'filterCategory': isWfh ? 'Work From Home' : 'Leave',
          'status': d['status'] ?? 'pending',
          'createdAt': d['createdAt'],
          'approvedBy': d['approvedByName'] ?? '-',
        });
      }

      items.sort((a, b) {
        final ta = a['createdAt'] as Timestamp?;
        final tb = b['createdAt'] as Timestamp?;
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
    return Column(
      children: [
        // Chips
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((f) {
                final isSelected = f == _selectedFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedFilter = f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        f,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF4B5563),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        // List
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _buildRequestsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
              }
              
              var items = snapshot.data ?? [];
              items = items.where((item) => item['filterCategory'] == _selectedFilter).toList();

              if (items.isEmpty) {
                return const Center(child: Text('No requests found.', style: TextStyle(color: Colors.grey)));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, i) => _buildRequestCard(items[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> data) {
    final title = data['type'] ?? 'Request';
    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    final createdAt = data['createdAt'] as Timestamp?;
    final approvedBy = data['approvedBy'] ?? '-';
    
    final dateStr = createdAt != null ? DateFormat('MMM d').format(createdAt.toDate()) : '--';

    Color bg; Color fg; String label;
    if (status == 'approved') {
      bg = const Color(0xFFECFDF5); fg = const Color(0xFF10B981); label = 'Approved';
    } else if (status == 'rejected') {
      bg = const Color(0xFFFEF2F2); fg = const Color(0xFFEF4444); label = 'Rejected';
    } else {
      bg = const Color(0xFFFFFBEB); fg = const Color(0xFFD97706); label = 'Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827)))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: fg.withOpacity(0.2))),
                child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 4),
              Text('Applied $dateStr', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
              const SizedBox(width: 16),
              const Icon(Icons.person_outline, size: 14, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 4),
              Text(approvedBy, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
            ],
          ),
        ],
      ),
    );
  }
}
