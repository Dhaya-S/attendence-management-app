import 'package:attendance_app/screens/employee/task_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';

class EmployeeTeamTasksTab extends StatefulWidget {
  const EmployeeTeamTasksTab({super.key});

  @override
  State<EmployeeTeamTasksTab> createState() => _EmployeeTeamTasksTabState();
}

class _EmployeeTeamTasksTabState extends State<EmployeeTeamTasksTab> {
  int _selectedTab = 1; // Default to In Progress based on screenshot
  final List<String> _tabs = ['ToDo', 'In Progress', 'Completed'];

  final List<Map<String, dynamic>> _todoTasks = [
    {
      'title': 'Wireframe Review v3',
      'priority': 'High',
      'priorityColor': const Color(0xFFEF4444),
      'priorityBg': const Color(0xFFFEF2F2),
      'assignee': 'Rahul Mehta',
      'due': 'Today, 6:00 PM',
    },
    {
      'title': 'Update Component Library',
      'priority': 'Medium',
      'priorityColor': const Color(0xFFF59E0B),
      'priorityBg': const Color(0xFFFFFBEB),
      'assignee': 'Rahul Mehta',
      'due': 'Tomorrow',
    },
    {
      'title': 'User Testing Prep',
      'priority': 'Low',
      'priorityColor': const Color(0xFF10B981),
      'priorityBg': const Color(0xFFECFDF5),
      'assignee': 'Rahul Mehta',
      'due': 'Wed, Jul 30',
    }
  ];

  final List<Map<String, dynamic>> _inProgressTasks = [
    {
      'title': 'Mobile Flow Design',
      'priority': 'High',
      'priorityColor': const Color(0xFFEF4444),
      'priorityBg': const Color(0xFFFEF2F2),
      'assignee': 'Rahul Mehta',
      'due': 'Today, 5:00 PM',
      'progress': 65,
    },
    {
      'title': 'Sprint Report Draft',
      'priority': 'High',
      'priorityColor': const Color(0xFFEF4444),
      'priorityBg': const Color(0xFFFEF2F2),
      'assignee': 'Rahul Mehta',
      'due': 'Today, 4:00 PM',
      'progress': 80,
    }
  ];

  final List<Map<String, dynamic>> _completedTasks = [
    {
      'title': 'Onboarding Screens',
      'assignee': 'Rahul Mehta',
      'completedDate': 'Jul 25, 2026',
      'status': 'Approved',
      'statusColor': const Color(0xFF10B981),
    },
    {
      'title': 'Design System Audit',
      'assignee': 'Rahul Mehta',
      'completedDate': 'Jul 22, 2026',
      'status': 'Pending',
      'statusColor': const Color(0xFFF59E0B),
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTabs(),
        const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
        Container(
          color: const Color(0xFFF9FAFB),
          child: _buildList(),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      color: Colors.white,
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final sel = _selectedTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: sel ? const Color(0xFF5C5CFF) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _tabs[i],
                    style: TextStyle(
                      color: sel
                          ? const Color(0xFF5C5CFF)
                          : const Color(0xFF6B7280),
                      fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildList() {
    final myDept = (AppSession().userDepartment ?? '').toString().trim().toLowerCase();
    final myEmail = (AppSession().email ?? '').toString().trim().toLowerCase();

    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.tasksCol.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final rawDocs = snapshot.data?.docs ?? [];
        final filteredDocs = rawDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final dept = (data['department'] ?? data['departmentName'] ?? '').toString().trim().toLowerCase();
          final assignedTo = (data['assignedTo'] ?? '').toString().trim().toLowerCase();
          if (AppSession().hasAdminAccess) return true;
          if (myDept.isNotEmpty && dept == myDept) return true;
          if (assignedTo == myEmail) return true;
          return false;
        }).toList();

        final todoTasks = <Map<String, dynamic>>[];
        final inProgressTasks = <Map<String, dynamic>>[];
        final completedTasks = <Map<String, dynamic>>[];

        for (var doc in filteredDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? 'todo').toString().toLowerCase();
          final item = {
            'id': doc.id,
            'title': data['title'] ?? data['taskName'] ?? 'Untitled Task',
            'priority': data['priority'] ?? 'Medium',
            'priorityColor': (data['priority'] == 'High') ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
            'priorityBg': (data['priority'] == 'High') ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
            'assignee': data['assignedToName'] ?? data['assignedTo'] ?? 'Team Member',
            'due': data['dueDate'] ?? 'Today',
            'progress': data['progress'] ?? 50,
            'completedDate': data['completedDate'] ?? 'Recently',
            'status': data['status'] ?? 'Pending',
            'statusColor': const Color(0xFF10B981),
            ...data,
          };
          if (status == 'completed' || status == 'done') {
            completedTasks.add(item);
          } else if (status == 'in progress' || status == 'in_progress' || status == 'active') {
            inProgressTasks.add(item);
          } else {
            todoTasks.add(item);
          }
        }

        List<Map<String, dynamic>> items = _selectedTab == 0
            ? (todoTasks.isNotEmpty ? todoTasks : _todoTasks)
            : (_selectedTab == 1
                ? (inProgressTasks.isNotEmpty ? inProgressTasks : _inProgressTasks)
                : (completedTasks.isNotEmpty ? completedTasks : _completedTasks));

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            if (_selectedTab == 0) return _buildTodoCard(items[index]);
            if (_selectedTab == 1) return _buildInProgressCard(items[index]);
            return _buildCompletedCard(items[index]);
          },
        );
      },
    );
  }

  Widget _buildTodoCard(Map<String, dynamic> data) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TaskDetailScreen(
              taskId: data['id'],
              initialTaskData: data,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    data['title'],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      data['priority'],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: data['priorityColor'],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded,
                        size: 16, color: Color(0xFF9CA3AF)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 14, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text(
                  data['assignee'],
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.access_time, size: 14, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text(
                  data['due'],
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Accept',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      if (data['id'] != null) {
                        await FirestoreService.tasksCol.doc(data['id']).update({
                          'status': 'in_progress',
                          'timerStart': FieldValue.serverTimestamp(),
                          'isPaused': false,
                        });
                      }
                    },
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5C5CFF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Start',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInProgressCard(Map<String, dynamic> data) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TaskDetailScreen(
              taskId: data['id'],
              initialTaskData: data,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    data['title'],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      data['priority'],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: data['priorityColor'],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded,
                        size: 16, color: Color(0xFF9CA3AF)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 14, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text(
                  data['assignee'],
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.access_time, size: 14, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text(
                  data['due'],
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: (data['progress'] as num?)?.toInt() ?? 50,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF5C5CFF),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 100 - ((data['progress'] as num?)?.toInt() ?? 50),
                          child: const SizedBox(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${data['progress']}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5C5CFF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showUpdateProgressSheet(
                        context, (data['progress'] as num?)?.toInt() ?? 50),
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFF5C5CFF)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.show_chart_rounded,
                              size: 16, color: Color(0xFF5C5CFF)),
                          SizedBox(width: 8),
                          Text(
                            'Update Progress',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF5C5CFF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chat_bubble_outline_rounded,
                      size: 16, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedCard(Map<String, dynamic> data) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TaskDetailScreen(
              taskId: data['id'],
              initialTaskData: data,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    data['title'],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                const Icon(Icons.check_circle_outline,
                    color: Color(0xFF10B981), size: 18),
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: Color(0xFF9CA3AF)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 14, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text(
                  data['assignee'],
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.check_circle_outline,
                    size: 14, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text(
                  data['completedDate'],
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Manager Review: ',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  data['status'],
                  style: TextStyle(
                    fontSize: 12,
                    color: data['statusColor'],
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateProgressSheet(BuildContext context, int initialProgress) {
    int currentProgress = initialProgress;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Update Progress',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Completion',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                      Text(
                        '$currentProgress%',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF5C5CFF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 6,
                      activeTrackColor: const Color(0xFF5C5CFF),
                      inactiveTrackColor: const Color(0xFFE5E7EB),
                      thumbColor: const Color(0xFF5C5CFF),
                      overlayColor:
                          const Color(0xFF5C5CFF).withValues(alpha: 0.1),
                    ),
                    child: Slider(
                      value: currentProgress.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 100,
                      onChanged: (val) {
                        setModalState(() {
                          currentProgress = val.toInt();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4B5563),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF5C5CFF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Save',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
