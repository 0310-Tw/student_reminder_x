import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ShiftTimeline extends StatelessWidget {
  final DateTime? clockIn;
  final DateTime? clockOut;
  final bool clockOutAuto;
  final String? placeIn;
  final String? placeOut;
  final String? livePlace;

  const ShiftTimeline({
    super.key,
    this.clockIn,
    this.clockOut,
    this.clockOutAuto = false,
    this.placeIn,
    this.placeOut,
    this.livePlace,
    required Color color,
  });

  @override
  Widget build(BuildContext context) {
    final status = _getStatus(clockIn, clockOut);

    Color color;
    String label;

    switch (status) {
      case 'early':
        color = Colors.green;
        label = 'Early';
        break;
      case 'late':
        color = Colors.orange;
        label = 'Late';
        break;
      case 'left_early':
        color = Colors.deepOrange;
        label = 'Left Early';
        break;
      case 'absent':
        color = Colors.red;
        label = 'Absent';
        break;
      default:
        color = Colors.grey;
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Shift Timeline",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Status: $label",
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
                if (clockIn != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Clock In: ${_fmtJM(clockIn)}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (placeIn != null)
                        Text(
                          placeIn!,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                if (clockOut != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Clock Out: ${_fmtJM(clockOut)}${clockOutAuto ? ' (Auto)' : ''}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (placeOut != null)
                        Text(
                          placeOut!,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                if (livePlace != null)
                  Text(
                    "Live: $livePlace",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatus(DateTime? inTime, DateTime? outTime) {
    if (inTime == null) return "absent";

    final eightAM = DateTime(inTime.year, inTime.month, inTime.day, 8, 0);
    final eightThirty = DateTime(inTime.year, inTime.month, inTime.day, 8, 30);
    final fourPM = DateTime(inTime.year, inTime.month, inTime.day, 16, 0);

    if (outTime != null && outTime.isBefore(fourPM)) return "left_early";

    if (inTime.isAfter(eightAM) && inTime.isBefore(eightThirty)) return "early";
    if (inTime.isAfter(eightThirty)) return "late";

    return "early";
  }

  String _fmtJM(DateTime? t) {
    if (t == null) return '—';
    return DateFormat.jm().format(t);
  }
}
