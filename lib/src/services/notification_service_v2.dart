import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  // Replace with your actual Firebase project region and project ID
  static const String _baseUrl =
      "https://us-central1-student-reminder-xx-16738.cloudfunctions.net";

  static NotificationService? _instance;
  static NotificationService get instance =>
      _instance ??= NotificationService._();
  NotificationService._();

  /// Send push notification using Cloud Functions
  static Future<bool> sendPushNotificationv2({
    required String deviceToken,
    required String title,
    required String body,
  }) async {
    final url = Uri.parse("$_baseUrl/sendPushNotification");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "title": title,
          "body": body,
          "deviceToken": deviceToken,
        }),
      );

      if (response.statusCode == 200) {
        print("✅ Notification sent: ${response.body}");
        return true;
      } else {
        print("⚠️ Failed: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      print("❌ Error sending push notification: $e");
      return false;
    }
  }

  /// Send notification to a topic using Cloud Functions
  static Future<bool> sendTopicNotification({
    required String topic,
    required String title,
    required String body,
  }) async {
    final url = Uri.parse("$_baseUrl/sendTopicNotification");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"title": title, "body": body, "topic": topic}),
      );

      if (response.statusCode == 200) {
        print("✅ Topic notification sent: ${response.body}");
        return true;
      } else {
        print("⚠️ Failed: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      print("❌ Error sending topic notification: $e");
      return false;
    }
  }

  /// Get FCM token for current device
  static Future<String?> getFCMToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      print("❌ Error getting FCM token: $e");
      return null;
    }
  }

  /// Subscribe to a topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      print("✅ Subscribed to topic: $topic");
    } catch (e) {
      print("❌ Error subscribing to topic $topic: $e");
    }
  }

  /// Unsubscribe from a topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      print("✅ Unsubscribed from topic: $topic");
    } catch (e) {
      print("❌ Error unsubscribing from topic $topic: $e");
    }
  }

  /// Setup default topic subscriptions for a user
  static Future<void> setupDefaultSubscriptions() async {
    await subscribeToTopic('morning_reminders');
    await subscribeToTopic('evening_reminders');
    await subscribeToTopic('general_announcements');
  }

  /// Send a test notification to current device
  static Future<bool> sendTestNotification() async {
    final token = await getFCMToken();
    if (token == null) return false;

    return await sendPushNotificationv2(
      deviceToken: token,
      title: 'Test Notification',
      body: 'This is a test notification from your Student Reminder app!',
    );
  }
}
