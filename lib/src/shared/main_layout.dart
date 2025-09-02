import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:students_reminder/src/features/auth/login_page.dart';
import 'package:students_reminder/src/features/home/home_page.dart';
import 'package:students_reminder/src/features/notes/my_notes_page.dart';
import 'package:students_reminder/src/features/profile/profile_page.dart';
import 'package:students_reminder/src/features/public_notes/public_notes_page.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/admin/pages/attendance_admin_page.dart';
import 'package:students_reminder/src/admin/services/attendance_service.dart';

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
          HomePage(),
         
          PublicFeeds(),
          AttendanceAdminPage(),
          ProfilePage(),
        ]
      : [HomePage(), MyNotesPage(), PublicFeeds(), ProfilePage()];

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await AttendanceService.isCurrentUserAdmin();
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
                      icon: Icon(Icons.home),
                      label: 'Home',
                    ),
                   
                    NavigationDestination(
                      icon: Icon(Icons.public),
                      label: 'Public Feeds',
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
