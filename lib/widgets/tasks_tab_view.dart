import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/screens/employee/task_detail_screen.dart';
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
  final Map<String, TextEditingController> _cardCommentControllers = {};

  @override
  void initState() {
    super.initState();
    // Update UI every second for live timers in "In Progress" tasks
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _cardCommentControllers.values) {
      controller.dispose();
    }
    _cardCommentControllers.clear();
    super.dispose();
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'AH';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  // Helper to format duration in hours and minutes (e.g. 1h 35m or 50m)
  String _formatDurationHM(int totalSeconds) {
    if (totalSeconds <= 0) return "0m";
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return "${hours}h ${minutes.toString().padLeft(2, '0')}m";
    }
    return "${minutes}m";
  }

  // Normalize status string from Firestore (web or mobile)
  String _normalizeStatus(Map<String, dynamic> data) {
    final raw = (data['status'] ?? 'assigned').toString().trim().toLowerCase();
    if (raw == 'in_progress' || raw == 'in progress' || raw == 'working' || raw == 'active') {
      return 'in_progress';
    }
    if (raw == 'completed' || raw == 'done' || raw == 'finished') {
      return 'completed';
    }
    if (raw == 'overdue') {
      return 'overdue';
    }
    if (raw == 'archived') {
      return 'archived';
    }
    return 'assigned';
  }

  bool _isAssignedToCurrentUser(Map<String, dynamic> data) {
    final userEmail = (AppSession().email ?? FirebaseAuth.instance.currentUser?.email ?? '').trim().toLowerCase();
    final userName = (AppSession().userName ?? FirebaseAuth.instance.currentUser?.displayName ?? '').trim().toLowerCase();
    final userUid = (AppSession().uid ?? FirebaseAuth.instance.currentUser?.uid ?? '').trim().toLowerCase();

    // 1. Web App Compatibility: check assignees array
    if (data['assignees'] is List) {
      final list = (data['assignees'] as List).map((e) => e.toString().trim().toLowerCase()).toList();
      if (userEmail.isNotEmpty && list.contains(userEmail)) return true;
      if (userUid.isNotEmpty && list.contains(userUid)) return true;
    }

    // 2. Web App Compatibility: check assignee map object
    if (data['assignee'] is Map) {
      final aMap = data['assignee'] as Map;
      final aMail = (aMap['email'] ?? aMap['userEmail'] ?? '').toString().trim().toLowerCase();
      final aUid = (aMap['uid'] ?? aMap['userId'] ?? '').toString().trim().toLowerCase();
      if (userEmail.isNotEmpty && aMail.isNotEmpty && aMail == userEmail) return true;
      if (userUid.isNotEmpty && aUid.isNotEmpty && aUid == userUid) return true;
    }

    final assigneeEmail = (data['assigneeEmail'] ?? data['assignedToEmail'] ?? data['employeeEmail'] ?? data['email'] ?? '').toString().trim().toLowerCase();
    final assignee = (data['assignee'] is String ? data['assignee'] : (data['assigneeName'] ?? data['assignedTo'] ?? '')).toString().trim().toLowerCase();
    final assigneeUid = (data['userId'] ?? data['uid'] ?? data['assignedToUid'] ?? data['assigneeId'] ?? '').toString().trim().toLowerCase();

    // Exact UID match
    if (userUid.isNotEmpty && assigneeUid.isNotEmpty && userUid == assigneeUid) return true;

    // Exact Email match
    if (userEmail.isNotEmpty) {
      if (assigneeEmail.isNotEmpty && assigneeEmail == userEmail) return true;
      if (assignee.isNotEmpty && assignee == userEmail) return true;
    }

    // Exact Name match (only if assigneeEmail is empty)
    if (userName.isNotEmpty && assignee.isNotEmpty && assigneeEmail.isEmpty) {
      if (assignee == userName) return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF9FAFB),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.tasksCol.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          // Clean up any previously seeded demo tasks so only real database tasks exist
          const demoTitles = [
            'Review Q3 Policy Updates',
            'Prepare Onboarding Docs',
            'Mobile Flow Design',
            'Sprint Report Draft',
            'Onboarding Screens',
            'Design System Audit',
            'Audit Leave Records - Q2',
            'Generate Payroll Report',
          ];

          final realDocs = docs.where((doc) {
            if (!FirestoreService.isDocInCurrentCompany(doc)) return false;
            final data = doc.data() as Map<String, dynamic>;
            final title = (data['title'] ?? '').toString();
            if (demoTitles.contains(title)) {
              doc.reference.delete();
              return false;
            }
            return true;
          }).toList();

          // Filter tasks so that each user ONLY sees real tasks assigned to them
          final userDocs = realDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _isAssignedToCurrentUser(data);
          }).toList();

          // Count tasks per category for current user
          int assignedCount = 0;
          int inProgressCount = 0;
          int completedCount = 0;
          int overdueCount = 0;

          for (var doc in userDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final normStatus = _normalizeStatus(data);

            if (normStatus == 'archived') continue;

            if (normStatus == 'assigned') assignedCount++;
            else if (normStatus == 'in_progress') inProgressCount++;
            else if (normStatus == 'completed') completedCount++;
            else if (normStatus == 'overdue') overdueCount++;
          }

          String targetStatus = 'assigned';
          if (_selectedTab == 1) targetStatus = 'in_progress';
          if (_selectedTab == 2) targetStatus = 'completed';
          if (_selectedTab == 3) targetStatus = 'overdue';

          final filteredDocs = userDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final normStatus = _normalizeStatus(data);
            if (normStatus == 'archived') return false;
            return normStatus == targetStatus;
          }).toList();

          return Column(
            children: [
              _buildSecondaryNav(assignedCount, inProgressCount, completedCount, overdueCount),
              Expanded(
                child: filteredDocs.isEmpty
                    ? Center(
                        child: Text(
                          'No tasks in ${_getTabName(_selectedTab)}.',
                          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final doc = filteredDocs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return _buildTaskCard(doc.id, data);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getTabName(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return 'Assigned';
      case 1:
        return 'In Progress';
      case 2:
        return 'Completed';
      case 3:
        return 'Overdue';
      default:
        return '';
    }
  }

  Widget _buildSecondaryNav(int assigned, int inProgress, int completed, int overdue) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildNavTab('Assigned($assigned)', 0),
            const SizedBox(width: 8),
            _buildNavTab('In Progress($inProgress)', 1),
            const SizedBox(width: 8),
            _buildNavTab('Completed($completed)', 2),
            const SizedBox(width: 8),
            _buildNavTab('Overdue($overdue)', 3),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF5C5CFF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF5C5CFF) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            color: isActive ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is String) {
      final s = val.trim();
      if (s.isEmpty) return null;
      final dt = DateTime.tryParse(s);
      if (dt != null) return dt;
      try {
        return DateFormat('MMM d, yyyy').parse(s);
      } catch (_) {}
      try {
        return DateFormat('yyyy-MM-dd').parse(s);
      } catch (_) {}
    }
    return null;
  }

  Widget _buildTaskCard(String id, Map<String, dynamic> data) {
    final normStatus = _normalizeStatus(data);
    final title = data['title'] ?? data['taskName'] ?? 'Untitled Task';
    final priority = data['priority'] ?? 'Medium';
    final assignedBy = data['assignedBy'] ?? data['department'] ?? data['reporterName'] ?? 'Unassigned';

    // Dates
    final dueDate = _parseDateTime(data['dueDate'] ?? data['due']);
    String dueDateStr = dueDate != null
        ? 'Due ${DateFormat('MMM d, yyyy').format(dueDate)}'
        : (data['due']?.toString() ?? 'No due date');

    if (normStatus == 'assigned') {
      return _buildAssignedCard(id, data, title, assignedBy, dueDateStr);
    } else if (normStatus == 'in_progress') {
      return _buildInProgressCard(id, data, title, priority);
    } else if (normStatus == 'completed') {
      return _buildCompletedCard(id, data, title);
    } else if (normStatus == 'overdue') {
      return _buildOverdueCard(id, data, title, assignedBy, dueDateStr);
    }

    return const SizedBox();
  }

  // ── Assigned Card UI (Matches Screen 1) ──────────────────────────────────
  Widget _buildAssignedCard(String id, Map<String, dynamic> data, String title, String assignedBy, String dueDateStr) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: id, initialTaskData: data)),
        );
      },
      child: Container(
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
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'By $assignedBy',
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF5C5CFF).withOpacity(0.2)),
                  ),
                  child: const Text(
                    'Assigned',
                    style: TextStyle(
                      color: Color(0xFF5C5CFF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    await FirestoreService.tasksCol.doc(id).update({
                      'status': 'In Progress',
                      'taskStatus': 'In Progress',
                      'timerStart': FieldValue.serverTimestamp(),
                      'isPaused': false,
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5C5CFF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Start',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
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

  // ── In Progress Card UI (Matches Screen 2) ──────────────────────────────
  Widget _buildInProgressCard(String id, Map<String, dynamic> data, String title, String priority) {
    final isPaused = data['isPaused'] == true;
    final timerStart = _parseDateTime(data['timerStart'] ?? data['startedAt']);
    final startTimeStr = timerStart != null
        ? DateFormat('hh:mm a').format(timerStart)
        : '-';

    // Calculate real-time elapsed seconds
    int baseElapsed = (data['totalElapsedSeconds'] as num?)?.toInt() ?? 0;
    if (!isPaused && timerStart != null) {
      final now = DateTime.now();
      final diff = now.difference(timerStart).inSeconds;
      if (diff > 0) baseElapsed += diff;
    }

    double estHours = (data['estimatedHours'] as num?)?.toDouble() ?? 0.0;
    int estSeconds = (estHours * 3600).toInt();
    int remainingSeconds = estSeconds > baseElapsed ? estSeconds - baseElapsed : 0;

    _cardCommentControllers[id] ??= TextEditingController();
    final commentCtrl = _cardCommentControllers[id]!;
    final userInitials = _getInitials(AppSession().userName ?? FirebaseAuth.instance.currentUser?.displayName ?? 'AH');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: id, initialTaskData: data)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Title & Priority
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Text(
                        priority,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFFEF4444)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Working status tag
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isPaused ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isPaused ? 'Paused' : 'Working',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isPaused ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                  ),
                ),
                if (startTimeStr != '-') ...[
                  const SizedBox(width: 8),
                  Text(
                    'Started $startTimeStr',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),

            // Stats grid: Elapsed | Remaining | Est Time
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          _formatDurationHM(baseElapsed),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Elapsed',
                          style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          estSeconds > 0 ? _formatDurationHM(remainingSeconds) : '-',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Remaining',
                          style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          estSeconds > 0 ? _formatDurationHM(estSeconds) : 'Not set',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Est. Time',
                          style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Realtime Comment Input Inside Card
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF5C5CFF),
                  child: Text(
                    userInitials,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Add a comment...',
                              hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (val) => _submitComment(id, val, commentCtrl),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _submitComment(id, commentCtrl.text, commentCtrl),
                          child: const Icon(Icons.send_rounded, size: 16, color: Color(0xFF5C5CFF)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Action Buttons: Pause & Complete
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      if (isPaused) {
                        // Resume
                        await FirestoreService.tasksCol.doc(id).update({
                          'isPaused': false,
                          'timerStart': FieldValue.serverTimestamp(),
                        });
                      } else {
                        // Pause
                        await FirestoreService.tasksCol.doc(id).update({
                          'isPaused': true,
                          'totalElapsedSeconds': baseElapsed,
                        });
                      }
                    },
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isPaused ? 'Resume' : 'Pause',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showCompleteConfirmation(id),
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Complete',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
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

  // ── Completed Card UI (Matches Screen 3) ──────────────────────────────
  Widget _buildCompletedCard(String id, Map<String, dynamic> data, String title) {
    final assignee = data['assignee'] ?? data['assigneeName'] ?? data['assignedToName'] ?? data['assignedTo'] ?? 'Unassigned';
    final compDt = _parseDateTime(data['completedAt'] ?? data['completedDate']);
    final completedDate = compDt != null ? DateFormat('MMM d, yyyy').format(compDt) : (data['completedDate']?.toString() ?? '-');
    final managerReview = data['managerReview'] ?? 'Pending';
    final isApproved = managerReview.toString().toLowerCase() == 'approved';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: id, initialTaskData: data)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                  ),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF10B981), width: 2),
                  ),
                  child: const Icon(Icons.check_rounded, size: 16, color: Color(0xFF10B981)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text(
                  assignee,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF10B981)),
                const SizedBox(width: 4),
                Text(
                  completedDate,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Manager Review: ',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                ),
                Text(
                  managerReview,
                  style: TextStyle(
                    fontSize: 12,
                    color: isApproved ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _showArchiveConfirmation(id),
              child: Container(
                width: double.infinity,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.insert_drive_file_outlined, size: 16, color: Color(0xFF4B5563)),
                    SizedBox(width: 8),
                    Text(
                      'Archive',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Overdue Card UI (Matches Screen 4) ──────────────────────────────
  Widget _buildOverdueCard(String id, Map<String, dynamic> data, String title, String assignedBy, String dueDateStr) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: id, initialTaskData: data)),
        );
      },
      child: Container(
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
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'By $assignedBy',
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
              ),
              child: const Text(
                'Overdue',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Submit comment to Firestore in real-time
  Future<void> _submitComment(String id, String text, TextEditingController ctrl) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    try {
      ctrl.clear();
      final userName = AppSession().userName ?? FirebaseAuth.instance.currentUser?.displayName ?? 'User';
      final userId = AppSession().uid ?? FirebaseAuth.instance.currentUser?.uid ?? '';
      final initials = _getInitials(userName);

      final commentObj = {
        'id': 'c_${DateTime.now().millisecondsSinceEpoch}',
        'text': trimmed,
        'authorId': userId,
        'userId': userId,
        'authorName': userName,
        'userName': userName,
        'authorInitials': initials,
        'initials': initials,
        'color': 0xFF5C5CFF,
        'createdAt': DateTime.now().toIso8601String(),
      };
      await FirestoreService.tasksCol.doc(id).update({
        'comments': FieldValue.arrayUnion([commentObj]),
      });
    } catch (e) {
      debugPrint('Error adding comment: $e');
    }
  }

  // ── Complete Task Confirmation Bottom Sheet (Matches Image 3) ─────────────────
  void _showCompleteConfirmation(String id) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Complete Task?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                ),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Are you sure you want to mark this task as complete? This action cannot be undone.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        await FirestoreService.tasksCol.doc(id).update({
                          'status': 'Done',
                          'taskStatus': 'Done',
                          'completedDate': DateFormat('MMM d, yyyy').format(DateTime.now()),
                          'completedAt': FieldValue.serverTimestamp(),
                        });
                      },
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Complete',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Archive Task Confirmation Bottom Sheet (Matches Image 3) ────────────────
  void _showArchiveConfirmation(String id) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Archive Task?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                ),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'The task will be archived and hidden from your Completed list. You can still find it in History.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Keep',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        await FirestoreService.tasksCol.doc(id).update({
                          'status': 'archived',
                          'isArchived': true,
                          'archivedAt': FieldValue.serverTimestamp(),
                        });
                      },
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Archive',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

