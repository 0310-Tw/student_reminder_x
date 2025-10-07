import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:students_reminder/src/admin/pages/admin_dashborad.dart';
import 'package:students_reminder/src/features/auth/login_page.dart';
import 'package:students_reminder/src/features/home/home_page.dart';
import 'package:students_reminder/src/features/notes/my_notes_page.dart';
import 'package:students_reminder/src/features/profile/profile_page.dart';
import 'package:students_reminder/src/features/public_notes/public_notes_page.dart';
import 'package:students_reminder/src/history/attendance_history.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/services/admin_service.dart';
import 'package:students_reminder/src/services/notification_service.dart';
import 'package:students_reminder/src/admin/pages/admin_public_feeds.dart';
import 'package:students_reminder/src/admin/pages/attendance_admin_page.dart';
import 'package:students_reminder/src/timetable/timetable.dart';

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
    final previousPageCount = _pages.length;
    if (_isAdmin) {
      _pages = [
        const AdminDashboard(),
        const AdminPublicFeeds(),
        const AttendanceAdminPage(),
        const ProfilePage(),
      ];
    } else {
      _pages = [
        const HomePage(),
        const MyNotesPage(),
        TimetableGeneratorScreen(),
        PublicFeeds(),
        AttendanceHistory14d(),
      ];

      // Reset index if switching between admin/student mode or if current index is out of bounds
      if (previousPageCount != _pages.length || _index >= _pages.length) {
        _index = 0;
      }
    }
  }

  List<Widget> _buildNavigationIcons() {
    if (_isAdmin) {
      return [
        Icon(Icons.people, size: 30, color: Colors.white),
        Icon(Icons.content_copy, size: 30, color: Colors.white),
        Icon(Icons.assessment, size: 30, color: Colors.white),
        Icon(Icons.person_outline, size: 30, color: Colors.white),
      ];
    } else {
      return [
        Icon(Icons.home, size: 30, color: Colors.white),
        Icon(Icons.book_online, size: 30, color: Colors.white),
        Icon(Icons.calendar_month, size: 30, color: Colors.white), // timetable
        Icon(Icons.public, size: 30, color: Colors.white),
        Icon(Icons.history, size: 30, color: Colors.white),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanged(),
      builder: (context, snap) {
        final user = snap.data;
        if (user == null) return LoginPage();

        // Show loading only on initial load, not during navigation
        if (snap.connectionState == ConnectionState.waiting && _pages.isEmpty) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Show loading for admin status only if pages aren't initialized yet
        if (_isLoadingAdminStatus && _pages.isEmpty) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Use IndexedStack to prevent page rebuilds and maintain state
        return Scaffold(
          body: IndexedStack(
            key: ValueKey(_isAdmin ? 'admin' : 'student'),
            index: _index,
            children: _pages.isNotEmpty ? _pages : [Container()],
          ),
          bottomNavigationBar: _pages.isNotEmpty
              ? CurvedNavigationBar(
                  index: _index,
                  height: 60.0,
                  items: _buildNavigationIcons(),
                  color: _isAdmin
                      ? const Color(0xFF6366F1)
                      : const Color(0xFF3498DB),
                  buttonBackgroundColor: _isAdmin
                      ? const Color(0xFF4F46E5)
                      : const Color(0xFF2980B9),
                  backgroundColor: Colors.transparent,
                  animationCurve: Curves.easeInOutCubic,
                  animationDuration: const Duration(milliseconds: 250),
                  onTap: (index) {
                    if (index != _index && index < _pages.length) {
                      setState(() => _index = index);
                    }
                  },
                )
              : null,
        );
      },
    );
  }
}
