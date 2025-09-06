import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> markMissedDaysAbsent(String userId) async {
  final firestore = FirebaseFirestore.instance;
  final attendanceRef = firestore.collection('attendance').doc(userId).collection('days');

  // Get all attendance dates (or just the latest one)
  final lastAttendanceSnapshot = await attendanceRef
      .orderBy('date', descending: true)
      .limit(1)
      .get();

  DateTime lastDate;

  if (lastAttendanceSnapshot.docs.isEmpty) {
    // If no attendance at all, start from a default (e.g., semester start date)
    lastDate = DateTime.now().subtract(Duration(days: 30)); // Or use actual semester start
  } else {
    lastDate = DateTime.parse(lastAttendanceSnapshot.docs.first['date']);
  }

  // Go from lastDate + 1 to yesterday
  final now = DateTime.now();
  DateTime currentDate = lastDate.add(Duration(days: 1));
  final yesterday = DateTime(now.year, now.month, now.day).subtract(Duration(days: 1));

  while (currentDate.isBefore(yesterday) || currentDate.isAtSameMomentAs(yesterday)) {
    // Only mark weekdays (Mon–Fri)
    if (currentDate.weekday >= 1 && currentDate.weekday <= 5) {
      final dateString = currentDate.toIso8601String().substring(0, 10); // e.g., "2025-09-05"

      final docRef = attendanceRef.doc(dateString);
      final doc = await docRef.get();

      if (!doc.exists) {
        await docRef.set({
          'date': dateString,
          'status': 'Absent',
          'clockInTime': null,
          'clockOutTime': null,
          'clockInLocation': null,
          'clockOutLocation': null,
          'lateReason': null,
        });
      }
    }

    currentDate = currentDate.add(Duration(days: 1));
  }
}
