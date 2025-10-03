import 'package:flutter/material.dart';

ThemeData buildTheme() {
  final primaryScheme = ColorScheme.fromSeed(seedColor: Color(0xFF5BC0DE));
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: Color(0xFF5BC0DE),
  );

  return base.copyWith(
        
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: primaryScheme.surfaceContainerHighest.withOpacity(0.5),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      prefixIconColor: primaryScheme.primary,
      prefixStyle: TextStyle(color: primaryScheme.primary),

      floatingLabelStyle: TextStyle(
        color: primaryScheme.primary,
        fontWeight: FontWeight.w600,
      ),
      border: OutlineInputBorder(),
      ),
    navigationBarTheme: NavigationBarThemeData(
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
  );
}
