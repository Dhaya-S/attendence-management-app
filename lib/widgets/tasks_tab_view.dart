import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class TasksTabView extends StatefulWidget {
  const TasksTabView({super.key});

  @override
  State<TasksTabView> createState() => _TasksTabViewState();
}

class _TasksTabViewState extends State<TasksTabView> {
  int _selectedTab = 0; // 0: Assigned, 1: In Progress, 2: Completed, 3: Overdue
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Update UI every second for timers in "In Progress" tasks
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_selectedTab == 1 && mounted) {
        setState(() {}); // Trigger rebuild to update timers
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF9FAFB),
      child: Column(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirestoreService.allTasksQuery.snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              
              int assignedCount = 0;
              int inProgressCount = 0;
              int completedCount = 0;
              int overdueCount = 0;

              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status'] as String? ?? 'assigned';
                if (status == 'assigned') assignedCount++;
                else if (status == 'in_progress') inProgressCount++;
                else if (status == 'completed') completedCount++;
                else if (status == 'overdue') overdueCount++;
              }

              return _buildSecondaryNav(assignedCount, inProgressCount, completedCount, overdueCount);
            },
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirestoreService.allTasksQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];
                
                String targetStatus = 'assigned';
                if (_selectedTab == 1) targetStatus = 'in_progress';
                if (_selectedTab == 2) targetStatus = 'completed';
                if (_selectedTab == 3) targetStatus = 'overdue';

                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'] as String? ?? 'assigned';
                  return status == targetStatus;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(child: Text('No tasks found.', style: TextStyle(color: Color(0xFF6B7280))));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildTaskCard(doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryNav(int assigned, int inProgress, int completed, int overdue) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildNavTab('Assigned ($assigned)', 0),
            _buildNavTab('In Progress ($inProgress)', 1),
            _buildNavTab('Completed ($completed)', 2),
            _buildNavTab('Overdue ($overdue)', 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavTab(String label, int index) {
    final isActive = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFF5C5CFF) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            color: isActive ? const Color(0xFF5C5CFF) : const Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCard(String id, Map<String, dynamic> data) {
    final title = data['title'] ?? 'Untitled Task';
    final department = data['department'] ?? 'Unknown Dept';
    final status = data['status'] ?? 'assigned';
    final dueDateTimestamp = data['dueDate'] as Timestamp?;
    final timerStartTimestamp = data['timerStart'] as Timestamp?;

    String dueDateStr = 'No due date';
    if (dueDateTimestamp != null) {
      dueDateStr = 'Due ${DateFormat('MMM d, yyyy').format(dueDateTimestamp.toDate())}';
    }

    String timerStr = '00:00:00';
    if (status == 'in_progress' && timerStartTimestamp != null) {
      final now = DateTime.now();
      final diff = now.difference(timerStartTimestamp.toDate());
      timerStr = _formatDuration(diff);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                ),
                const SizedBox(height: 12),
                Text(
                  'By $department',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  dueDateStr,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildStatusChip(status),
              const SizedBox(height: 16),
              if (status == 'assigned')
                _buildActionButton('Start', const Color(0xFF5C5CFF), () {
                  FirestoreService.companyDoc().collection('tasks').doc(id).update({
                    'status': 'in_progress',
                    'timerStart': FieldValue.serverTimestamp(),
                  });
                }),
              if (status == 'in_progress')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timerStr,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                    ),
                    const SizedBox(height: 8),
                    _buildActionButton('Complete', const Color(0xFF10B981), () {
                      FirestoreService.companyDoc().collection('tasks').doc(id).update({
                        'status': 'completed',
                      });
                    }),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'assigned':
        bgColor = const Color(0xFFEEF2FF);
        textColor = const Color(0xFF5C5CFF);
        label = 'Assigned';
        break;
      case 'in_progress':
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFF59E0B);
        label = 'In Progress';
        break;
      case 'completed':
        bgColor = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF10B981);
        label = 'Completed';
        break;
      case 'overdue':
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFEF4444);
        label = 'Overdue';
        break;
      default:
        bgColor = Colors.grey.shade200;
        textColor = Colors.grey;
        label = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
