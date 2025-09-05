import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:students_reminder/src/features/auth/login_page.dart';
import 'package:students_reminder/src/features/home/home_page.dart';
import 'package:students_reminder/src/features/notes/my_notes_page.dart';
import 'package:students_reminder/src/features/profile/profile_page.dart';
import 'package:students_reminder/src/features/public_notes/public_notes_page.dart';
import 'package:students_reminder/src/admin/pages_screens/admin_home_page.dart';
import 'package:students_reminder/src/admin/pages_screens/admin_public_feeds.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/services/admin_service.dart';
import 'package:students_reminder/src/admin/pages_screens/attendance_admin_page.dart';
import 'package:students_reminder/src/services/notification_service_v2.dart';

class MainLayoutPage extends StatefulWidget {
  const MainLayoutPage({super.key});

  @override
  State<MainLayoutPage> createState() => _MainLayoutPageState();
}

class _MainLayoutPageState extends State<MainLayoutPage> {
  int _index = 0;
  bool _isAdmin = false;
  bool _isLoadingAdminStatus = true;

  List<Widget> get _pages => _isAdmin
      ? [
          // Admin  pages
          AdminHomePage(),
          AdminPublicFeeds(),
          AttendanceAdminPage(),
          ProfilePage(),
        ]
      : [
          // Regular users pages
          HomePage(),
          MyNotesPage(),
          PublicFeeds(),
          ProfilePage(),
        ];

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _setupNotifications();
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await AdminService.instance.isCurrentUserAdmin();
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
        _isLoadingAdminStatus = false;
        // Reset index if it's out of bounds after admin check
        if (_index >= _pages.length) {
          _index = 0;
        }
      });
    }
  }

  Future<void> _setupNotifications() async {
    // Setup FCM token and subscribe to topics for the current user
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          // Get FCM token and subscribe to user-specific topics
          String? token = await NotificationService.getFCMToken();
          if (token != null) {
            print(
              "✅ FCM Token obtained in MainLayout: ${token.substring(0, 20)}...",
            );

            // Subscribe to user-specific notification topic
            await NotificationService.subscribeToTopic('user_${user.uid}');

            // Subscribe to general topics
            await NotificationService.subscribeToTopic('all_users');

            print("✅ Notification setup completed for user: ${user.uid}");
          }
        } catch (e) {
          print("❌ Error setting up notifications: $e");
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanged(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting ||
            _isLoadingAdminStatus) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) return LoginPage();
        return Scaffold(
          body: _pages[_index],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            destinations: _isAdmin
                ? [
                    NavigationDestination(
                      icon: Icon(Icons.admin_panel_settings),
                      label: 'Users',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.content_paste),
                      label: 'Content',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.checklist),
                      label: 'Attendance',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      label: 'Profile',
                    ),
                  ]
                : [
                    NavigationDestination(
                      icon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.event_note),
                      label: 'Notes',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.public),
                      label: 'Public Feeds',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      label: 'Profile',
                    ),
                  ],
            onDestinationSelected: (i) => setState(() => _index = i),
          ),
        );
      },
    );
  }
}
