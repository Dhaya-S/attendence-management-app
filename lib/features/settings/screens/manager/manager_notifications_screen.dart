import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/features/leave_management/screens/manager/leave_approval_screen.dart';
import 'package:attendance_app/features/attendance/screens/manager/late_adjustment_review_screen.dart';

class ManagerNotificationsScreen extends StatefulWidget {
  const ManagerNotificationsScreen({super.key});

  @override
  State<ManagerNotificationsScreen> createState() =>
      _ManagerNotificationsScreenState();
}

class _ManagerNotificationsScreenState
    extends State<ManagerNotificationsScreen> {
  String _selectedTab = 'All';
  final _tabs = ['All', 'Leave Requests', 'Adjustments', 'System'];

  @override
  void initState() {
    super.initState();
    _markSystemNotificationsAsRead();
  }

  Future<void> _markSystemNotificationsAsRead() async {
    try {
      final unread = await FirestoreService.globalNotificationsCol
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
      debugPrint('Error marking system notifications as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary, size: 18),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text('Notifications',
            style: AppTheme.h1.copyWith(fontSize: 18)),
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _tabs.map((t) {
                  final isActive = _selectedTab == t;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppTheme.primarySurface
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                isActive ? AppTheme.primary : AppTheme.divider,
                            width: isActive ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          t,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isActive ? FontWeight.w700 : FontWeight.w500,
                            color: isActive
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
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
            child: _selectedTab == 'Adjustments'
                ? _buildAdjustmentsList()
                : _selectedTab == 'System'
                    ? _buildSystemNotificationsList()
                    : _buildLeaveAndAdjustmentsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemNotificationsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.globalNotificationsCol
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildEmptyState('Error loading system notifications');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return _buildEmptyState('No system notifications');
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _buildSystemNotifItem(data);
          },
        );
      },
    );
  }

  Widget _buildSystemNotifItem(Map<String, dynamic> data) {
    final title = data['title'] ?? 'System Notification';
    final body = data['body'] ?? '';
    final timestamp = data['timestamp'] as Timestamp?;
    final timeStr = _formatTime(timestamp);
    final type = data['type'] ?? 'system';

    IconData icon = Icons.info_outline;
    Color iconColor = AppTheme.primary;
    Color iconBg = AppTheme.primarySurface;

    if (type == 'new_leave_request') {
      icon = Icons.event_note_rounded;
      iconColor = AppTheme.warning;
      iconBg = AppTheme.warningLight;
    } else if (type == 'leave_applied' || type == 'wfh_applied') {
      icon = Icons.calendar_today_rounded;
      iconColor = AppTheme.info;
      iconBg = AppTheme.info.withOpacity(0.1);
    }

    return _notificationItem(
      icon: icon,
      iconBg: iconBg,
      iconColor: iconColor,
      title: title,
      time: timeStr,
      content: body,
      actionText: type == 'new_leave_request' ? 'View Requests' : null,
      onAction: type == 'new_leave_request' ? () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveApprovalScreen()));
      } : null,
    );
  }

  // Combined list for "All" and "Leave Requests" tabs
  Widget _buildLeaveAndAdjustmentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.companyLeaveRequestsQuery.snapshots(),
      builder: (context, leaveSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirestoreService.allAttendanceRecordsCol
              .where('isAdjustmentRequest', isEqualTo: true)
              .where('remarkStatus', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, adjustSnap) {
            if (leaveSnap.hasError || adjustSnap.hasError) {
              debugPrint('Notification Stream Error: L:${leaveSnap.error} A:${adjustSnap.error}');
            }

            final leaveDocs = leaveSnap.data?.docs ?? [];
            final adjustDocs = adjustSnap.data?.docs ?? [];

            // Build a combined list of notification items
            List<_NotifItem> items = [];

            // Add leave items
            if (_selectedTab == 'All' || _selectedTab == 'Leave Requests') {
              for (var doc in leaveDocs) {
                final data = doc.data() as Map<String, dynamic>;
                final appliedAt = (data['requestDate'] ?? data['appliedAt']) as Timestamp?;
                
                // Only show pending items for clarity (they disappear once reviewed)
                if (data['status'] != 'pending') continue;

                items.add(_NotifItem(
                  type: 'leave',
                  data: data,
                  doc: doc,
                  timestamp: appliedAt,
                ));
              }
            }

            // Add adjustment items
            if (_selectedTab == 'All' || _selectedTab == 'Adjustments') {
              for (var doc in adjustDocs) {
                final data = doc.data() as Map<String, dynamic>;
                // Adjustment items are already filtered by query (pending only)
                if (data['isAdjustmentRequest'] != true) continue;
                
                final requestTime = data['requestTime'] as Timestamp?;
                
                // Only show pending items for clarity (they disappear once reviewed)
                if (data['isAdjustmentRequest'] != true) continue;

                items.add(_NotifItem(
                  type: 'adjustment',
                  data: data,
                  doc: doc,
                  timestamp: requestTime,
                ));
              }
            }

            // Sort by timestamp descending
            items.sort((a, b) {
              final aTime = a.timestamp?.toDate() ?? DateTime.now();
              final bTime = b.timestamp?.toDate() ?? DateTime.now();
              return bTime.compareTo(aTime);
            });

            if (items.isEmpty) {
              return _buildEmptyState('No notifications yet');
            }

            return ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                if (item.type == 'leave') {
                  return _buildLeaveNotif(item.data, item.doc);
                } else {
                  return _buildAdjustmentNotif(item.data, item.doc);
                }
              },
            );
          },
        );
      },
    );
  }

  // Dedicated adjustments list
  Widget _buildAdjustmentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.allAttendanceRecordsCol
          .where('isAdjustmentRequest', isEqualTo: true)
          .where('remarkStatus', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['remarkStatus'] == 'pending' && data['isAdjustmentRequest'] == true;
        }).toList();

        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = (aData['requestTime'] as Timestamp?)?.toDate() ?? DateTime.now();
          final bTime = (bData['requestTime'] as Timestamp?)?.toDate() ?? DateTime.now();
          return bTime.compareTo(aTime);
        });

        if (docs.isEmpty) {
          return _buildEmptyState('No adjustment requests');
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _buildAdjustmentNotif(data, docs[index]);
          },
        );
      },
    );
  }

  Widget _buildLeaveNotif(Map<String, dynamic> data, QueryDocumentSnapshot doc) {
    final userId = data['userId'] as String?;
    final reason = data['reason'] ?? 'Leave';
    final status = data['status'] ?? 'pending';
    final Timestamp? appliedAt = data['appliedAt'];
    final timeStr = _formatTime(appliedAt);

    Widget buildItemWithName(String name) {
      if (status == 'pending') {
        return _notificationItem(
          icon: Icons.event_note_rounded,
          iconBg: AppTheme.primarySurface,
          iconColor: AppTheme.primary,
          title: 'Leave Request: $name',
          time: timeStr,
          content: '$name requested leave for $reason.',
          badgeText: 'PENDING',
          badgeColor: AppTheme.warning,
          badgeBg: AppTheme.warningLight,
          actionText: 'Review',
          onAction: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LeaveApprovalScreen()));
          },
        );
      } else if (status == 'approved') {
        return _notificationItem(
          icon: Icons.check_circle_rounded,
          iconBg: AppTheme.successLight,
          iconColor: AppTheme.success,
          title: 'Leave Approved',
          time: timeStr,
          content: '$name\'s leave request has been approved.',
        );
      } else {
        return _notificationItem(
          icon: Icons.cancel_rounded,
          iconBg: AppTheme.dangerLight,
          iconColor: AppTheme.danger,
          title: 'Leave Rejected',
          time: timeStr,
          content: '$name\'s leave request was rejected.',
        );
      }
    }

    // Try name from record first
    final storedName = data['userName'] as String?;
    if (storedName != null && storedName != 'Employee' && storedName.isNotEmpty) {
      return buildItemWithName(storedName);
    }

    // Fallback: fetch name from users collection
    if (userId == null) return buildItemWithName('Employee');

    return FutureBuilder<QuerySnapshot>(
      future: FirestoreService.usersCol.where('uid', isEqualTo: userId).limit(1).get(),
      builder: (context, snapshot) {
        String name = 'Employee';
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          name = (snapshot.data!.docs.first.data() as Map<String, dynamic>)['name'] ?? name;
        }
        return buildItemWithName(name);
      },
    );
  }

  Widget _buildAdjustmentNotif(Map<String, dynamic> data, QueryDocumentSnapshot doc) {
    // Extract userId and recordDate from fields OR path fallback
    String? userId = data['userId'] as String?;
    String? recordDate = data['recordDate'] as String?;

    // Path analysis: approved_companies/{cid}/attendance/{userId}/records/{date}
    final pathParts = doc.reference.path.split('/');
    // Try to find 'attendance' segment and extract userId from the next part
    final attIdx = pathParts.indexOf('attendance');
    if (userId == null && attIdx >= 0 && attIdx + 1 < pathParts.length) {
      userId = pathParts[attIdx + 1];
    }
    final recIdx = pathParts.indexOf('records');
    if ((recordDate == null || recordDate.isEmpty) && recIdx >= 0 && recIdx + 1 < pathParts.length) {
      recordDate = pathParts[recIdx + 1];
    }

    final remark = data['remark'] ?? '';
    final remarkStatus = data['remarkStatus'] ?? 'pending';
    final Timestamp? requestTime = data['requestTime'];
    final timeStr = _formatTime(requestTime);

    // Helper widget to build the actual notification once we have the name
    Widget buildItemWithName(String name) {
      if (remarkStatus == 'pending') {
        return _notificationItem(
          icon: Icons.schedule_rounded,
          iconBg: const Color(0xFFFFF3E0),
          iconColor: AppTheme.warning,
          title: 'Adjustment: $name',
          time: timeStr,
          content: 'Check-in adjustment for ${recordDate ?? "Unknown Date"}.\nReason: "$remark"',
          badgeText: 'PENDING',
          badgeColor: AppTheme.warning,
          badgeBg: AppTheme.warningLight,
          actionText: 'Review',
          onAction: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const LateAdjustmentReviewScreen()));
          },
        );
      } else if (remarkStatus == 'approved') {
        return _notificationItem(
          icon: Icons.check_circle_rounded,
          iconBg: AppTheme.successLight,
          iconColor: AppTheme.success,
          title: 'Adjustment Approved',
          time: timeStr,
          content: '$name\'s check-in adjustment for $recordDate was approved.',
        );
      } else {
        return _notificationItem(
          icon: Icons.cancel_rounded,
          iconBg: AppTheme.dangerLight,
          iconColor: AppTheme.danger,
          title: 'Adjustment Denied',
          time: timeStr,
          content: '$name\'s check-in adjustment for $recordDate was denied.',
        );
      }
    }

    // Try name from record first
    final storedName = data['userName'] as String?;
    if (storedName != null && storedName != 'Employee' && storedName.isNotEmpty) {
      return buildItemWithName(storedName);
    }

    // Fallback: fetch name from users collection if record is missing it
    if (userId == null) return buildItemWithName('Employee');

    return FutureBuilder<QuerySnapshot>(
      future: FirestoreService.usersCol.where('uid', isEqualTo: userId).limit(1).get(),
      builder: (context, snapshot) {
        String name = 'Employee';
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          name = (snapshot.data!.docs.first.data() as Map<String, dynamic>)['name'] ?? name;
        }
        return buildItemWithName(name);
      },
    );
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays == 1) return 'Yesterday';
    return DateFormat('MMM dd').format(ts.toDate());
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded,
              size: 64, color: AppTheme.textHint.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }


  Widget _notificationItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String time,
    required String content,
    String? badgeText,
    Color? badgeColor,
    Color? badgeBg,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
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
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textHint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (badgeText != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: badgeColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (actionText != null && onAction != null)
                        GestureDetector(
                          onTap: onAction,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              actionText,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifItem {
  final String type; // 'leave' or 'adjustment'
  final Map<String, dynamic> data;
  final QueryDocumentSnapshot doc;
  final Timestamp? timestamp;

  _NotifItem({
    required this.type,
    required this.data,
    required this.doc,
    this.timestamp,
  });
}
