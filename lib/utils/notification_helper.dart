import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/onesignal_helper.dart';

class NotificationHelper {
  /// Sends a notification to a specific employee
  static Future<void> notifyEmployee({
    required String employeeEmail,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final notificationData = {
        'companyId': FirestoreService.companyId,
        'title': title,
        'body': body,
        'type': type,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        if (extraData != null) ...extraData,
      };

      // 1. Store in Firestore for in-app history
      try {
        await FirestoreService.userNotificationsCol(employeeEmail).add(notificationData);
      } catch (e) {
        print('Firestore user notification write error (ignoring to prevent app crash): $e');
      }

      // 2. Trigger OneSignal Push Notification for background delivery
      try {
        await OneSignalHelper.sendPushNotification(
          playerEmail: employeeEmail,
          title: title,
          content: body,
          additionalData: {
            'type': type,
            if (extraData != null) ...extraData,
          },
        );
      } catch (e) {
        print('OneSignal user push send error (ignoring to prevent app crash): $e');
      }
    } catch (e) {
      print('General error in notifyEmployee: $e');
    }
  }

  static Future<List<String>> _getManagerEmails(String companyId) async {
    final List<String> emails = [];
    
    // 1. Fetch primary manager email from the company profile
    try {
      final companySnap = await FirestoreService.companyDoc(companyId).get();
      if (companySnap.exists && companySnap.data() != null) {
        final primaryEmail = companySnap.data()?['managerEmail'] as String?;
        if (primaryEmail != null && primaryEmail.isNotEmpty) {
          final sanitized = primaryEmail.trim().toLowerCase();
          if (!emails.contains(sanitized)) {
            emails.add(sanitized);
          }
        }
      }
    } catch (e) {
      print('Warning: Failed to fetch primary manager email from company doc: $e');
    }

    // 2. Query company users subcollection for any users with role == 'manager'
    try {
      final companyManagersSnap = await FirestoreService.companyDoc(companyId)
          .collection('users')
          .where('role', isEqualTo: 'manager')
          .get();
      for (var doc in companyManagersSnap.docs) {
        final email = (doc.data()['email'] as String? ?? doc.id).trim().toLowerCase();
        if (email.isNotEmpty && !emails.contains(email)) {
          emails.add(email);
        }
      }
    } catch (e) {
      print('Warning: Failed to fetch managers from company users subcollection: $e');
    }

    // 3. Query approved_users global collection (best effort, might fail due to security rules)
    try {
      final managersSnap = await FirebaseFirestore.instance
          .collection('approved_users')
          .where('companyId', isEqualTo: companyId)
          .where('role', isEqualTo: 'manager')
          .get();

      for (var doc in managersSnap.docs) {
        final email = doc.id.trim().toLowerCase();
        if (email.isNotEmpty && !emails.contains(email)) {
          emails.add(email);
        }
      }
    } catch (e) {
      print('Warning: Failed to query approved_users for managers (expected for employees): $e');
    }

    print('Resolved manager emails for push: $emails');
    return emails;
  }

  /// Sends a notification to the manager(s) of the company
  static Future<void> notifyManager({
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final companyId = FirestoreService.companyId;
      final notificationData = {
        'companyId': companyId,
        'title': title,
        'body': body,
        'type': type,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'fromEmail': AppSession().email,
        'fromName': AppSession().userName,
        if (extraData != null) ...extraData,
      };

      // 1. Store in Firestore
      try {
        await FirestoreService.globalNotificationsCol.add(notificationData);
      } catch (e) {
        print('Firestore global notification write error (ignoring to prevent app crash): $e');
      }

      // 2. Fetch manager emails and send push notifications directly to their external_ids
      try {
        final managerEmails = await _getManagerEmails(companyId);
        for (var managerEmail in managerEmails) {
          try {
            await OneSignalHelper.sendPushNotification(
              playerEmail: managerEmail,
              title: title,
              content: body,
              additionalData: {
                'type': type,
                'fromEmail': AppSession().email,
                if (extraData != null) ...extraData,
              },
            );
          } catch (e) {
            print('OneSignal manager push send error for $managerEmail (ignoring): $e');
          }
        }
      } catch (e) {
        print('Error resolving/sending manager push notifications: $e');
      }
    } catch (e) {
      print('General error in notifyManager: $e');
    }
  }

  static Future<List<String>> _getAdminEmails(String companyId) async {
    final List<String> emails = [];
    try {
      final companyAdminsSnap = await FirestoreService.companyDoc(companyId)
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();
      for (var doc in companyAdminsSnap.docs) {
        final email = (doc.data()['email'] as String? ?? doc.id).trim().toLowerCase();
        if (email.isNotEmpty && !emails.contains(email)) {
          emails.add(email);
        }
      }
    } catch (e) {
      print('Warning: Failed to fetch admins from company users subcollection: $e');
    }

    try {
      final adminsSnap = await FirebaseFirestore.instance
          .collection('approved_users')
          .where('companyId', isEqualTo: companyId)
          .where('role', isEqualTo: 'admin')
          .get();
      for (var doc in adminsSnap.docs) {
        final email = doc.id.trim().toLowerCase();
        if (email.isNotEmpty && !emails.contains(email)) {
          emails.add(email);
        }
      }
    } catch (e) {
      print('Warning: Failed to query approved_users for admins: $e');
    }
    return emails;
  }

  /// Sends a notification to the admin(s) of the company
  static Future<void> notifyAdmin({
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final companyId = FirestoreService.companyId;
      final notificationData = {
        'companyId': companyId,
        'title': title,
        'body': body,
        'type': type,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'fromEmail': AppSession().email,
        'fromName': AppSession().userName,
        if (extraData != null) ...extraData,
      };

      try {
        await FirestoreService.globalNotificationsCol.add(notificationData);
      } catch (e) {
        print('Firestore global notification write error (ignoring to prevent app crash): $e');
      }

      try {
        final adminEmails = await _getAdminEmails(companyId);
        for (var adminEmail in adminEmails) {
          try {
            await OneSignalHelper.sendPushNotification(
              playerEmail: adminEmail,
              title: title,
              content: body,
              additionalData: {
                'type': type,
                'fromEmail': AppSession().email,
                if (extraData != null) ...extraData,
              },
            );
          } catch (e) {
            print('OneSignal admin push send error for $adminEmail (ignoring): $e');
          }
        }
      } catch (e) {
        print('Error resolving/sending admin push notifications: $e');
      }
    } catch (e) {
      print('General error in notifyAdmin: $e');
    }
  }

  /// Sends a notification to all employees in the company
  static Future<void> notifyAllEmployees({
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      // 1. Fetch all employees in the company
      final usersSnapshot = await FirestoreService.companyUsersQuery.get();
      
      final batch = FirebaseFirestore.instance.batch();
      final notificationData = {
        'companyId': FirestoreService.companyId,
        'title': title,
        'body': body,
        'type': type,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'fromEmail': AppSession().email,
        'fromName': AppSession().userName,
        if (extraData != null) ...extraData,
      };

      for (var doc in usersSnapshot.docs) {
        final email = doc.id; // Document ID is email.toLowerCase()
        final userNotifRef = FirestoreService.userNotificationsCol(email).doc();
        batch.set(userNotifRef, notificationData);
      }

      // Commit the batch write to all employees' personal collections
      await batch.commit();

      // 2. Trigger OneSignal Push notification to all employees
      await OneSignalHelper.sendPushToAllEmployees(
        title: title,
        content: body,
        additionalData: {
          'type': type,
          'fromEmail': AppSession().email,
          if (extraData != null) ...extraData,
        },
      );
    } catch (e) {
      print('Error sending notifications to all employees: $e');
    }
  }
}
