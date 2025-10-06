import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper service for managing geofence data in Firestore
/// Stores geofences in a clean Monday-Friday format:
/// {
///   "monday": { "lat": 18.123, "lng": -76.456, "radius": 100 },
///   "tuesday": { "lat": 18.234, "lng": -76.567, "radius": 150 },
///   ...
/// }
class GeofenceDataService {
  static const String _collection = 'user_geofences';
  static const List<String> _validDays = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
  ];

  /// Save a geofence for a specific day
  /// Uses SetOptions(merge: true) to preserve other days
  static Future<void> saveGeofence(
    String userId,
    String day,
    double lat,
    double lng,
    double radius,
  ) async {
    // Validate day
    if (!_validDays.contains(day.toLowerCase())) {
      throw ArgumentError(
        'Invalid day: $day. Only Monday-Friday are supported.',
      );
    }

    // Validate coordinates and radius
    if (lat < -90 || lat > 90) {
      throw ArgumentError(
        'Invalid latitude: $lat. Must be between -90 and 90.',
      );
    }
    if (lng < -180 || lng > 180) {
      throw ArgumentError(
        'Invalid longitude: $lng. Must be between -180 and 180.',
      );
    }
    if (radius <= 0) {
      throw ArgumentError('Invalid radius: $radius. Must be greater than 0.');
    }

    try {
      await FirebaseFirestore.instance.collection(_collection).doc(userId).set({
        day.toLowerCase(): {
          'lat': lat,
          'lng': lng,
          'radius': radius,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to save geofence for $day: $e');
    }
  }

  /// Get a geofence for a specific day
  /// Returns null if no geofence is set for the day
  static Future<Map<String, dynamic>?> getGeofence(
    String userId,
    String day,
  ) async {
    // Validate day
    if (!_validDays.contains(day.toLowerCase())) {
      throw ArgumentError(
        'Invalid day: $day. Only Monday-Friday are supported.',
      );
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(userId)
          .get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      final data = doc.data()!;
      final dayData = data[day.toLowerCase()];

      if (dayData == null) {
        return null;
      }

      // Safely cast and extract values
      if (dayData is Map<String, dynamic>) {
        final lat = _extractDouble(dayData['lat']);
        final lng = _extractDouble(dayData['lng']);
        final radius = _extractDouble(dayData['radius']);

        // Ensure all required fields are present and valid
        if (lat != null && lng != null && radius != null) {
          return {'lat': lat, 'lng': lng, 'radius': radius};
        }
      }

      return null;
    } catch (e) {
      throw Exception('Failed to get geofence for $day: $e');
    }
  }

  /// Get all geofences for Monday-Friday
  /// Returns a map with day names as keys and geofence data as values
  static Future<Map<String, Map<String, dynamic>>> getAllGeofences(
    String userId,
  ) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(userId)
          .get();

      if (!doc.exists || doc.data() == null) {
        return {};
      }

      final data = doc.data()!;
      final Map<String, Map<String, dynamic>> result = {};

      for (final day in _validDays) {
        final dayData = data[day];

        if (dayData != null && dayData is Map<String, dynamic>) {
          final lat = _extractDouble(dayData['lat']);
          final lng = _extractDouble(dayData['lng']);
          final radius = _extractDouble(dayData['radius']);

          // Only include days with complete, valid data
          if (lat != null && lng != null && radius != null) {
            result[day] = {'lat': lat, 'lng': lng, 'radius': radius};
          }
        }
      }

      return result;
    } catch (e) {
      throw Exception('Failed to get all geofences: $e');
    }
  }

  /// Remove a geofence for a specific day
  static Future<void> removeGeofence(String userId, String day) async {
    // Validate day
    if (!_validDays.contains(day.toLowerCase())) {
      throw ArgumentError(
        'Invalid day: $day. Only Monday-Friday are supported.',
      );
    }

    try {
      await FirebaseFirestore.instance
          .collection(_collection)
          .doc(userId)
          .update({day.toLowerCase(): FieldValue.delete()});
    } catch (e) {
      throw Exception('Failed to remove geofence for $day: $e');
    }
  }

  /// Clear all geofences for a user
  static Future<void> clearAllGeofences(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection(_collection)
          .doc(userId)
          .delete();
    } catch (e) {
      throw Exception('Failed to clear all geofences: $e');
    }
  }

  /// Helper method to safely extract double values from Firestore data
  /// Handles both double and num types, returns null if invalid
  static double? _extractDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return null;
  }

  /// Check if a day is valid (Monday-Friday)
  static bool isValidDay(String day) {
    return _validDays.contains(day.toLowerCase());
  }

  /// Get list of valid days
  static List<String> getValidDays() {
    return List.unmodifiable(_validDays);
  }
}
