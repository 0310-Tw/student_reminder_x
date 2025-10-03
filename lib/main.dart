import 'package:flutter/material.dart';
import 'package:students_reminder/src/core/app_theme.dart';
import 'package:students_reminder/src/core/bootstrap.dart';
import 'package:students_reminder/src/shared/routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initFirebase();
  await initNotifications();

  runApp(const StudentsReminderApp());
}

class StudentsReminderApp extends StatelessWidget {
  const StudentsReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Students Reminder',
      theme: buildTheme(),
      debugShowCheckedModeBanner: false,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      // initialRoute: AppRoutes.register,
      initialRoute: AppRoutes.intro,
    );
  }
}
