import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void displaySnackBar(
  BuildContext context,
  String message, {
  Color backgroundColor = Colors.blue,
  Color textColor = Colors.white,
  Duration duration = const Duration(seconds: 5),
  SnackBarAction? action,
}) {
  // Check if the context is still mounted before trying to access ScaffoldMessenger
  try {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Center(
            child: Text(message, style: TextStyle(color: textColor)),
          ),
          backgroundColor: backgroundColor,
          duration: duration,
        ),
      );
    }
  } catch (e) {
    // If there's an error accessing the context, just ignore it
    // This prevents crashes when the widget is disposed
    debugPrint('Could not show snackbar: $e');
  }
}

Color hexToColor(String hexCode) {
  final buffer = StringBuffer();
  if (hexCode.startsWith('#')) hexCode = hexCode.substring(1);
  if (hexCode.length == 6) buffer.write('ff');
  buffer.write(hexCode.toUpperCase());
  return Color(int.parse(buffer.toString(), radix: 16));
}
