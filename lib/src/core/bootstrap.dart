import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:students_reminder/firebase_options.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/services/session_manager.dart';

// Background message handler for FCM
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}

Future<void> initFirebase() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (await SessionManager.isExpired()) {
    await AuthService.instance.logout();
  }
}

Future<void> initNotifications() async {
  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize FCM and get token
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Request permission
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  // Check if permissions were granted and setup notifications accordingly
  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print("Notification permissions granted");

    // Get the token
    String? token = await messaging.getToken();
    print("FCM Token: $token");

    // Setup foreground message handling
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Foreground message received: ${message.notification?.title}");
    });

    // Setup message handling when app is opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("App opened from notification: ${message.notification?.title}");
    });
  } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
    print("Notification permissions denied");
  } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
    print("Notification permissions provisional");
  } else {
    print("Notification permission status: ${settings.authorizationStatus}");
  }
}
