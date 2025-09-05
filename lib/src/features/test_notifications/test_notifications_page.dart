import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:students_reminder/src/services/notification_service_v2.dart';

class TestNotificationsPage extends StatefulWidget {
  const TestNotificationsPage({super.key});

  @override
  State<TestNotificationsPage> createState() => _TestNotificationsPageState();
}

class _TestNotificationsPageState extends State<TestNotificationsPage> {
  String? _fcmToken;
  bool _isLoading = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _getFCMToken();
    _setupMessageHandlers();
  }

  Future<void> _getFCMToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      setState(() {
        _fcmToken = token;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error getting FCM token: $e';
      });
    }
  }

  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      setState(() {
        _statusMessage =
            'Received foreground message: ${message.notification?.title}';
      });

      // Show a local dialog when notification is received
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(message.notification?.title ?? 'Notification'),
            content: Text(message.notification?.body ?? 'No body'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    });

    // Handle notification taps when app is in background/foreground
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      setState(() {
        _statusMessage = 'Notification tapped: ${message.notification?.title}';
      });
    });
  }

  Future<void> _sendTestNotificationViaAPI() async {
    if (_fcmToken == null) {
      setState(() {
        _statusMessage = 'No FCM token available';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Sending test notification via Cloud Functions...';
    });

    try {
      final success = await NotificationService.sendPushNotificationv2(
        deviceToken: _fcmToken!,
        title: 'Test Notification',
        body: 'This is a test notification sent via Cloud Functions!',
      );

      setState(() {
        _statusMessage = success
            ? '✅ Test notification sent successfully!'
            : '❌ Failed to send test notification';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Test Notifications'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FCM Token:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        _fcmToken ?? 'Loading...',
                        style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _sendTestNotificationViaAPI,
              icon: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.send),
              label: Text(
                _isLoading
                    ? 'Sending...'
                    : 'Send Test Notification via Cloud Functions',
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),

            SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: () async {
                setState(() {
                  _statusMessage = 'Subscribing to topics...';
                });
                await NotificationService.setupDefaultSubscriptions();
                setState(() {
                  _statusMessage =
                      '✅ Subscribed to default notification topics!';
                });
              },
              icon: Icon(Icons.topic),
              label: Text('Subscribe to Topics'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),

            SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _getFCMToken,
              icon: Icon(Icons.refresh),
              label: Text('Refresh FCM Token'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),

            SizedBox(height: 20),

            if (_statusMessage.isNotEmpty) ...[
              Text(
                'Status:',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Text(
                  _statusMessage,
                  style: TextStyle(color: Colors.blue[800]),
                ),
              ),
            ],

            Spacer(),

            Card(
              color: Colors.amber[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.amber[800]),
                        SizedBox(width: 8),
                        Text(
                          'How to test notifications:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Copy the FCM token above\n'
                      '2. Use "Send Test Notification" button to test via Cloud Functions\n'
                      '3. Subscribe to topics for scheduled reminders\n'
                      '4. Test Firebase Console by pasting token there\n\n'
                      'The Cloud Functions method should work better than Firebase Console.',
                      style: TextStyle(color: Colors.amber[800]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
