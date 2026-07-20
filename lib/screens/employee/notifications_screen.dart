import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animate_do/animate_do.dart';
import 'package:attendance_app/utils/firestore_service.dart';

import 'package:attendance_app/screens/employee/attendance_history_screen.dart';
import 'package:attendance_app/screens/employee/leave_tab.dart';

class EmployeeNotificationsScreen extends StatefulWidget {
  const EmployeeNotificationsScreen({super.key});

  @override
  State<EmployeeNotificationsScreen> createState() => _EmployeeNotificationsScreenState();
}

class _EmployeeNotificationsScreenState extends State<EmployeeNotificationsScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Attendance', 'Leave', 'Tasks', 'Team', 'Announcements'];

  Future<void> _markAllAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final unread = await FirestoreService.userNotificationsCol(user.email ?? '')
          .where('isRead', isEqualTo: false)
          .get();
      if (unread.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in unread.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error marking notifications as read: $e');
    }
  }

  Future<void> _clearAll() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final allDocs = await FirestoreService.userNotificationsCol(user.email ?? '').get();
      if (allDocs.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in allDocs.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
    }
  }

  String _timeAgo(DateTime d) {
    Duration diff = DateTime.now().difference(d);
    if (diff.inDays > 365) return "${(diff.inDays / 365).floor()} ${(diff.inDays / 365).floor() == 1 ? "year" : "years"} ago";
    if (diff.inDays > 30) return "${(diff.inDays / 30).floor()} ${(diff.inDays / 30).floor() == 1 ? "month" : "months"} ago";
    if (diff.inDays > 7) return "${(diff.inDays / 7).floor()} ${(diff.inDays / 7).floor() == 1 ? "week" : "weeks"} ago";
    if (diff.inDays > 0) {
      if (diff.inDays == 1) return "Yesterday";
      return "${diff.inDays} days ago";
    }
    if (diff.inHours > 0) return "${diff.inHours} ${diff.inHours == 1 ? "hour" : "hours"} ago";
    if (diff.inMinutes > 0) return "${diff.inMinutes} ${diff.inMinutes == 1 ? "min" : "min"} ago";
    return "Just now";
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
        title: const Text('Notifications', style: TextStyle(color: Color(0xFF111827), fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text('Read all', style: TextStyle(color: Color(0xFF4F46E5), fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: _clearAll,
            child: const Text('Clear', style: TextStyle(color: Color(0xFFDC2626), fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = filter == _selectedFilter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedFilter = filter),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF4B5563),
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirestoreService.userNotificationsCol(user?.email ?? '').limit(50).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
                
                var docs = snapshot.data!.docs.toList();
                
                // Filter
                if (_selectedFilter != 'All') {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final type = (data['type'] ?? '').toString().toLowerCase();
                    final filter = _selectedFilter.toLowerCase();
                    if (filter == 'attendance' && (type.contains('check') || type.contains('attendance'))) return true;
                    if (filter == 'leave' && type.contains('leave')) return true;
                    if (filter == 'tasks' && type.contains('task')) return true;
                    if (filter == 'team' && (type.contains('team') || type.contains('birthday'))) return true;
                    if (filter == 'announcements' && (type.contains('announcement') || type.contains('policy'))) return true;
                    return false; 
                  }).toList();
                }

                docs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = (aData['timestamp'] as Timestamp? ?? aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                  final bTime = (bData['timestamp'] as Timestamp? ?? bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                  return bTime.compareTo(aTime);
                });

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none_rounded, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text('No notifications', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE5E7EB), indent: 70),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return FadeInUp(
                      duration: Duration(milliseconds: 300 + (index * 50)),
                      child: _notificationCard(context, doc.id, data),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _notificationCard(BuildContext context, String docId, Map<String, dynamic> data) {
    final title = data['title'] ?? 'Notification';
    final body = data['body'] ?? data['message'] ?? '';
    final type = (data['type'] ?? 'info').toString();
    final timestamp = (data['timestamp'] as Timestamp? ?? data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final isRead = data['isRead'] ?? false;

    IconData icon;
    Color iconColor;
    Color iconBg;
    String categoryLabel;

    if (type.contains('leave')) {
      icon = Icons.calendar_today_outlined;
      iconColor = const Color(0xFF6366F1); 
      iconBg = const Color(0xFFEEF2FF);
      categoryLabel = 'Leave';
      if (type.contains('approved')) categoryLabel += ' · Approved';
      if (type.contains('rejected')) categoryLabel += ' · Rejected';
    } else if (type.contains('check') || type.contains('attendance')) {
      icon = Icons.access_time;
      iconColor = const Color(0xFFD97706); 
      iconBg = const Color(0xFFFFFBEB);
      categoryLabel = 'Attendance';
      if (type.contains('correction') || type.contains('missing')) categoryLabel += ' · Correction';
    } else if (type.contains('task')) {
      icon = Icons.assignment_outlined;
      iconColor = const Color(0xFF8B5CF6); 
      iconBg = const Color(0xFFF5F3FF);
      categoryLabel = 'Tasks';
    } else if (type.contains('announcement') || type.contains('policy')) {
      icon = Icons.notifications_none;
      iconColor = const Color(0xFF3B82F6); 
      iconBg = const Color(0xFFEFF6FF);
      categoryLabel = 'Announcements';
      if (type.contains('manager')) categoryLabel += ' · Manager';
    } else if (type.contains('birthday') || type.contains('team')) {
      icon = Icons.people_outline;
      iconColor = const Color(0xFF10B981); 
      iconBg = const Color(0xFFECFDF5);
      categoryLabel = 'Announcements · Birthdays';
    } else if (type.contains('mention') || type.contains('feed')) {
      icon = Icons.chat_bubble_outline;
      iconColor = const Color(0xFFD946EF); 
      iconBg = const Color(0xFFFDF4FF);
      categoryLabel = 'Feed';
    } else {
      icon = Icons.notifications_none;
      iconColor = const Color(0xFF6B7280);
      iconBg = const Color(0xFFF3F4F6);
      categoryLabel = 'Update';
    }

    return GestureDetector(
      onTap: () {
        if (!isRead) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            FirestoreService.userNotificationsCol(user.email ?? '').doc(docId).update({'isRead': true});
          }
        }
        
        if (type.contains('leave')) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeLeaveTab()));
        } else if (type.contains('check') || type.contains('attendance')) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen()));
        }
      },
      child: Container(
        color: isRead ? Colors.white : const Color(0xFFF0F4FF),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827)),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _timeAgo(timestamp),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                      ),
                      Row(
                        children: [
                          Text(
                            categoryLabel,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5)),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, size: 14, color: Color(0xFF4F46E5)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
