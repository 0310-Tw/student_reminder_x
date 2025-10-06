import 'dart:math' as math;

class CampusLocation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  CampusLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });
}

class StudentProfile {
  final String id;
  final String name;
  final Map<String, String> geofenceSchedule;

  StudentProfile({
    required this.id,
    required this.name,
    required this.geofenceSchedule,
  });

  String getCampusForToday() {
    final now = DateTime.now();
    final weekday = now.weekday; // 1 = Monday, 7 = Sunday

    const dayMap = {
      1: "monday",
      2: "tuesday",
      3: "wednesday",
      4: "thursday",
      5: "friday",
      6: "saturday",
      7: "sunday",
    };

    final todayKey = dayMap[weekday]!;
    return geofenceSchedule[todayKey] ?? "up_park_camp"; // fallback
  }
}

class CampusLocationService {
  static final CampusLocationService _instance =
      CampusLocationService._internal();
  factory CampusLocationService() => _instance;
  CampusLocationService._internal();

  // Static campus locations data
  static final Map<String, CampusLocation> _campusLocations = {
    "up_park_camp": CampusLocation(
      id: "up_park_camp",
      name: "Up Park Camp",
      latitude: 18.0123,
      longitude: -76.7890,
      radiusMeters: 100,
    ),
    "stony_hill": CampusLocation(
      id: "stony_hill",
      name: "Stony Hill Campus",
      latitude: 18.1234,
      longitude: -76.8765,
      radiusMeters: 100,
    ),
  };

  /// Get all available campus locations
  Map<String, CampusLocation> get allCampusLocations => _campusLocations;

  /// Get a specific campus location by ID
  CampusLocation? getCampusLocation(String campusId) {
    return _campusLocations[campusId];
  }

  /// Get campus location for a student for today
  CampusLocation? getTodayCampusForStudent(StudentProfile studentProfile) {
    final campusId = studentProfile.getCampusForToday();
    return getCampusLocation(campusId);
  }

  /// Create a GeofenceProfile from campus location for both check-in and check-out
  Map<String, dynamic> createGeofenceProfileFromCampus(
    String campusId, {
    String bandType = 'fixed',
    String outsidePolicy = 'allow',
    String? outsideMessage,
  }) {
    final campus = getCampusLocation(campusId);
    if (campus == null) {
      throw Exception('Campus location not found: $campusId');
    }

    return {
      'checkInLocation': {
        'lat': campus.latitude,
        'lng': campus.longitude,
        'radius': campus.radiusMeters,
      },
      'checkOutLocation': {
        'lat': campus.latitude,
        'lng': campus.longitude,
        'radius': campus.radiusMeters,
      },
      'bandType': bandType,
      'outsidePolicy': outsidePolicy,
      'outsideMessage': outsideMessage,
      'campusId': campusId,
      'campusName': campus.name,
    };
  }

  /// Check if a location is within any campus geofence
  String? findCampusForLocation(
    double latitude,
    double longitude, {
    double tolerance = 50.0,
  }) {
    for (final entry in _campusLocations.entries) {
      final campus = entry.value;
      final distance = _calculateDistance(
        latitude,
        longitude,
        campus.latitude,
        campus.longitude,
      );

      if (distance <= (campus.radiusMeters + tolerance)) {
        return entry.key;
      }
    }
    return null;
  }

  /// Helper method to calculate distance between two points
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // Earth radius in meters
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Get all campus names for dropdown/selection UI
  List<String> getCampusNames() {
    return _campusLocations.values.map((campus) => campus.name).toList();
  }

  /// Get campus options for UI selection
  List<Map<String, String>> getCampusOptions() {
    return _campusLocations.entries
        .map((entry) => {'id': entry.key, 'name': entry.value.name})
        .toList();
  }
}
