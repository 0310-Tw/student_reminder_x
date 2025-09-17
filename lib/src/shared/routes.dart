import 'package:flutter/material.dart';
import 'package:students_reminder/src/admin/pages/admin_home_page.dart';

import 'package:students_reminder/src/features/auth/login_page.dart';
import 'package:students_reminder/src/features/auth/register_page.dart';
import 'package:students_reminder/src/features/profile/student_profile_page.dart';
import 'package:students_reminder/src/intro/intro_screen.dart';
import 'package:students_reminder/src/shared/main_layout.dart';
import 'package:students_reminder/src/admin/pages/attendance_admin_page.dart';
import 'package:students_reminder/src/admin/pages/admin_public_feeds.dart';

import 'package:students_reminder/src/features/splash/splash_gate.dart';

class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const main = '/main';
  static const admin = '/admin';
  static const adminDashboard = '/admin-dashboard';
  static const adminHome = '/admin-home';
  static const adminFeeds = '/admin-feeds';
  static const adminNav = '/admin-home';
  static const splash = '/splash';
  static const intro = '/intro';

  static Route<dynamic> onGenerateRoute(RouteSettings setting) {
    //Expecting /student/:uid
    //              /student/12345
    //              /student/
    final url = Uri.parse(setting.name ?? '');
    if (url.pathSegments.isNotEmpty && url.pathSegments[0] == 'student') {
      final uid = url.pathSegments.length > 1 ? url.pathSegments[1] : '';
      return MaterialPageRoute(builder: (_) => StudentProfilePage(uid: uid));
    }

    switch (setting.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterPage());
      case main:
        return MaterialPageRoute(builder: (_) => const MainLayoutPage());
      case admin:
        return MaterialPageRoute(builder: (_) => const AttendanceAdminPage());
      case adminDashboard:
        return MaterialPageRoute(builder: (_) => const AdminHomePage());
      case adminHome:
        return MaterialPageRoute(builder: (_) => const AdminHomePage());
      case adminFeeds:
        return MaterialPageRoute(builder: (_) => const AdminPublicFeeds());
      case intro:
        return MaterialPageRoute(builder: (_) => const IntroScreen());

      case splash:
        return MaterialPageRoute(builder: (_) => const SplashGate());
      default:
        return MaterialPageRoute(builder: (_) => const SplashGate());
    }
  }
}
