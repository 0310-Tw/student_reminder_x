// lib/src/services/geofence_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:students_reminder/src/admin/models/geofence_model.dart';


class GeofenceService {
  GeofenceService._();
  static final instance = GeofenceService._();

  final _db = FirebaseFirestore.instance;

  /// Save or update a geofence profile for a specific day.
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

  /// Fetch a geofence profile for a specific day.
  Future<GeofenceProfile?> getProfile({
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
    return null;
  }
}
