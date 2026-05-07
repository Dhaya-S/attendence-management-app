import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/features/settings/screens/manager/manager_notifications_screen.dart';
import 'package:attendance_app/screens/employee/notifications_screen.dart';
import 'package:attendance_app/utils/firestore_service.dart';

class NotificationAction extends StatelessWidget {
  final bool isManager;
  final Color? iconColor;
  final Color? backgroundColor;

  const NotificationAction({
    super.key,
    this.isManager = true,
    this.iconColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (isManager) {
      return _buildManagerNotification(context);
    } else {
      return _buildEmployeeNotification(context);
    }
  }

  Widget _buildManagerNotification(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.companyLeaveRequestsQuery
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, leaveSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirestoreService.allAttendanceRecordsCol
              .where('remarkStatus', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, adjustSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirestoreService.globalNotificationsCol
                  .where('isRead', isEqualTo: false)
                  .snapshots(),
              builder: (context, systemSnap) {
                final leaveCount = (leaveSnap.hasData && leaveSnap.data != null) ? leaveSnap.data!.docs.length : 0;
                final adjustCount = (adjustSnap.hasData && adjustSnap.data != null) ? adjustSnap.data!.docs.length : 0;
                final systemCount = (systemSnap.hasData && systemSnap.data != null) ? systemSnap.data!.docs.length : 0;
                final total = leaveCount + adjustCount + systemCount;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 16),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: backgroundColor ?? AppTheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.notifications_outlined,
                          color: iconColor ?? AppTheme.textSecondary,
                          size: 22,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ManagerNotificationsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    if (total > 0)
                      Positioned(
                        right: 12,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppTheme.danger,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            total > 9 ? '9+' : '$total',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmployeeNotification(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.userNotificationsCol(user.email ?? '')
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: backgroundColor ?? Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  )
                ],
              ),
              child: IconButton(
                icon: Icon(
                  Icons.notifications_none_rounded,
                  color: iconColor ?? AppTheme.textPrimary,
                  size: 22,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EmployeeNotificationsScreen(),
                    ),
                  );
                },
              ),
            ),
            if (count > 0)
              Positioned(
                right: 12,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppTheme.danger,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
