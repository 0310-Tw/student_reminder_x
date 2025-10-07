/// Comprehensive Geofence Profile Resolver
/// Combines set days, fallback locations, and custom student locations
/// to provide admins with complete visibility into student geofence configurations

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:students_reminder/src/services/user_custom_locations_service.dart';

enum LocationSource {
  setDay, // Mandatory Wed/Thu days
  fallback, // Default campus locations
  studentCustom, // Student's own custom locations
}

class GeofenceLocationInfo {
  final String day;
  final double lat;
  final double lng;
  final double radius;
  final LocationSource source;
  final String description;

  GeofenceLocationInfo({
    required this.day,
    required this.lat,
    required this.lng,
    required this.radius,
    required this.source,
    required this.description,
  });

  String get sourceDisplay {
    switch (source) {
      case LocationSource.setDay:
        return 'Set Day';
      case LocationSource.fallback:
        return 'Fallback';
      case LocationSource.studentCustom:
        return 'Student Custom';
    }
  }
}

class ComprehensiveGeofenceProfile {
  final String userId;
  final List<GeofenceLocationInfo> locations;
  final DateTime generatedAt;

  ComprehensiveGeofenceProfile({
    required this.userId,
    required this.locations,
    required this.generatedAt,
  });

  List<GeofenceLocationInfo> get setDayLocations =>
      locations.where((l) => l.source == LocationSource.setDay).toList();

  List<GeofenceLocationInfo> get fallbackLocations =>
      locations.where((l) => l.source == LocationSource.fallback).toList();

  List<GeofenceLocationInfo> get studentCustomLocations =>
      locations.where((l) => l.source == LocationSource.studentCustom).toList();

  int get totalActiveLocations => locations.length;
}

class ComprehensiveGeofenceResolver {
  static final ComprehensiveGeofenceResolver _instance =
      ComprehensiveGeofenceResolver._internal();
  factory ComprehensiveGeofenceResolver() => _instance;
  ComprehensiveGeofenceResolver._internal();

  static ComprehensiveGeofenceResolver get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Default campus coordinates
  static const Map<String, Map<String, dynamic>> campusLocations = {
    'stony_hill': {
      'lat': 18.05,
      'lng': -76.82,
      'radius': 150.0,
      'name': 'Stony Hill Campus',
    },
    'up_park_camp': {
      'lat': 18.00,
      'lng': -76.80,
      'radius': 150.0,
      'name': 'Up Park Camp',
    },
  };

  /// Set days (mandatory attendance days)
  static const List<String> setDays = ['wednesday', 'thursday'];

  /// All valid weekdays
  static const List<String> allWeekdays = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
  ];

  /// Get comprehensive geofence profile for a student
  Future<ComprehensiveGeofenceProfile> getStudentComprehensiveProfile(
    String userId,
  ) async {
    try {
      final List<GeofenceLocationInfo> allLocations = [];

      // Get student's custom locations
      final customLocations = await UserCustomLocationsService.instance
          .getAllCustomLocations(userId);

      // Process each weekday
      for (final day in allWeekdays) {
        GeofenceLocationInfo locationInfo;

        if (customLocations.containsKey(day)) {
          // Student has custom location for this day
          final customData = customLocations[day]!;
          locationInfo = GeofenceLocationInfo(
            day: day,
            lat: _extractDouble(customData['lat']) ?? 0.0,
            lng: _extractDouble(customData['lng']) ?? 0.0,
            radius: _extractDouble(customData['radius']) ?? 100.0,
            source: LocationSource.studentCustom,
            description: 'Custom location set by student',
          );
        } else if (setDays.contains(day)) {
          // Set day - use Stony Hill campus
          final campus = campusLocations['stony_hill']!;
          locationInfo = GeofenceLocationInfo(
            day: day,
            lat: campus['lat'],
            lng: campus['lng'],
            radius: campus['radius'],
            source: LocationSource.setDay,
            description:
                'Mandatory ${_getDayDisplayName(day)} - ${campus['name']}',
          );
        } else {
          // Fallback day - use Up Park Camp
          final campus = campusLocations['up_park_camp']!;
          locationInfo = GeofenceLocationInfo(
            day: day,
            lat: campus['lat'],
            lng: campus['lng'],
            radius: campus['radius'],
            source: LocationSource.fallback,
            description: 'Default fallback - ${campus['name']}',
          );
        }

        allLocations.add(locationInfo);
      }

      return ComprehensiveGeofenceProfile(
        userId: userId,
        locations: allLocations,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      print('❌ Error getting comprehensive profile for $userId: $e');
      rethrow;
    }
  }

  /// Get effective location for a specific day (what's actually active)
  Future<GeofenceLocationInfo?> getEffectiveLocationForDay(
    String userId,
    String day,
  ) async {
    try {
      if (!allWeekdays.contains(day.toLowerCase())) {
        return null;
      }

      final profile = await getStudentComprehensiveProfile(userId);
      return profile.locations.firstWhere((l) => l.day == day.toLowerCase());
    } catch (e) {
      print('❌ Error getting effective location for $userId on $day: $e');
      return null;
    }
  }

  /// Get profile summary statistics
  Future<Map<String, dynamic>> getProfileSummary(String userId) async {
    try {
      final profile = await getStudentComprehensiveProfile(userId);

      return {
        'totalLocations': profile.totalActiveLocations,
        'setDayCount': profile.setDayLocations.length,
        'fallbackCount': profile.fallbackLocations.length,
        'studentCustomCount': profile.studentCustomLocations.length,
        'customizationPercentage':
            (profile.studentCustomLocations.length / allWeekdays.length * 100)
                .round(),
        'hasCustomizations': profile.studentCustomLocations.isNotEmpty,
        'generatedAt': profile.generatedAt.toIso8601String(),
      };
    } catch (e) {
      print('❌ Error getting profile summary for $userId: $e');
      return {};
    }
  }

  /// Get all students' comprehensive profiles (admin use)
  Future<List<ComprehensiveGeofenceProfile>> getAllStudentsProfiles() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      final List<ComprehensiveGeofenceProfile> allProfiles = [];

      for (final userDoc in usersSnapshot.docs) {
        try {
          final profile = await getStudentComprehensiveProfile(userDoc.id);
          allProfiles.add(profile);
        } catch (e) {
          print('⚠️ Error processing profile for ${userDoc.id}: $e');
        }
      }

      print(
        '✅ Generated comprehensive profiles for ${allProfiles.length} students',
      );
      return allProfiles;
    } catch (e) {
      print('❌ Error getting all students profiles: $e');
      return [];
    }
  }

  /// Get system-wide statistics
  Future<Map<String, dynamic>> getSystemStatistics() async {
    try {
      final allProfiles = await getAllStudentsProfiles();

      int totalStudents = allProfiles.length;
      int studentsWithCustomizations = 0;
      int totalCustomLocations = 0;
      Map<String, int> dayCustomizationCount = {};

      for (final profile in allProfiles) {
        if (profile.studentCustomLocations.isNotEmpty) {
          studentsWithCustomizations++;
          totalCustomLocations += profile.studentCustomLocations.length;

          for (final customLocation in profile.studentCustomLocations) {
            dayCustomizationCount[customLocation.day] =
                (dayCustomizationCount[customLocation.day] ?? 0) + 1;
          }
        }
      }

      // Find most customized day
      String mostCustomizedDay = 'none';
      if (dayCustomizationCount.isNotEmpty) {
        mostCustomizedDay = dayCustomizationCount.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
      }

      return {
        'totalStudents': totalStudents,
        'studentsWithCustomizations': studentsWithCustomizations,
        'customizationRate': totalStudents > 0
            ? (studentsWithCustomizations / totalStudents * 100).round()
            : 0,
        'totalCustomLocations': totalCustomLocations,
        'averageCustomizationsPerStudent': totalStudents > 0
            ? (totalCustomLocations / totalStudents).toStringAsFixed(1)
            : '0.0',
        'dayCustomizationBreakdown': dayCustomizationCount,
        'mostCustomizedDay': mostCustomizedDay,
        'setDaysCount': setDays.length,
        'fallbackDaysCount': allWeekdays.length - setDays.length,
      };
    } catch (e) {
      print('❌ Error getting system statistics: $e');
      return {};
    }
  }

  /// Check if student has overridden any set days
  Future<bool> hasOverriddenSetDays(String userId) async {
    try {
      final customLocations = await UserCustomLocationsService.instance
          .getAllCustomLocations(userId);
      return setDays.any((setDay) => customLocations.containsKey(setDay));
    } catch (e) {
      print('❌ Error checking set day overrides for $userId: $e');
      return false;
    }
  }

  /// Get locations by source type
  Future<List<GeofenceLocationInfo>> getLocationsBySource(
    String userId,
    LocationSource source,
  ) async {
    try {
      final profile = await getStudentComprehensiveProfile(userId);
      return profile.locations.where((l) => l.source == source).toList();
    } catch (e) {
      print('❌ Error getting locations by source for $userId: $e');
      return [];
    }
  }

  /// Utility methods

  double? _extractDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return null;
  }

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
}
