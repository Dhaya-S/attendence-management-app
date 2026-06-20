import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'firestore_service.dart';

class OneSignalHelper {
  static const String _appId = "39b2a8cc-5e31-4df9-a025-cf855bf41a1a";
  static const String _restApiKey = String.fromEnvironment('ONESIGNAL_REST_API_KEY', defaultValue: '');

  /// Sends a push notification to a specific user via their email (external_id)
  static Future<void> sendPushNotification({
    required String playerEmail,
    required String title,
    required String content,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $_restApiKey',
        },
        body: jsonEncode({
          'app_id': _appId,
          'include_external_user_ids': [playerEmail],
          'headings': {'en': title},
          'contents': {'en': content},
          'data': additionalData ?? {},
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('OneSignal: Push notification sent successfully to $playerEmail');
      } else {
        debugPrint('OneSignal: Failed to send push notification. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      debugPrint('OneSignal: Error sending push notification: $e');
    }
  }

  /// Sends a push notification to all managers (using a specific tag or segment)
  static Future<void> sendPushToManagers({
    required String title,
    required String content,
    Map<String, dynamic>? additionalData,
  }) async {
    // In a real app, you might want to tag managers in OneSignal
    // For now, if we don't have a list of manager emails, we could use filters
    try {
      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $_restApiKey',
        },
        body: jsonEncode({
          'app_id': _appId,
          'filters': [
            {'field': 'tag', 'key': 'role', 'relation': '=', 'value': 'manager'},
            {'operator': 'AND'},
            {'field': 'tag', 'key': 'companyId', 'relation': '=', 'value': FirestoreService.companyId}
          ],
          'headings': {'en': title},
          'contents': {'en': content},
          'data': additionalData ?? {},
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('OneSignal: Push notification sent successfully to managers');
      } else {
        debugPrint('OneSignal: Failed to send push to managers. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      debugPrint('OneSignal: Error sending push to managers: $e');
    }
  }

  /// Sends a push notification to all employees of the company
  static Future<void> sendPushToAllEmployees({
    required String title,
    required String content,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $_restApiKey',
        },
        body: jsonEncode({
          'app_id': _appId,
          'filters': [
            {'field': 'tag', 'key': 'role', 'relation': '=', 'value': 'employee'},
            {'operator': 'AND'},
            {'field': 'tag', 'key': 'companyId', 'relation': '=', 'value': FirestoreService.companyId}
          ],
          'headings': {'en': title},
          'contents': {'en': content},
          'data': additionalData ?? {},
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('OneSignal: Push notification sent successfully to all employees');
      } else {
        debugPrint('OneSignal: Failed to send push to employees. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      debugPrint('OneSignal: Error sending push to employees: $e');
    }
  }
}
