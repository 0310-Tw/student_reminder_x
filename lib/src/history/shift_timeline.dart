import 'package:flutter/material.dart';
class ShiftTimeline extends StatelessWidget {
  final DateTime? clockIn;
  final DateTime? clockOut;
  final Color? color; // optional external color

  const ShiftTimeline({
    super.key,
    this.clockIn,
    this.clockOut,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Determine status
    final status = _getStatus(clockIn, clockOut);

    // Use passed color if provided, otherwise determine from status
    final timelineColor = color ?? _colorForStatus(status);

    return Container(
      height: 6,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: timelineColor,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  /// Simple status rules
  String _getStatus(DateTime? inAt, DateTime? outAt) {
    if (inAt == null && outAt == null) return 'absent';
    if (inAt != null) {
      final shiftStart = DateTime(inAt.year, inAt.month, inAt.day, 9, 0);
      return inAt.isBefore(shiftStart) ? 'early' : 'late';
    }
    return 'present';
  }

  /// Map status to default colors
  Color _colorForStatus(String status) {
    switch (status) {
      case 'early':
        return Colors.green;
      case 'late':
        return Colors.orange;
      case 'absent':
        return Colors.red;
      default:
        return Colors.grey.shade400;
    }
  }
}