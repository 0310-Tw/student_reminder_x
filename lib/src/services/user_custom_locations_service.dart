import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:students_reminder/src/services/auth_service.dart';

/// Service for managing user's custom geofence locations
/// Follows the existing pattern used in GeofenceService by storing locations
/// directly in users/{userId} document under 'geofences' field
class UserCustomLocationsService {
  static final UserCustomLocationsService _instance =
      UserCustomLocationsService._internal();
  factory UserCustomLocationsService() => _instance;
  UserCustomLocationsService._internal();

  static UserCustomLocationsService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Valid weekdays for geofence configuration
  static const List<String> validDays = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
  ];

  /// Save a custom geofence location for a specific day
  /// Follows the existing GeofenceService.saveGeofence pattern
  Future<void> saveCustomLocation({
    required String day,
    required double latitude,
    required double longitude,
    double radius = 100.0,
    String? userId,
  }) async {
    try {
      final uid = userId ?? AuthService.instance.currentUser?.uid;
      if (uid == null) {
        throw Exception('No authenticated user found');
      }

      if (!isValidDay(day)) {
        throw Exception('Invalid day: $day. Must be monday-friday.');
      }

      await _firestore.collection('users').doc(uid).set({
        "geofences": {
          day.toLowerCase(): {
            "lat": latitude,
            "lng": longitude,
            "radius": radius,
          },
        },
      }, SetOptions(merge: true));

      print(
        '✅ Saved custom location for $day: lat=$latitude, lng=$longitude, radius=$radius',
      );
    } catch (e) {
      print('❌ Error saving custom location: $e');
      rethrow;
    }
  }

  /// Get custom geofence location for a specific day
  /// Follows the existing GeofenceService.getGeofence pattern
  Future<Map<String, dynamic>?> getCustomLocation(
    String day, [
    String? userId,
  ]) async {
    try {
      final uid = userId ?? AuthService.instance.currentUser?.uid;
      if (uid == null) {
        throw Exception('No authenticated user found');
      }

      final snapshot = await _firestore.collection('users').doc(uid).get();
      if (!snapshot.exists) {
        print('❌ User document does not exist');
        return null;
      }

      final data = snapshot.data();
      if (data == null || data["geofences"] == null) {
        print('❌ No geofences field in user document');
        return null;
      }

      final geofences = data["geofences"] as Map<String, dynamic>;
      final dayData = geofences[day.toLowerCase()] as Map<String, dynamic>?;

      if (dayData != null) {
        print('✅ Found custom location for $day: $dayData');
      } else {
        print('📍 No custom location found for $day');
      }

      return dayData;
    } catch (e) {
      print('❌ Error getting custom location: $e');
      return null;
    }
  }

  /// Get all custom geofence locations for the user
  /// Follows the existing GeofenceService.getAllGeofences pattern
  Future<Map<String, Map<String, dynamic>>> getAllCustomLocations([
    String? userId,
  ]) async {
    try {
      final uid = userId ?? AuthService.instance.currentUser?.uid;
      if (uid == null) {
        throw Exception('No authenticated user found');
      }

      final snapshot = await _firestore.collection('users').doc(uid).get();
      final Map<String, Map<String, dynamic>> result = {};

      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        if (data["geofences"] != null) {
          final geofences = data["geofences"] as Map<String, dynamic>;

          for (final day in validDays) {
            if (geofences[day] != null) {
              result[day] = Map<String, dynamic>.from(geofences[day]);
            }
          }

          print('✅ Loaded ${result.length} custom locations');
        } else {
          print('📍 No geofences field found');
        }
      } else {
        print('❌ User document does not exist');
      }

      return result;
    } catch (e) {
      print('❌ Error getting all custom locations: $e');
      return {};
    }
  }

  /// Watch custom locations as a stream for real-time updates
  Stream<Map<String, Map<String, dynamic>>> watchCustomLocations([
    String? userId,
  ]) {
    try {
      final uid = userId ?? AuthService.instance.currentUser?.uid;
      if (uid == null) {
        throw Exception('No authenticated user found');
      }

      return _firestore.collection('users').doc(uid).snapshots().map((
        snapshot,
      ) {
        final Map<String, Map<String, dynamic>> result = {};

        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data()!;
          if (data["geofences"] != null) {
            final geofences = data["geofences"] as Map<String, dynamic>;

            for (final day in validDays) {
              if (geofences[day] != null) {
                result[day] = Map<String, dynamic>.from(geofences[day]);
              }
            }
          }
        }

        return result;
      });
    } catch (e) {
      print('❌ Error watching custom locations: $e');
      return Stream.value({});
    }
  }

  /// Delete a custom location for a specific day
  Future<void> deleteCustomLocation(String day, [String? userId]) async {
    try {
      final uid = userId ?? AuthService.instance.currentUser?.uid;
      if (uid == null) {
        throw Exception('No authenticated user found');
      }

      if (!isValidDay(day)) {
        throw Exception('Invalid day: $day');
      }

      await _firestore.collection('users').doc(uid).update({
        "geofences.$day": FieldValue.delete(),
      });

      print('✅ Deleted custom location for $day');
    } catch (e) {
      print('❌ Error deleting custom location: $e');
      rethrow;
    }
  }

  /// Update an existing custom location
  Future<void> updateCustomLocation({
    required String day,
    double? latitude,
    double? longitude,
    double? radius,
    String? userId,
  }) async {
    try {
      final uid = userId ?? AuthService.instance.currentUser?.uid;
      if (uid == null) {
        throw Exception('No authenticated user found');
      }

      if (!isValidDay(day)) {
        throw Exception('Invalid day: $day');
      }

      // Get current location data
      final currentLocation = await getCustomLocation(day, uid);
      if (currentLocation == null) {
        throw Exception('No existing location found for $day');
      }

      // Update with new values or keep existing ones
      final updatedLocation = {
        "lat": latitude ?? _extractDouble(currentLocation['lat']) ?? 0.0,
        "lng": longitude ?? _extractDouble(currentLocation['lng']) ?? 0.0,
        "radius": radius ?? _extractDouble(currentLocation['radius']) ?? 100.0,
      };

      await _firestore.collection('users').doc(uid).update({
        "geofences.$day": updatedLocation,
      });

      print('✅ Updated custom location for $day: $updatedLocation');
    } catch (e) {
      print('❌ Error updating custom location: $e');
      rethrow;
    }
  }

  /// Search custom locations by proximity to a point
  Future<List<Map<String, dynamic>>> getCustomLocationsNearby({
    required double centerLat,
    required double centerLng,
    required double maxDistanceKm,
    String? userId,
  }) async {
    try {
      final locations = await getAllCustomLocations(userId);
      final List<Map<String, dynamic>> nearbyLocations = [];

      for (final entry in locations.entries) {
        final day = entry.key;
        final locationData = entry.value;

        final lat = _extractDouble(locationData['lat']);
        final lng = _extractDouble(locationData['lng']);
        final radius = _extractDouble(locationData['radius']);

        if (lat != null && lng != null && radius != null) {
          final distance = _calculateDistance(centerLat, centerLng, lat, lng);

          if (distance <= maxDistanceKm) {
            nearbyLocations.add({
              'day': day,
              'lat': lat,
              'lng': lng,
              'radius': radius,
              'distance': distance,
            });
          }
        }
      }

      // Sort by distance
      nearbyLocations.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
      );

      return nearbyLocations;
    } catch (e) {
      print('❌ Error getting nearby custom locations: $e');
      return [];
    }
  }

  /// Get statistics about user's custom locations
  Future<Map<String, dynamic>> getCustomLocationStats([String? userId]) async {
    try {
      final locations = await getAllCustomLocations(userId);

      if (locations.isEmpty) {
        return {
          'totalLocations': 0,
          'averageRadius': 0.0,
          'daysConfigured': <String>[],
          'daysNotConfigured': List<String>.from(validDays),
        };
      }

      final radiusList = <double>[];
      final configuredDays = <String>[];

      for (final entry in locations.entries) {
        final day = entry.key;
        final locationData = entry.value;

        final radius = _extractDouble(locationData['radius']);
        if (radius != null) {
          radiusList.add(radius);
          configuredDays.add(day);
        }
      }

      final averageRadius = radiusList.isNotEmpty
          ? radiusList.reduce((a, b) => a + b) / radiusList.length
          : 0.0;

      final notConfiguredDays = validDays
          .where((day) => !configuredDays.contains(day))
          .toList();

      return {
        'totalLocations': locations.length,
        'averageRadius': averageRadius,
        'daysConfigured': configuredDays,
        'daysNotConfigured': notConfiguredDays,
      };
    } catch (e) {
      print('❌ Error getting custom location stats: $e');
      return {
        'totalLocations': 0,
        'averageRadius': 0.0,
        'daysConfigured': <String>[],
        'daysNotConfigured': List<String>.from(validDays),
      };
    }
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth radius in kilometers

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// Helper method to safely extract double values
  double? _extractDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return null;
  }

  /// Check if a day is valid for geofence configuration
  static bool isValidDay(String day) {
    return validDays.contains(day.toLowerCase());
  }

  /// Get a formatted list of all configured custom locations
  Future<List<Map<String, dynamic>>> getFormattedCustomLocations([
    String? userId,
  ]) async {
    try {
      final locations = await getAllCustomLocations(userId);
      final List<Map<String, dynamic>> formatted = [];

      for (final entry in locations.entries) {
        final day = entry.key;
        final locationData = entry.value;

        final lat = _extractDouble(locationData['lat']);
        final lng = _extractDouble(locationData['lng']);
        final radius = _extractDouble(locationData['radius']);

        if (lat != null && lng != null && radius != null) {
          formatted.add({
            'day': day,
            'dayName': _getDayDisplayName(day),
            'latitude': lat,
            'longitude': lng,
            'radius': radius,
            'coordinates':
                '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
            'radiusText': '${radius.toInt()}m',
          });
        }
      }

      // Sort by weekday order
      final dayOrder = {
        'monday': 1,
        'tuesday': 2,
        'wednesday': 3,
        'thursday': 4,
        'friday': 5,
      };

      formatted.sort(
        (a, b) =>
            (dayOrder[a['day']] ?? 999).compareTo(dayOrder[b['day']] ?? 999),
      );

      return formatted;
    } catch (e) {
      print('❌ Error formatting custom locations: $e');
      return [];
    }
  }

  /// Get display name for a day
  String _getDayDisplayName(String day) {
    switch (day.toLowerCase()) {
      case 'monday':
        return 'Monday';
      case 'tuesday':
        return 'Tuesday';
      case 'wednesday':
        return 'Wednesday';
      case 'thursday':
        return 'Thursday';
      case 'friday':
        return 'Friday';
      default:
        return day;
    }
  }

  /// Check if user has any custom locations configured
  Future<bool> hasCustomConfigurations([String? userId]) async {
    try {
      final locations = await getAllCustomLocations(userId);
      return locations.isNotEmpty;
    } catch (e) {
      print('❌ Error checking custom configurations: $e');
      return false;
    }
  }

  /// Get configuration summary for current user
  Future<String> getConfigurationSummary([String? userId]) async {
    try {
      final uid = userId ?? AuthService.instance.currentUser?.uid;
      if (uid == null) {
        return 'Error: No authenticated user found';
      }

      final locations = await getAllCustomLocations(uid);
      final stats = await getCustomLocationStats(uid);

      final configuredDays = stats['daysConfigured'] as List<String>;
      final notConfiguredDays = stats['daysNotConfigured'] as List<String>;
      final averageRadius = stats['averageRadius'] as double;

      return '''
Custom Geofence Configuration Summary

User ID: $uid
Total Custom Locations: ${locations.length}
Average Radius: ${averageRadius.toInt()}m

Configured Days:
${configuredDays.map((day) => '- ${_getDayDisplayName(day)}').join('\n')}

Not Configured:
${notConfiguredDays.map((day) => '- ${_getDayDisplayName(day)}').join('\n')}

Configuration loaded successfully.''';
    } catch (e) {
      return 'Error getting configuration summary: $e';
    }
  }

  /// Bulk operations for admin use

  /// Get all users' custom locations (admin only)
  Future<Map<String, Map<String, Map<String, dynamic>>>>
  getAllUsersCustomLocations() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      final Map<String, Map<String, Map<String, dynamic>>> allLocations = {};

      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final locations = await getAllCustomLocations(userId);
        if (locations.isNotEmpty) {
          allLocations[userId] = locations;
        }
      }

      print('✅ Loaded custom locations for ${allLocations.length} users');
      return allLocations;
    } catch (e) {
      print('❌ Error getting all users custom locations: $e');
      return {};
    }
  }

  /// Get custom locations statistics across all users (admin only)
  Future<Map<String, dynamic>> getGlobalCustomLocationStats() async {
    try {
      final allUsersLocations = await getAllUsersCustomLocations();

      int totalLocations = 0;
      double totalRadius = 0.0;
      final Map<String, int> dayFrequency = {};

      for (final userLocations in allUsersLocations.values) {
        totalLocations += userLocations.length;

        for (final entry in userLocations.entries) {
          final locationData = entry.value;
          final radius = _extractDouble(locationData['radius']) ?? 0.0;
          totalRadius += radius;

          final day = entry.key;
          dayFrequency[day] = (dayFrequency[day] ?? 0) + 1;
        }
      }

      final averageRadius = totalLocations > 0
          ? totalRadius / totalLocations
          : 0.0;

      String mostConfiguredDay = 'none';
      if (dayFrequency.isNotEmpty) {
        mostConfiguredDay = dayFrequency.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
      }

      return {
        'totalUsers': allUsersLocations.length,
        'totalLocations': totalLocations,
        'averageRadius': averageRadius,
        'dayFrequency': dayFrequency,
        'mostConfiguredDay': mostConfiguredDay,
        'averageLocationsPerUser': allUsersLocations.isNotEmpty
            ? totalLocations / allUsersLocations.length
            : 0.0,
      };
    } catch (e) {
      print('❌ Error getting global custom location stats: $e');
      return {
        'totalUsers': 0,
        'totalLocations': 0,
        'averageRadius': 0.0,
        'dayFrequency': <String, int>{},
        'mostConfiguredDay': 'none',
        'averageLocationsPerUser': 0.0,
      };
    }
  }
}
