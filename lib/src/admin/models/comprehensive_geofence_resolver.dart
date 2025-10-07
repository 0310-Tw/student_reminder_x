/// Comprehensive Geofence Profile Resolver
/// Combines set days, fallback locations, and custom student locations
/// to provide admins with complete visibility into student geofence configurations

import 'package:cloud_firestore/cloud_firestore.dart';

enum LocationSource {
  setDay, // Mandatory Wed/Thu days
  fallback, // Default campus locations
  studentCustom, // Student's own custom locations
  adminOverride, // Admin-set overrides for students
}

enum GeofenceBandType {
  fixed, // Must be within designated geofence
  floating, // May clock in/out anywhere
}

class GeofenceLocationInfo {
  final String day;
  final double lat;
  final double lng;
  final double radius;
  final LocationSource source;
  final String description;
  final GeofenceBandType bandType;
  final String? outsideAreaMessage;

  GeofenceLocationInfo({
    required this.day,
    required this.lat,
    required this.lng,
    required this.radius,
    required this.source,
    required this.description,
    this.bandType = GeofenceBandType.fixed,
    this.outsideAreaMessage,
  });

  String get sourceDisplay {
    switch (source) {
      case LocationSource.setDay:
        return 'Set Day';
      case LocationSource.fallback:
        return 'Fallback';
      case LocationSource.studentCustom:
        return 'Student Custom';
      case LocationSource.adminOverride:
        return 'Admin Override';
    }
  }

  String get bandTypeDisplay {
    switch (bandType) {
      case GeofenceBandType.fixed:
        return 'Fixed Band';
      case GeofenceBandType.floating:
        return 'Floating Band';
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

      // Get student's geofence profiles from the new subcollection
      final geofenceProfilesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('geofence_profiles')
          .get();

      Map<String, Map<String, dynamic>> profilesData = {};
      for (final doc in geofenceProfilesSnapshot.docs) {
        profilesData[doc.id] = doc.data();
      }

      // Process each weekday
      for (final day in allWeekdays) {
        GeofenceLocationInfo locationInfo;

        if (profilesData.containsKey(day)) {
          // Student has profile for this day
          final profileData = profilesData[day]!;
          final source = profileData['source']?.toString();

          locationInfo = GeofenceLocationInfo(
            day: day,
            lat: _extractDouble(profileData['latitude']) ?? 0.0,
            lng: _extractDouble(profileData['longitude']) ?? 0.0,
            radius: _extractDouble(profileData['radius']) ?? 100.0,
            source: source == 'studentCustom'
                ? LocationSource.studentCustom
                : source == 'adminOverride'
                ? LocationSource.adminOverride
                : LocationSource.setDay,
            description: profileData['description'] ?? 'Location for $day',
            bandType: _parseBandType(profileData['bandType']),
            outsideAreaMessage: profileData['outsideAreaMessage']?.toString(),
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
            bandType: GeofenceBandType.fixed, // Set days are always fixed
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
            bandType: GeofenceBandType.fixed, // Fallback locations are fixed
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
      final geofenceProfilesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('geofence_profiles')
          .get();

      Map<String, Map<String, dynamic>> profilesData = {};
      for (final doc in geofenceProfilesSnapshot.docs) {
        profilesData[doc.id] = doc.data();
      }

      return setDays.any(
        (setDay) =>
            profilesData.containsKey(setDay) &&
            profilesData[setDay]!['source'] == 'studentCustom',
      );
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

  GeofenceBandType _parseBandType(dynamic value) {
    if (value?.toString().toLowerCase() == 'floating') {
      return GeofenceBandType.floating;
    }
    return GeofenceBandType.fixed; // Default to fixed
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
