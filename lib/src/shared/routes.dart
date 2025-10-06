import 'package:flutter/material.dart';
import 'package:students_reminder/src/admin/pages/admin_dashborad.dart';
import 'package:students_reminder/src/admin/pages/admin_geofence_editor.dart';
import 'package:students_reminder/src/admin/pages/admin_profileview_page.dart';
import 'package:students_reminder/src/admin/pages/trends.dart';
import 'package:students_reminder/src/features/auth/login_page.dart';
import 'package:students_reminder/src/features/auth/register_page.dart';
import 'package:students_reminder/src/features/auth/forgot_password_page.dart';
import 'package:students_reminder/src/features/profile/profile_page.dart';
import 'package:students_reminder/src/features/profile/student_profile_page.dart';
import 'package:students_reminder/src/intro/intro_screen.dart';
import 'package:students_reminder/src/shared/main_layout.dart';
import 'package:students_reminder/src/admin/pages/attendance_admin_page.dart';
import 'package:students_reminder/src/admin/pages/admin_public_feeds.dart';
import 'package:students_reminder/src/features/splash/splash_gate.dart';
import 'package:students_reminder/src/timetable/timetable.dart';
import 'package:students_reminder/src/features/geofence/student_geofence_dashboard.dart';
import 'package:students_reminder/src/features/geofence/geofence_incident_history.dart';
import 'package:students_reminder/src/features/geofence/student_location_selection_page.dart';

class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const main = '/main';
  static const intro = '/intro';
  static const admin = '/admin';
  static const adminProfileviewPage = '/admin-profileview-page';
  static const adminDashboard = '/admin-dashboard';
  static const adminFeeds = '/admin-feeds';
  static const adminNav = '/admin-home';
  static const time = '/timetable';
  static const splash = '/splash';
  static const studentAttendance = '/student-attendance';
  static const geofence = '/geofence';
  static const geofenceDashboard = '/geofence-dashboard';
  static const geofenceIncidents = '/geofence-incidents';
  static const locationSelection = '/location-selection';
  static const profile = '/profile'; // ✅ Added profile route
  static const trends = '/trends';

  static Route<dynamic> onGenerateRoute(RouteSettings setting) {
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
      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordPage());
      case main:
        return MaterialPageRoute(builder: (_) => const MainLayoutPage());
      case intro:
        return MaterialPageRoute(builder: (_) => const IntroScreen());
      case admin:
        return MaterialPageRoute(builder: (_) => const AttendanceAdminPage());
      case adminDashboard:
        return MaterialPageRoute(builder: (_) => const AdminDashboard());
      case adminProfileviewPage:
        return MaterialPageRoute(builder: (_) => const AdminProfileviewPage());
      case adminFeeds:
        return MaterialPageRoute(builder: (_) => const AdminPublicFeeds());
      case time:
        return MaterialPageRoute(
          builder: (_) => const TimetableGeneratorScreen(),
        );
      case trends:
        return MaterialPageRoute(builder: (_) => const TrendsPage());
      case geofence:
        final args = setting.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => AdminGeofenceEditor(
            studentId: args?['studentId'] ?? '',
            dateId: args?['dateId'] ?? '',
          ),
        );
      case geofenceDashboard:
        return MaterialPageRoute(
          builder: (_) => const StudentGeofenceDashboard(),
        );
      case geofenceIncidents:
        return MaterialPageRoute(
          builder: (_) => const GeofenceIncidentHistory(),
        );
      case locationSelection:
        return MaterialPageRoute(
          builder: (_) => const StudentLocationSelectionPage(),
        );
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashGate());
      case profile: // ✅ Added profile page
        return MaterialPageRoute(builder: (_) => const ProfilePage());
      default:
        return MaterialPageRoute(builder: (_) => const SplashGate());
    }
  }
}
