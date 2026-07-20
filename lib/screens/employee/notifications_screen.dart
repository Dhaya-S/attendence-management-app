import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import '../../theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';

import 'package:attendance_app/screens/employee/attendance_history_screen.dart';
import 'package:attendance_app/screens/employee/leave_tab.dart';

class EmployeeNotificationsScreen extends StatefulWidget {
  const EmployeeNotificationsScreen({super.key});

  @override
  State<EmployeeNotificationsScreen> createState() => _EmployeeNotificationsScreenState();
}

class _EmployeeNotificationsScreenState extends State<EmployeeNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    _markAllAsRead();
  }

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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 18),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text('Notifications', style: AppTheme.h3),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.userNotificationsCol(user?.email ?? '')
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text('Error: ${snapshot.error}\n\nNote: This may require a Firestore Index. Check your Firebase console.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.danger, fontSize: 10)),
            ));
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          // Make it a modifiable list for sorting
          final docs = snapshot.data!.docs.toList();
          
          // Sort by timestamp descending in memory
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = (aData['timestamp'] as Timestamp? ?? aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final bTime = (bData['timestamp'] as Timestamp? ?? bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            return bTime.compareTo(aTime);
          });

          if (docs.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => await Future.delayed(const Duration(milliseconds: 800)),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none_rounded, size: 64, color: AppTheme.textHint),
                        const SizedBox(height: 16),
                        Text('No notifications yet', style: AppTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => await Future.delayed(const Duration(milliseconds: 800)),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                return FadeInUp(
                  duration: Duration(milliseconds: 300 + (index * 50)),
                  child: _notificationCard(context, data),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _notificationCard(BuildContext context, Map<String, dynamic> data) {
    final title = data['title'] ?? 'Notification';
    final body = data['body'] ?? data['message'] ?? '';
    final type = data['type'] ?? 'info';
    final timestamp = (data['timestamp'] as Timestamp? ?? data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    IconData icon;
    Color color;
    switch (type) {
      case 'check_in':
        icon = Icons.login_rounded;
        color = AppTheme.success;
        break;
      case 'check_out':
        icon = Icons.logout_rounded;
        color = AppTheme.primary;
        break;
      case 'leave_approved':
      case 'leave_rejected':
      case 'adjustment_approved':
      case 'attendance_corrected':
        icon = Icons.check_circle_rounded;
        color = AppTheme.success;
        break;
      case 'adjustment_denied':
        icon = Icons.cancel_rounded;
        color = AppTheme.danger;
        break;
      default:
        icon = Icons.notifications_rounded;
        color = AppTheme.primary;
    }

    return GestureDetector(
      onTap: () {
        if (type == 'leave_approved' || type == 'leave_rejected') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeLeaveTab()));
        } else if (type == 'check_in' || type == 'check_out' || type == 'adjustment_approved' || type == 'adjustment_denied' || type == 'attendance_corrected') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen()));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.05), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary))),
                      Text(DateFormat('hh:mm a').format(timestamp), style: AppTheme.label.copyWith(fontSize: 9)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(body, style: AppTheme.label.copyWith(fontSize: 10, color: AppTheme.textHint)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
