// lib/src/admin/pages/campus_location.dart

/// Represents a campus location used for geofencing, attendance, and schedule assignment.
class CampusLocation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  const CampusLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  /// Converts to a map for Firestore or JSON compatibility.
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
      };

  /// Creates a CampusLocation from a Firestore or JSON map.
  factory CampusLocation.fromMap(Map<String, dynamic> data) {
    return CampusLocation(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (data['radiusMeters'] as num?)?.toDouble() ?? 100.0,
    );
  }
}

/// Predefined map of campus locations for easy access.
/// These are used by GeofenceService, CampusLocationService,
/// and student schedule mappings.
final Map<String, CampusLocation> campusLocations = {
  'up_park_camp': CampusLocation(
    id: 'up_park_camp',
    name: 'Up Park Camp',
    latitude: 18.01649,   // ✅ Accurate coordinates for Up Park Camp
    longitude: -76.78510,
    radiusMeters: 200,
  ),
  'stony_hill': CampusLocation(
    id: 'stony_hill',
    name: 'Stony Hill Campus',
    latitude: 18.07563,   // ✅ Accurate coordinates for Stony Hill HEART College
    longitude: -76.79324,
    radiusMeters: 150,
  ),
};

/// Helper to get a list of all available campuses.
List<CampusLocation> getAllCampuses() => campusLocations.values.toList();

/// Helper to fetch a campus by ID.
CampusLocation? getCampusById(String id) => campusLocations[id];
