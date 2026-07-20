import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  StreamSubscription? _firestoreSubscription;
  StreamSubscription? _managerSubscription;

  bool _isInitialized = false;

  // Replace with your OneSignal App ID
  static const String _oneSignalAppId = "39b2a8cc-5e31-4df9-a025-cf855bf41a1a";

  Future<void> initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    // 1. Initialize OneSignal
    if (!kIsWeb) {
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      OneSignal.initialize(_oneSignalAppId);

      // Request push notification permission
      await OneSignal.Notifications.requestPermission(true);
    }

    // Request runtime permission for local notifications (Android 13+)
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // 2. Request FCM Permissions (Optional if using OneSignal, but kept for compatibility)
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. Initialize Local Notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification click if needed
      },
    );

    // 4. Create Android Channel
    const androidChannel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // 5. Handle FCM Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null) {
        _localNotifications.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              androidChannel.id,
              androidChannel.name,
              channelDescription: androidChannel.description,
              icon: android?.smallIcon,
            ),
          ),
        );
      }
    });

    _isInitialized = true;
    onUserLogin();
  }

  /// Sets up user-specific notification settings after login.
  void onUserLogin() {
    if (!_isInitialized) return;
    _updateToken();
    setupOneSignalUser();
    startFirestoreListener();
  }

  /// Sets the OneSignal external user ID to the user's email for targeted notifications.
  void setupOneSignalUser() {
    if (kIsWeb) return;
    final rawEmail = AppSession().email;
    final role = AppSession().role?.toLowerCase() ?? 'employee';
    final companyId = AppSession().companyId;
    
    if (rawEmail != null) {
      final sanitizedEmail = rawEmail.trim().toLowerCase();
      OneSignal.login(sanitizedEmail);
      OneSignal.User.addTagWithKey('role', role);
      if (companyId != null) {
        OneSignal.User.addTagWithKey('companyId', companyId);
      }
      debugPrint('OneSignal: Logged in user with email: $sanitizedEmail, role: $role, company: $companyId');
    }
  }

  /// Listens to Firestore notifications in real-time to show local alerts when the app is open.
  void startFirestoreListener() {
    final email = AppSession().email;
    if (email == null) return;

    _firestoreSubscription?.cancel();
    _managerSubscription?.cancel();
    _managerSubscription = null;
    
    final startTime = DateTime.now().subtract(const Duration(minutes: 1));

    // 1. Listen to personal notifications
    _firestoreSubscription = FirestoreService.userNotificationsCol(email)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>?;
          if (data != null) {
            final timestamp = data['timestamp'] as Timestamp?;
            // Accept the notification if it is a new write (null timestamp locally) or fresh
            if (timestamp == null || timestamp.toDate().isAfter(startTime)) {
              debugPrint('New personal notification received in Firestore: ${change.doc.id}');
              final title = data['title'] ?? 'Notification';
              final body = data['body'] ?? '';
              showNotification(title: title, body: body);
            }
          }
        }
      }
    }, onError: (e) {
      debugPrint('Firestore personal notifications listener error: $e');
    });

    // 2. IF MANAGER: Also listen to global notifications for the company
    if (AppSession().isManager) {
      _managerSubscription = FirestoreService.globalNotificationsCol
          .snapshots()
          .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data() as Map<String, dynamic>?;
            if (data != null) {
              final timestamp = data['timestamp'] as Timestamp?;
              // Accept the notification if it is a new write (null timestamp locally) or fresh
              if (timestamp == null || timestamp.toDate().isAfter(startTime)) {
                debugPrint('New global notification received in Firestore: ${change.doc.id}');
                final title = data['title'] ?? 'Manager Alert';
                final body = data['body'] ?? 'New request received.';
                showNotification(title: title, body: body);
              }
            }
          }
        }
      }, onError: (e) {
        debugPrint('Firestore manager global notifications listener error: $e');
      });
    }
  }

  void stopFirestoreListener() {
    _firestoreSubscription?.cancel();
    _firestoreSubscription = null;
    _managerSubscription?.cancel();
    _managerSubscription = null;
    if (!kIsWeb) {
      OneSignal.logout();
    }
  }

  Future<void> _updateToken() async {
    try {
      String? token = await _fcm.getToken();
      if (token != null && AppSession().email != null) {
        final q = await FirestoreService.usersCol.where('email', isEqualTo: AppSession().email).limit(1).get();
        if (q.docs.isNotEmpty) {
          await q.docs.first.reference.update({
            'fcmToken': token,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to update FCM token: $e');
    }
  }

  Future<void> scheduleCheckoutReminder(DateTime shiftEndTime) async {
    if (shiftEndTime.isBefore(DateTime.now())) return;

    const androidDetails = AndroidNotificationDetails(
      'checkout_reminder',
      'Checkout Reminders',
      channelDescription: 'Reminds you to check out at the end of your shift.',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    await _localNotifications.zonedSchedule(
      id: 999,
      title: 'Shift Ending Soon â°',
      body: 'Don\'t forget to check out! Your shift ends at ${DateFormat('hh:mm a').format(shiftEndTime)}.',
      scheduledDate: tz.TZDateTime.from(shiftEndTime, tz.local),
      notificationDetails: NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelCheckoutReminder() async {
    await _localNotifications.cancel(id: 999);
  }

  Future<void> showNotification({required String title, required String body}) async {
    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    await _localNotifications.show(
      id: DateTime.now().millisecond, 
      title: title, 
      body: body, 
      notificationDetails: notificationDetails,
    );
  }
}
