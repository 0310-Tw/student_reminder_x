import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class AttendanceService {
  static final _firestore = FirebaseFirestore.instance;

  /// Stream last 14 days attendance
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamLast14Days(String uid) {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 14));

    return _firestore
        .collection('attendance')
        .doc(uid)
        .collection('days')
        .where('dayId', isGreaterThanOrEqualTo: _dateId(start))
        .where('dayId', isLessThanOrEqualTo: _dateId(now))
        .snapshots();
  }

  /// Clock in
  static Future<void> clockIn(String uid, Position pos, String placeName) async {
    final now = DateTime.now();
    final dayId = _dateId(now);

    final data = {
      'dayId': dayId,
      'inAt': Timestamp.fromDate(now),
      'inLoc': GeoPoint(pos.latitude, pos.longitude),
      'placeIn': placeName,
    };

    await _firestore
        .collection('attendance')
        .doc(uid)
        .collection('days')
        .doc(dayId)
        .set(data, SetOptions(merge: true));
  }

  /// Clock out
  static Future<void> clockOut(String uid, Position pos, String placeName) async {
    final now = DateTime.now();
    final dayId = _dateId(now);

    final docRef = _firestore.collection('attendance').doc(uid).collection('days').doc(dayId);
    final snapshot = await docRef.get();

    if (!snapshot.exists || snapshot.data()?['inAt'] == null) {
      throw Exception("Cannot clock out before clocking in.");
    }

    await docRef.set({
      'outAt': Timestamp.fromDate(now),
      'outLoc': GeoPoint(pos.latitude, pos.longitude),
      'placeOut': placeName,
    }, SetOptions(merge: true));
  }

  /// Helper: YYYYMMDD format
  static String _dateId(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return "$y$m$d";
  }
}
