// lib/src/services/campus_location_service.dart

import 'dart:math';
import 'package:students_reminder/src/admin/pages/campus_location.dart';
import 'package:students_reminder/src/admin/models/geofence_model.dart';

/// A helper service for managing and retrieving predefined campus locations.
/// This service is used by [GeofenceService] and admin dashboards.
class CampusLocationService {
  /// Singleton instance
  static final CampusLocationService _instance = CampusLocationService._internal();
  factory CampusLocationService() => _instance;
  CampusLocationService._internal();

  /// Returns all available campus locations.
  List<CampusLocation> getAllCampuses() => campusLocations.values.toList();

  /// Returns a campus location by ID, or null if not found.
  CampusLocation? getCampusLocation(String campusId) {
    return campusLocations[campusId];
  }

  /// Converts all campuses to a UI-friendly dropdown list format.
  List<Map<String, String>> getCampusOptions() {
    return campusLocations.entries
        .map((entry) => {
              'id': entry.key,
              'name': entry.value.name,
            })
        .toList();
  }

  /// Creates a geofence profile map from a campus definition.
  /// Used by GeofenceService to build today's profile automatically.
  Map<String, dynamic> createGeofenceProfileFromCampus(
    String campusId, {
    String bandType = 'fixed',
    String outsidePolicy = 'allow',
    String? outsideMessage,
  }) {
    final campus = getCampusLocation(campusId);
    if (campus == null) {
      throw Exception('Campus not found: $campusId');
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
      'outsideMessage':
          outsideMessage ?? 'You are outside the ${campus.name} area.',
      'isCustomLocation': false,
      'campusId': campus.id,
      'campusName': campus.name,
    };
  }

  /// Finds the campus that a user’s current location belongs to.
  /// Returns the campus ID if found, or null otherwise.
  String? findCampusForLocation(
    double latitude,
    double longitude, {
    double tolerance = 50.0,
  }) {
    for (final campus in campusLocations.values) {
      final distance = _calculateDistanceMeters(
        latitude,
        longitude,
        campus.latitude,
        campus.longitude,
      );
      if (distance <= campus.radiusMeters + tolerance) {
        print('📍 Student is within ${campus.name} campus zone');
        return campus.id;
      }
    }

    print('⚠️ User is not near any registered campus');
    return null;
  }

  /// Calculates distance between two points in meters using Haversine formula.
  double _calculateDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371000; // Earth radius in meters
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _degToRad(double deg) => deg * pi / 180;
}
