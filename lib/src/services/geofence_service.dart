import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:students_reminder/src/admin/models/geofence_profile.dart';
import 'package:students_reminder/src/admin/pages/campus_location.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/services/campus_location_service.dart';

class GeofenceService {
  static final GeofenceService _instance = GeofenceService._internal();
  factory GeofenceService() => _instance;
  GeofenceService._internal();

  static GeofenceService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<Position>? _locationSubscription;
  final CampusLocationService _campusService = CampusLocationService();

  // ----------------------------------------------------
  // CAMPUS & PROFILE UTILITIES
  // ----------------------------------------------------

  CampusLocation? getCampusLocation(String campusId) =>
      _campusService.getCampusLocation(campusId);

  Map<String, dynamic> createProfileFromCampus(
    String campusId, {
    String bandType = 'fixed',
    String outsidePolicy = 'allow',
    String? outsideMessage,
  }) {
    return _campusService.createGeofenceProfileFromCampus(
      campusId,
      bandType: bandType,
      outsidePolicy: outsidePolicy,
      outsideMessage: outsideMessage,
    );
  }

  Future<String?> detectCurrentCampus({double tolerance = 75.0}) async {
    try {
      final position = await getCurrentLocation();
      return _campusService.findCampusForLocation(
        position.latitude,
        position.longitude,
        tolerance: tolerance,
      );
    } catch (e) {
      print('⚠️ Error detecting campus: $e');
      return null;
    }
  }

  // ----------------------------------------------------
  // PROFILE CREATION & RETRIEVAL
  // ----------------------------------------------------

  Future<GeofenceProfile?> getProfile(String studentId, String dateId) async {
    try {
      final doc = await _firestore
          .collection('geofences')
          .doc(studentId)
          .collection('days')
          .doc(dateId)
          .get();

      if (doc.exists && doc.data() != null) {
        return GeofenceProfile.fromDoc(doc);
      }

      final dt = _parseDateId(dateId);
      if (dt != null) {
        return _defaultProfileForDay(dt);
      }
      return null;
    } catch (e) {
      print('❌ Error getting geofence profile: $e');
      return null;
    }
  }

  /// ✅ Public helper for accessing default profile
  GeofenceProfile getDefaultProfileForDay(DateTime day) =>
      _defaultProfileForDay(day);

  /// ✅ Save or update geofence profile for a student/day
  Future<void> setProfile({
    required String studentId,
    required String dateId,
    required GeofenceProfile profile,
  }) async {
    try {
      await _firestore
          .collection('geofences')
          .doc(studentId)
          .collection('days')
          .doc(dateId)
          .set(profile.toMap(), SetOptions(merge: true));

      print('✅ Geofence profile saved for $studentId on $dateId');
    } catch (e) {
      print('❌ Error saving geofence profile: $e');
      rethrow;
    }
  }

  // ----------------------------------------------------
  // LOCATION UTILITIES
  // ----------------------------------------------------

  Future<Position> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw GeofenceException('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw GeofenceException('Location permissions denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw GeofenceException(
        'Location permissions are permanently denied. Enable them in settings.',
      );
    }

    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  double calculateDistance(double lat1, double lng1, double lat2, double lng2) =>
      Geolocator.distanceBetween(lat1, lng1, lat2, lng2);

  // ----------------------------------------------------
  // INCIDENT LOGGING
  // ----------------------------------------------------

  Future<void> logIncident({
    required String studentId,
    required String dayId,
    required String direction,
    required double actualLat,
    required double actualLng,
    required double designatedLat,
    required double designatedLng,
    required double distanceMeters,
    String? outsideMessage,
  }) async {
    try {
      await _firestore
          .collection('geofence_incidents')
          .doc(studentId)
          .collection('incidents')
          .add({
        'type': direction,
        'dayId': dayId,
        'actualLat': actualLat,
        'actualLng': actualLng,
        'designatedLat': designatedLat,
        'designatedLng': designatedLng,
        'distanceMeters': distanceMeters,
        'outsideMessage': outsideMessage,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('📝 Geofence incident logged for $studentId ($direction)');
    } catch (e) {
      print('❌ Error logging geofence incident: $e');
    }
  }

  /// ✅ Stream incidents for current user with date filter
  Stream<QuerySnapshot<Map<String, dynamic>>> getStudentIncidentsWithDateFilter(
    DateTime start,
    DateTime end,
  ) {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    return _firestore
        .collection('geofence_incidents')
        .doc(user.uid)
        .collection('incidents')
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where(
          'timestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(end),
        )
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // ----------------------------------------------------
  // STUDENT GEOFENCE MANAGEMENT (For Weekly Schedule)
  // ----------------------------------------------------

  Future<Map<String, dynamic>> getAllGeofences(String studentId) async {
    final snapshot = await _firestore
        .collection('student_geofences')
        .doc(studentId)
        .collection('days')
        .get();

    return {
      for (var doc in snapshot.docs) doc.id: doc.data(),
    };
  }

  Future<void> saveGeofence(
    String studentId,
    String day,
    double lat,
    double lng,
    double radius,
  ) async {
    await _firestore
        .collection('student_geofences')
        .doc(studentId)
        .collection('days')
        .doc(day)
        .set({
      'lat': lat,
      'lng': lng,
      'radius': radius,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  List<Map<String, String>> getCampusOptions() {
    return [
      {'name': 'Up Park Camp', 'id': 'up_park_camp'},
      {'name': 'Stony Hill', 'id': 'stony_hill'},
    ];
  }

  static bool isValidDay(String day) {
    const validDays = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ];
    return validDays.contains(day.toLowerCase());
  }

  // ----------------------------------------------------
  // DEFAULTS
  // ----------------------------------------------------

  GeofenceProfile _defaultProfileForDay(DateTime day) {
    final stonyHill = {'lat': 18.07563, 'lng': -76.79324, 'radius': 150.0};
    final upPark = {'lat': 18.01649, 'lng': -76.78510, 'radius': 200.0};
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
      bandType: BandType.fixed,
      outsidePolicy: OutsidePolicy.allowAndFlag,
      outsideMessage: 'You are outside the default campus zone.',
    );
  }

  double? _extractDouble(dynamic v) =>
      (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '');

  DateTime? _parseDateId(String id) {
    try {
      final parts = id.split('-');
      if (parts.length == 3) {
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final d = int.parse(parts[2]);
        return DateTime(y, m, d);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void dispose() => _locationSubscription?.cancel();
}

// ----------------------------------------------------
// SUPPORT CLASSES
// ----------------------------------------------------

class GeofenceValidationResult {
  final bool isValid;
  final String message;
  final double distance;
  final bool flagged;
  final Position? position;
  final GeofenceErrorType? errorType;

  GeofenceValidationResult({
    required this.isValid,
    required this.message,
    required this.distance,
    this.flagged = false,
    this.position,
    this.errorType,
  });
}

enum GeofenceErrorType {
  noProfile,
  noTargetLocation,
  outsideGeofence,
  systemError,
  unknown,
}

class GeofenceException implements Exception {
  final String message;
  GeofenceException(this.message);
  @override
  String toString() => 'GeofenceException: $message';
}
