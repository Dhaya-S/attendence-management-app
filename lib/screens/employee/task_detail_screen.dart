import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class TaskDetailScreen extends StatefulWidget {
  final String? taskId;
  final Map<String, dynamic>? initialTaskData;

  const TaskDetailScreen({
    super.key,
    this.taskId,
    this.initialTaskData,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _commentController.dispose();
    super.dispose();
  }

  String _formatDurationHM(int totalSeconds) {
    if (totalSeconds <= 0) return "0m";
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return "${hours}h ${minutes.toString().padLeft(2, '0')}m";
    }
    return "${minutes}m";
  }

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
    // A task that was never started and is past its due date counts as overdue
    // (the web board marks these "Overdue" too).
    final due = FirestoreService.parseAnyDate(data['dueDate'] ?? data['due']);
    if (due != null) {
      final t = DateTime.now();
      if (DateTime(due.year, due.month, due.day).isBefore(DateTime(t.year, t.month, t.day))) {
        return 'overdue';
      }
    }
    return 'assigned';
  }

  @override
  Widget build(BuildContext context) {
    final docId = widget.taskId;

    if (docId == null || docId.isEmpty) {
      return _buildContent(widget.initialTaskData ?? {}, null);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirestoreService.tasksCol.doc(docId).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.hasData && snapshot.data!.exists
            ? (snapshot.data!.data() as Map<String, dynamic>)
            : (widget.initialTaskData ?? {});
        return _buildContent(data, docId);
      },
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

  Widget _buildContent(Map<String, dynamic> data, String? docId) {
    final title = data['title'] ?? data['taskName'] ?? 'Untitled Task';
    final normStatus = _normalizeStatus(data);
    final assignedBy = data['assignedBy'] ?? data['reporterName'] ?? data['department'] ?? data['dept'] ?? 'Unassigned';

    // Due Date
    final dueDate = _parseDateTime(data['dueDate'] ?? data['due']);
    String dueDateStr = dueDate != null
        ? DateFormat('MMM d, yyyy').format(dueDate)
        : (data['due']?.toString() ?? 'No due date');

    // Est Hours
    double estHours = (data['estimatedHours'] as num?)?.toDouble() ??
        (((data['originalEstimateMinutes'] as num?)?.toDouble() ?? 0.0) / 60.0);
    String estTimeStr = estHours > 0
        ? (estHours == estHours.roundToDouble()
            ? '${estHours.toInt()} hours'
            : '${estHours.toStringAsFixed(1)} hours')
        : 'Not set';

    // Timing data if in progress or started
    final isPaused = data['isPaused'] == true;
    final timerStart = _parseDateTime(data['timerStart'] ?? data['startedAt']);
    final startedTimeStr = timerStart != null
        ? DateFormat('hh:mm a').format(timerStart)
        : '-';

    final expectedFinishStr = (timerStart != null && estHours > 0)
        ? DateFormat('hh:mm a').format(timerStart.add(Duration(hours: estHours.toInt())))
        : '-';

    int baseElapsed = (data['totalElapsedSeconds'] as num?)?.toInt() ?? 0;
    if (!isPaused && timerStart != null) {
      final diff = DateTime.now().difference(timerStart).inSeconds;
      if (diff > 0) baseElapsed += diff;
    }

    int estSeconds = (estHours * 3600).toInt();
    int remainingSeconds = estSeconds - baseElapsed;
    if (remainingSeconds < 0) remainingSeconds = 0;

    int progress = (data['progress'] as num?)?.toInt() ?? (estSeconds > 0 ? ((baseElapsed / estSeconds) * 100).clamp(0, 100).toInt() : 0);

    // Comments list from Firestore
    final List<dynamic> rawComments = data['comments'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE5E7EB), height: 1),
        ),
        title: const Text(
          'Task Detail',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.insert_drive_file_outlined, color: Color(0xFF5C5CFF)),
            onPressed: () {
              if (docId != null) _showArchiveConfirmation(docId);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Status Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildStatusPill(normStatus),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Metadata Info Grid (Assigned By, Due Date, Est Time)
                  _buildMetaRow('Assigned By', assignedBy),
                  const SizedBox(height: 8),
                  _buildMetaRow('Due Date', dueDateStr),
                  const SizedBox(height: 8),
                  _buildMetaRow('Estimated time', estTimeStr),
                  const SizedBox(height: 20),

                  // Live Timing Details Container if In Progress
                  if (normStatus == 'in_progress') ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF5C5CFF).withOpacity(0.15)),
                      ),
                      child: Column(
                        children: [
                          _buildTimingRow('Started', startedTimeStr, color: const Color(0xFF5C5CFF)),
                          const SizedBox(height: 8),
                          _buildTimingRow('Expected Finish', expectedFinishStr, color: const Color(0xFF5C5CFF)),
                          const SizedBox(height: 8),
                          _buildTimingRow('Elapsed', _formatDurationHM(baseElapsed), color: const Color(0xFF5C5CFF)),
                          const SizedBox(height: 8),
                          _buildTimingRow('Remaining', _formatDurationHM(remainingSeconds), color: const Color(0xFF5C5CFF)),
                          const SizedBox(height: 8),
                          _buildTimingRow('Current Progress', '$progress%', color: const Color(0xFF5C5CFF)),
                          const SizedBox(height: 8),
                          _buildTimingRow('Status', 'In Progress', color: const Color(0xFF5C5CFF)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Description Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DESCRIPTION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B7280),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          (data['description'] as String?)?.trim().isNotEmpty == true
                              ? data['description']
                              : 'No description provided for this task.',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF4B5563),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Progress Bar if In Progress
                  if (normStatus == 'in_progress') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Progress',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                        Text(
                          '$progress%',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF5C5CFF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: progress,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF5C5CFF),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 100 - progress > 0 ? 100 - progress : 0,
                            child: const SizedBox(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Realtime Comments Section
                  Text(
                    'Comments (${rawComments.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (rawComments.isNotEmpty)
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: rawComments.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final raw = rawComments[index];
                        final Map<String, dynamic> c = raw is Map<String, dynamic>
                            ? raw
                            : (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
                        final text = (c['text'] ?? c['content'] ?? '').toString();
                        final authorName = (c['authorName'] ?? c['userName'] ?? c['author'] ?? 'User').toString();
                        final initials = (c['authorInitials'] ?? c['initials'] ?? _getInitials(authorName)).toString();
                        final rawCreated = c['createdAt'];
                        String timeStr = '';
                        if (rawCreated is String) {
                          final dt = DateTime.tryParse(rawCreated);
                          if (dt != null) timeStr = DateFormat('MMM d, h:mm a').format(dt);
                        } else if (rawCreated is Timestamp) {
                          timeStr = DateFormat('MMM d, h:mm a').format(rawCreated.toDate());
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFF5C5CFF),
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                    bottomLeft: Radius.circular(16),
                                    topLeft: Radius.circular(4),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          authorName,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                        if (timeStr.isNotEmpty)
                                          Text(
                                            timeStr,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF9CA3AF),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      text,
                                      style: const TextStyle(
                                        color: Color(0xFF374151),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Bottom Input Bar & Primary Action Buttons
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Column(
              children: [
                // Comment Input Row
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF5C5CFF),
                      child: Text(
                        _getInitials(AppSession().userName ?? FirebaseAuth.instance.currentUser?.displayName ?? 'AH'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: TextField(
                          controller: _commentController,
                          decoration: const InputDecoration(
                            hintText: 'Add a comment...',
                            hintStyle: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: (val) {
                            if (docId != null) _submitComment(docId, val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFF5C5CFF),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        onPressed: () {
                          if (docId != null) _submitComment(docId, _commentController.text);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Primary Bottom Action Buttons according to status
                if (normStatus == 'assigned')
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (docId != null) {
                          await FirestoreService.updateTaskStatus(
                              FirestoreService.tasksCol.doc(docId), 'In Progress',
                              extra: {
                                'timerStart': FieldValue.serverTimestamp(),
                                'isPaused': false,
                              });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5C5CFF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Start Task',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  )
                else if (normStatus == 'in_progress')
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            if (docId != null) {
                              if (isPaused) {
                                await FirestoreService.resumeTask(FirestoreService.tasksCol.doc(docId));
                              } else {
                                await FirestoreService.pauseTask(FirestoreService.tasksCol.doc(docId));
                              }
                            }
                          },
                          child: Container(
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isPaused ? 'Resume' : 'Pause',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (docId != null) _showCompleteConfirmation(docId);
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
                  )
                else if (normStatus == 'overdue')
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            if (docId != null) {
                              await FirestoreService.updateTaskStatus(
                                  FirestoreService.tasksCol.doc(docId), 'In Progress',
                                  oldStatus: 'Overdue',
                                  extra: {
                                    'timerStart': FieldValue.serverTimestamp(),
                                    'isPaused': false,
                                  });
                            }
                          },
                          child: Container(
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF5C5CFF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Start Task',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (docId != null) _showCompleteConfirmation(docId);
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
                  )
                else if (normStatus == 'completed')
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (docId != null) _showArchiveConfirmation(docId);
                      },
                      icon: const Icon(Icons.insert_drive_file_outlined, color: Colors.white, size: 18),
                      label: const Text(
                        'Archive',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111827),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    String label = 'Assigned';
    Color bg = const Color(0xFFEEF2FF);
    Color fg = const Color(0xFF5C5CFF);

    if (status == 'in_progress') {
      label = 'In Progress';
      bg = const Color(0xFFEEF2FF);
      fg = const Color(0xFF5C5CFF);
    } else if (status == 'completed') {
      label = 'Completed';
      bg = const Color(0xFFECFDF5);
      fg = const Color(0xFF10B981);
    } else if (status == 'overdue') {
      label = 'Overdue';
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFEF4444);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6B7280),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  Widget _buildTimingRow(String label, String val, {required Color color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF4B5563)),
        ),
        Text(
          val,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
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

  Future<void> _submitComment(String docId, String val) async {
    final trimmed = val.trim();
    if (trimmed.isEmpty) return;
    try {
      _commentController.clear();
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
      await FirestoreService.tasksCol.doc(docId).update({
        'comments': FieldValue.arrayUnion([commentObj]),
      });
    } catch (e) {
      debugPrint('Error submitting comment: $e');
    }
  }

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
                        await FirestoreService.updateTaskStatus(
                            FirestoreService.tasksCol.doc(id), 'Done',
                            extra: {
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
                        await FirestoreService.updateTaskStatus(
                            FirestoreService.tasksCol.doc(id), 'Archived',
                            extra: {
                              'isArchived': true,
                              'archivedAt': FieldValue.serverTimestamp(),
                            });
                        if (mounted) Navigator.pop(context);
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

