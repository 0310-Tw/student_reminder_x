import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  // Replace with your actual Firebase project region and project ID
  static const String _baseUrl =
      "https://us-central1-student-reminder-xx-16738.cloudfunctions.net";

  static NotificationService? _instance;
  static NotificationService get instance =>
      _instance ??= NotificationService._();
  NotificationService._();

  // Local notifications plugin for foreground display
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static FirebaseMessaging? _messaging;
  static bool _initialized = false;

  // Initialize the notification service with foreground handling
  static Future<void> initialize() async {
    if (_initialized) return;

    _messaging = FirebaseMessaging.instance;

    // Request permissions
    await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Initialize local notifications for foreground display
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'admin_actions',
      'Admin Actions',
      description: 'Notifications for admin actions on user accounts',
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);

    // Handle foreground messages - this ensures notifications show when user is logged in
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Received foreground notification: ${message.notification?.title}');
      _showForegroundNotification(message);
    });

    // Handle notification taps when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification tapped: ${message.notification?.title}');
      _handleNotificationTap(message);
    });

    _initialized = true;
  }

  // Show notification when app is in foreground (user is logged in and active)
  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'admin_actions',
      'Admin Actions',
      channelDescription: 'Notifications for admin actions on user accounts',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(''),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message.notification?.title ?? 'Admin Action',
      message.notification?.body ?? 'Your account has been updated',
      notificationDetails,
      payload: message.data.toString(),
    );
  }

  // Handle notification tap actions
  static void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped with payload: ${response.payload}');
    _handleNotificationTap(null, payload: response.payload);
  }

  static void _handleNotificationTap(
    RemoteMessage? message, {
    String? payload,
  }) {
    final data = message?.data ?? <String, dynamic>{};
    final type = data['type'] as String?;

    print('Handling notification tap for type: $type');

    // You can implement navigation logic here based on notification type
    switch (type) {
      case 'suspension':
      case 'flag':
      case 'unflag':
      case 'attendance_update':
        // Navigate to specific pages based on notification type
        print('Navigate to appropriate page for type: $type');
        break;
      default:
        print('Handle notification tap for unknown type: $type');
    }
  }

  // Get FCM token for current user
  static Future<String?> getToken() async {
    if (_messaging == null) await initialize();
    return await _messaging!.getToken();
  }

  // Subscribe to token refresh
  static void onTokenRefresh(Function(String) callback) {
    if (_messaging == null) return;
    _messaging!.onTokenRefresh.listen(callback);
  }

  /// Send push notification using Cloud Functions
  static Future<bool> sendPushNotification({
    required String deviceToken,
    required String title,
    required String body,
  }) async {
    final url = Uri.parse("$_baseUrl/sendFCMNotification");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "token": deviceToken,
          "title": title,
          "body": body,
          "type": "admin_action",
        }),
      );

      if (response.statusCode == 200) {
        print("Notification sent: ${response.body}");
        return true;
      } else {
        print("Failed: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error sending push notification: $e");
      return false;
    }
  }

  /// Send notification to a topic using Cloud Functions
  static Future<bool> sendTopicNotification({
    required String topic,
    required String title,
    required String body,
  }) async {
    // TODO: Implement topic notification in Cloud Functions
    // For now, topic notifications are not supported
    try {
      print("Topic notification not implemented in Cloud Functions yet");
      print("Topic: $topic, Title: $title, Body: $body");
      return false;
    } catch (e) {
      print("Error sending topic notification: $e");
      return false;
    }
  }

  /// Get FCM token for current device
  static Future<String?> getFCMToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      print("Error getting FCM token: $e");
      return null;
    }
  }

  /// Subscribe to a topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      print("Subscribed to topic: $topic");
    } catch (e) {
      print("Error subscribing to topic $topic: $e");
    }
  }

  /// Unsubscribe from a topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      print("Unsubscribed from topic: $topic");
    } catch (e) {
      print("Error unsubscribing from topic $topic: $e");
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

    return await sendPushNotification(
      deviceToken: token,
      title: 'Test Notification',
      body: 'This is a test notification from your Student Reminder app!',
    );
  }
}
