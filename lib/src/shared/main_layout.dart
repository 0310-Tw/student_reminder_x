import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:students_reminder/src/features/auth/login_page.dart';
import 'package:students_reminder/src/features/home/home_page.dart';
import 'package:students_reminder/src/features/notes/my_notes_page.dart';
import 'package:students_reminder/src/features/profile/profile_page.dart';
import 'package:students_reminder/src/features/public_notes/public_notes_page.dart';
import 'package:students_reminder/src/history/attendance_history.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/services/admin_service.dart';
import 'package:students_reminder/src/services/notification_service.dart';
import 'package:students_reminder/src/admin/pages/admin_home_page.dart';
import 'package:students_reminder/src/admin/pages/admin_public_feeds.dart';
import 'package:students_reminder/src/admin/pages/attendance_admin_page.dart';

class MainLayoutPage extends StatefulWidget {
  const MainLayoutPage({super.key});

  @override
  State<MainLayoutPage> createState() => _MainLayoutPageState();
}

class _MainLayoutPageState extends State<MainLayoutPage> {
  int _index = 0;
  bool _isAdmin = false;
  bool _isLoadingAdminStatus = true;
  List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _initializeNotifications();
  }

  // Initialize notifications for logged-in users
  Future<void> _initializeNotifications() async {
    try {
      await NotificationService.initialize();
      // print('Foreground notifications initialized for logged-in user');

      // Update FCM token for this user
      final token = await NotificationService.getToken();
      if (token != null) {
        await _updateUserFCMToken(token);
      }

      // Listen for token refresh
      NotificationService.onTokenRefresh((newToken) {
        _updateUserFCMToken(newToken);
      });
    } catch (e) {
      print('Failed to initialize foreground notifications: $e');
    }
  }

  // Update user's FCM token in Firestore
  Future<void> _updateUserFCMToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': token});
        print('FCM token updated for logged-in user');
      }
    } catch (e) {
      print('Failed to update FCM token: $e');
    }
  }

  Future<void> _checkAdminStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      // Early exit if user is null or widget is not mounted
      if (user == null || !mounted) {
        if (mounted) {
          setState(() {
            _isAdmin = false;
            _isLoadingAdminStatus = false;
            _updatePages();
          });
        }
        return;
      }

      final adminStatus = await AdminService.instance.isCurrentUserAdmin();

      // Check again if widget is still mounted after async call
      if (!mounted) return;

      setState(() {
        _isAdmin = adminStatus;
        _isLoadingAdminStatus = false;
        _updatePages();
      });
    } catch (e) {
      print('Error checking admin status: $e');
      if (mounted) {
        setState(() {
          _isAdmin = false;
          _isLoadingAdminStatus = false;
          _updatePages();
        });
      }
    }
  }

  void _updatePages() {
    if (_isAdmin) {
      _pages = [
        const AdminHomePage(),
        const AdminPublicFeeds(),
        const AttendanceAdminPage(),
        const ProfilePage(),
      ];
    } else {
      _pages = [
        const HomePage(),
        const MyNotesPage(),
        PublicFeeds(),
        AttendanceHistory14d(),
        const ProfilePage(),
      ];
    }
  }

  List<NavigationDestination> _buildNavigationDestinations() {
    if (_isAdmin) {
      return [
        const NavigationDestination(icon: Icon(Icons.people), label: 'Users'),
        const NavigationDestination(
          icon: Icon(Icons.content_copy),
          label: 'Content',
        ),
        const NavigationDestination(
          icon: Icon(Icons.assessment),
          label: 'Attendance',
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ];
    } else {
      return [
        const NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
        const NavigationDestination(
          icon: Icon(Icons.event_note),
          label: 'Notes',
        ),
        const NavigationDestination(
          icon: Icon(Icons.public),
          label: 'Public Feeds',
        ),
        const NavigationDestination(
          icon: Icon(Icons.history),
          label: 'Attendance',
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ];
    }
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
            indicatorShape: _isAdmin
                ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                : const CircleBorder(),
            indicatorColor: _isAdmin ? null : Color(0xFF3498DB),
            backgroundColor: _isAdmin ? null : Color(0xFFF7F9FC),
            selectedIndex: _index,
            destinations: _buildNavigationDestinations(),
            onDestinationSelected: (i) => setState(() => _index = i),
          ),
        );
      },
    );
  }
}
