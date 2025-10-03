import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:students_reminder/src/admin/models/geofence_model.dart';

class GeofenceService {
  GeofenceService._();
  static final instance = GeofenceService._();

  final _db = FirebaseFirestore.instance;

  /// Save or update a geofence profile for a specific day
  Future<void> setProfile({
    required String studentId,
    required String dateId, // e.g. 20251001
    required GeofenceProfile profile,
  }) async {
    await _db
        .collection('geofences')
        .doc(studentId)
        .collection('days')
        .doc(dateId)
        .set(profile.toMap(), SetOptions(merge: true));
  }

  /// Fetch a geofence profile for a specific day, falling back to default if none exists
  Future<GeofenceProfile> getProfile({
    required String studentId,
    required String dateId,
  }) async {
    final doc = await _db
        .collection('geofences')
        .doc(studentId)
        .collection('days')
        .doc(dateId)
        .get();

    if (doc.exists) {
      return GeofenceProfile.fromDoc(doc);
    }

    // No profile saved → return default based on day of week
    final dt = DateTime.parse(dateId); // dateId like 20251001
    return _defaultProfileForDay(dt);
  }

  /// Log a geofence incident when a student clocks in/out outside the zone
  Future<void> logIncident({
    required String studentId,
    required String dateId,
    required String type, // "checkin" or "checkout"
    required double actualLat,
    required double actualLng,
    required double designatedLat,
    required double designatedLng,
    required double distance,
  }) async {
    await _db
        .collection('geofenceIncidents')
        .doc(studentId)
        .collection('incidents')
        .add({
      'type': type,
      'dateId': dateId,
      'actualLat': actualLat,
      'actualLng': actualLng,
      'designatedLat': designatedLat,
      'designatedLng': designatedLng,
      'distance': distance,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Optional: stream incidents for a student
  Stream<QuerySnapshot<Map<String, dynamic>>> getIncidents(String studentId) {
    return _db
        .collection('geofenceIncidents')
        .doc(studentId)
        .collection('incidents')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Internal helper to return the default profile based on day of week.
  GeofenceProfile _defaultProfileForDay(DateTime day) {
    final stonyHill = {
      'lat': 18.05,
      'lng': -76.82,
      'radius': 150.0,
    };
    final upPark = {
      'lat': 18.00,
      'lng': -76.80,
      'radius': 150.0,
    };

    final def = (day.weekday == DateTime.wednesday || day.weekday == DateTime.thursday)
        ? stonyHill
        : upPark;

    return GeofenceProfile(
      inLat: def['lat']!,
      inLng: def['lng']!,
      inRadius: def['radius']!,
      outLat: def['lat']!,
      outLng: def['lng']!,
      outRadius: def['radius']!,
      bandType: 'fixed',       // default band type
      outsidePolicy: 'block',  // default policy
      outsideMessage: null,    // no message by default
    );
  }
}
