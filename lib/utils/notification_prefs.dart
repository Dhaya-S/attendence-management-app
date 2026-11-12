import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

/// The user's notification switches (Settings → Notifications), stored live in
/// users/{email}/notifications/settings. Every place that shows or pops up a notification
/// checks [allows], so a switch takes effect immediately.
class NotificationPrefs {
  static const leave = 'leaveNotifications';
  static const attendance = 'attendanceAlerts';
  static const events = 'eventReminders';
  static const tasks = 'taskStatusUpdates';
  static const team = 'teamCommunication';

  static const allKeys = [leave, attendance, events, tasks, team];

  /// Documents inside the notifications collection that are NOT notifications.
  static bool isMetaDoc(String id) => id == 'settings' || id == 'security';

  final Map<String, bool> flags;
  const NotificationPrefs(this.flags);

  /// Everything on (the default).
  static NotificationPrefs get defaults => NotificationPrefs({for (final k in allKeys) k: true});

  factory NotificationPrefs.fromDoc(Map<String, dynamic>? d) {
    bool b(dynamic v) => v is bool ? v : true;
    return NotificationPrefs({
      leave: b(d?[leave]),
      attendance: b(d?[attendance]),
      events: b(d?[events]),
      tasks: b(d?[tasks]),
      // older versions called this "teamAnnouncements"
      team: d?[team] is bool ? d![team] as bool : b(d?['teamAnnouncements']),
    });
  }

  bool flag(String key) => flags[key] ?? true;

  /// Which switch a notification belongs to (null = always shown).
  static String? categoryOf(String type) {
    final t = type.toLowerCase();
    if (t.contains('leave')) return leave;
    if (t.contains('check') || t.contains('attendance') || t.contains('late') || t.contains('regulari') || t.contains('correction')) {
      return attendance;
    }
    if (t.contains('event') || t.contains('holiday') || t.contains('reminder') || t.contains('birthday') || t.contains('anniversary')) {
      return events;
    }
    if (t.contains('task')) return tasks;
    if (t.contains('announcement') || t.contains('policy') || t.contains('team') || t.contains('feed') ||
        t.contains('mention') || t.contains('comment') || t.contains('discussion')) {
      return team;
    }
    return null;
  }

  bool allows(String type) {
    final c = categoryOf(type);
    return c == null || flag(c);
  }

  static DocumentReference<Map<String, dynamic>> _doc(String email) =>
      FirestoreService.userNotificationsCol(email).doc('settings');

  /// Live preferences.
  static Stream<NotificationPrefs> stream(String email) {
    if (email.isEmpty) return Stream.value(defaults);
    return _doc(email).snapshots().map((s) => NotificationPrefs.fromDoc(s.data()));
  }

  static Future<NotificationPrefs> load(String email) async {
    if (email.isEmpty) return defaults;
    try {
      return NotificationPrefs.fromDoc((await _doc(email).get()).data());
    } catch (_) {
      return defaults;
    }
  }

  static Future<void> set(String email, Map<String, bool> changes) {
    return _doc(email).set({...changes, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }
}
