import 'package:flutter/material.dart';

Color getInitialColor(String name) {
  final colors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
    Colors.cyan,
  ];

  if (name.isEmpty) return Colors.grey;
  return colors[name.codeUnitAt(0) % colors.length];
}
