import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:students_reminder/firebase_options.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/services/session_manager.dart';

Future<void> initFirebase() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (await SessionManager.isExpired()) {
    await AuthService.instance.logout();
  }
}

// Background message handler for FCM
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}

Future<void> initNotifications() async {
  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Request notification permission
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional) {
    print("✅ Notification permissions granted");

    // ⚠️ Pass the VAPID key on web builds
    final String? token = await messaging.getToken(
      vapidKey: kIsWeb ? 'YOUR_PUBLIC_VAPID_KEY_HERE' : null,
    );

    print("✅ FCM Token: $token");

    // Foreground messages (while app is open)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("📩 Foreground message received: ${message.notification?.title}");
      // TODO: display a local notification or update your UI here
    });

    // When app is opened from notification click
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("📩 App opened from notification: ${message.notification?.title}");
      // TODO: navigate user or update UI accordingly
    });
  } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
    print("⚠️ Notification permissions denied (user clicked Block)");
  } else {
    print("⚠️ Notification permission status: ${settings.authorizationStatus}");
  }
}
