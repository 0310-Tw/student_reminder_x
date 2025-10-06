/// Advanced Geofence Integration Helper
///
/// This service provides integration between the existing GeofenceService
/// and the new advanced geofencing system without modifying the core service.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:students_reminder/src/admin/models/advanced_attendance_service.dart';
import 'package:students_reminder/src/admin/models/advanced_geofence_models.dart';

import '../../admin/models/advanced_geofence_models.dart' as advanced;
import '../../admin/models/effective_geofence_resolver.dart';
import '../../admin/models/advanced_attendance_service.dart' as attendance;
import '../../admin/models/geofence_profile_service.dart';
import '../../services/auth_service.dart';
import 'geofence_service.dart';

/// Service that bridges existing geofencing with advanced features
class AdvancedGeofenceIntegration {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Record attendance using the advanced geofencing system
  static Future<attendance.AttendanceResult> recordAdvancedAttendance({
    required Position currentPosition,
    required DateTime scheduledStart,
    required int graceMinutes,
    required attendance.AttendanceType attendanceType,
  }) async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) {
        return attendance.AttendanceResult.error('User not authenticated');
      }

      // Create organization defaults from campus service
      final orgDefaults = await _createOrgDefaults();

      return await attendance.AdvancedAttendanceService.recordAttendance(
        userId: user.uid,
        currentPosition: currentPosition,
        scheduledStart: scheduledStart,
        graceMinutes: graceMinutes,
        attendanceType: attendanceType,
        orgDefaults: orgDefaults,
      );
    } catch (e) {
      print('Error recording advanced attendance: $e');
      return attendance.AttendanceResult.error(
        'Failed to record attendance: $e',
      );
    }
  }

  /// Get effective geofence for current user and day
  static Future<advanced.EffectiveGeofence?>
  getCurrentEffectiveGeofence() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return null;

      final userProfile = await _loadUserProfile(user.uid);
      if (userProfile == null) return null;

      final orgDefaults = await _createOrgDefaults();
      final currentDay = GeofenceResolutionUtils.getCurrentDayOfWeek();

      return await EffectiveGeofenceResolver.resolveEffectiveGeofence(
        user: userProfile,
        dow: currentDay,
        defaults: orgDefaults,
      );
    } catch (e) {
      print('Error getting effective geofence: $e');
      return null;
    }
  }

  /// Get effective geofence for specific day
  static Future<advanced.EffectiveGeofence?> getEffectiveGeofenceForDay(
    int dayOfWeek,
  ) async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return null;

      final userProfile = await _loadUserProfile(user.uid);
      if (userProfile == null) return null;

      final orgDefaults = await _createOrgDefaults();

      return await EffectiveGeofenceResolver.resolveEffectiveGeofence(
        user: userProfile,
        dow: dayOfWeek,
        defaults: orgDefaults,
      );
    } catch (e) {
      print('Error getting effective geofence for day $dayOfWeek: $e');
      return null;
    }
  }

  /// Get weekly effective geofence configuration
  static Future<Map<int, advanced.EffectiveGeofence>?>
  getWeeklyEffectiveGeofences() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return null;

      final userProfile = await _loadUserProfile(user.uid);
      if (userProfile == null) return null;

      final orgDefaults = await _createOrgDefaults();

      return await EffectiveGeofenceResolver.resolveForWeek(
        user: userProfile,
        defaults: orgDefaults,
      );
    } catch (e) {
      print('Error getting weekly effective geofences: $e');
      return null;
    }
  }

  /// Check attendance status at current location
  static Future<advanced.AttStatus?> checkAttendanceStatus({
    required DateTime scheduledStart,
    required int graceMinutes,
    required advanced.GeofenceSlot slot,
  }) async {
    try {
      final position = await GeofenceService.instance.getCurrentLocation();
      final effectiveGeofence = await getCurrentEffectiveGeofence();
      if (effectiveGeofence == null) return null;

      final targetGeofence = slot == advanced.GeofenceSlot.checkIn
          ? effectiveGeofence.checkIn
          : effectiveGeofence.checkOut;

      final distance = targetGeofence.distanceTo(
        position.latitude,
        position.longitude,
      );

      return advanced.resolveStatus(
        now: DateTime.now(),
        start: scheduledStart,
        graceMinutes: graceMinutes,
        distanceMeters: distance,
        radiusMeters: targetGeofence.radiusMeters,
      );
    } catch (e) {
      print('Error checking attendance status: $e');
      return null;
    }
  }

  /// Get attendance history using advanced service
  static Future<List<attendance.AttendanceRecord>>
  getAdvancedAttendanceHistory({
    DateTime? startDate,
    DateTime? endDate,
    advanced.AttStatus? statusFilter,
    attendance.AttendanceType? typeFilter,
    int limit = 50,
  }) async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return [];

      return await attendance.AdvancedAttendanceService.getAttendanceHistory(
        userId: user.uid,
        startDate: startDate,
        endDate: endDate,
        statusFilter: statusFilter,
        typeFilter: typeFilter,
        limit: limit,
      );
    } catch (e) {
      print('Error getting attendance history: $e');
      return [];
    }
  }

  /// Get flagged attendance records for administrative review
  static Future<List<attendance.AttendanceRecord>> getFlaggedAttendance({
    DateTime? since,
    int limit = 100,
  }) async {
    return await attendance.AdvancedAttendanceService.getFlaggedAttendance(
      since: since,
      limit: limit,
    );
  }

  /// Calculate attendance statistics for current user
  static Future<attendance.AttendanceStatistics?>
  calculateAttendanceStatistics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return null;

      return await attendance.AdvancedAttendanceService.calculateStatistics(
        userId: user.uid,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      print('Error calculating attendance statistics: $e');
      return null;
    }
  }

  /// Create organization defaults from existing campus service
  static Future<advanced.OrgDefaults> _createOrgDefaults() async {
    final campusMap = <String, advanced.CampusLocation>{};
    final geofenceService = GeofenceService.instance;

    try {
      // Get campus locations from existing service
      final upPark = geofenceService.getCampusLocation('up_park');
      final stonyHill = geofenceService.getCampusLocation('stony_hill');

      if (upPark != null) {
        campusMap['up_park'] = advanced.CampusLocation(
          lat: upPark.latitude,
          lng: upPark.longitude,
          defaultRadiusMeters: upPark.radiusMeters,
          name: upPark.name,
          slug: 'up_park',
        );
      } else {
        // Fallback default for Up Park
        campusMap['up_park'] = const advanced.CampusLocation(
          lat: 18.0179,
          lng: -76.7449,
          defaultRadiusMeters: 100.0,
          name: 'Up Park',
          slug: 'up_park',
        );
      }

      if (stonyHill != null) {
        campusMap['stony_hill'] = advanced.CampusLocation(
          lat: stonyHill.latitude,
          lng: stonyHill.longitude,
          defaultRadiusMeters: stonyHill.radiusMeters,
          name: stonyHill.name,
          slug: 'stony_hill',
        );
      } else {
        // Fallback default for Stony Hill
        campusMap['stony_hill'] = const advanced.CampusLocation(
          lat: 18.0589,
          lng: -76.7676,
          defaultRadiusMeters: 100.0,
          name: 'Stony Hill',
          slug: 'stony_hill',
        );
      }

      return advanced.OrgDefaults(campusMap);
    } catch (e) {
      print('Error creating org defaults: $e');
      // Return minimal defaults if there's an error
      return advanced.OrgDefaults({
        'up_park': const advanced.CampusLocation(
          lat: 18.0179,
          lng: -76.7449,
          defaultRadiusMeters: 100.0,
          name: 'Up Park',
          slug: 'up_park',
        ),
        'stony_hill': const advanced.CampusLocation(
          lat: 18.0589,
          lng: -76.7676,
          defaultRadiusMeters: 100.0,
          name: 'Stony Hill',
          slug: 'stony_hill',
        ),
      });
    }
  }

  /// Load user profile for advanced geofencing
  static Future<advanced.UserProfile?> _loadUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists || doc.data() == null) {
        // Return default profile if user data doesn't exist
        return advanced.UserProfile(
          uid: userId,
          bandType: advanced.BandType.fixed,
          outsideMessageEnabled: false,
        );
      }

      final data = doc.data()!;
      return advanced.UserProfile.fromMap(data, userId);
    } catch (e) {
      print('Error loading user profile: $e');
      // Return default profile on error
      return advanced.UserProfile(
        uid: userId,
        bandType: advanced.BandType.fixed,
        outsideMessageEnabled: false,
      );
    }
  }

  /// Migrate legacy geofence data to advanced system
  static Future<bool> migrateLegacyGeofences() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return false;

      // Get existing geofences from the simplified format
      final allGeofences = await GeofenceService.instance.getAllGeofences(
        user.uid,
      );

      if (allGeofences.isEmpty) return true; // Nothing to migrate

      // Convert to geofence profiles
      for (final entry in allGeofences.entries) {
        final day = entry.key;
        final geofenceData = entry.value;

        final lat = _extractDouble(geofenceData['lat']);
        final lng = _extractDouble(geofenceData['lng']);
        final radius = _extractDouble(geofenceData['radius']);

        if (lat != null && lng != null && radius != null) {
          // Convert day name to day of week number
          final dayOfWeek = _dayNameToDayOfWeek(day);
          if (dayOfWeek != null) {
            final slotConfig = advanced.GeofenceSlotConfig(
              lat: lat,
              lng: lng,
              radiusMeters: radius,
            );

            // Create profile with both check-in and check-out using same location
            final profile = GeofenceProfile(
              dayOfWeek: dayOfWeek,
              userId: user.uid,
              checkInSlot: slotConfig,
              checkOutSlot: slotConfig,
            );

            await GeofenceProfileService.saveGeofenceProfile(profile);
          }
        }
      }

      return true;
    } catch (e) {
      print('Error migrating legacy geofences: $e');
      return false;
    }
  }

  /// Extract double value safely
  static double? _extractDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return null;
  }

  /// Convert day name to day of week number
  static int? _dayNameToDayOfWeek(String dayName) {
    switch (dayName.toLowerCase()) {
      case 'sunday':
        return 0;
      case 'monday':
        return 1;
      case 'tuesday':
        return 2;
      case 'wednesday':
        return 3;
      case 'thursday':
        return 4;
      case 'friday':
        return 5;
      case 'saturday':
        return 6;
      default:
        return null;
    }
  }

  /// Convert day of week number to day name
  static String dayOfWeekToName(int dayOfWeek) {
    const dayNames = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];

    if (dayOfWeek >= 0 && dayOfWeek < dayNames.length) {
      return dayNames[dayOfWeek];
    }
    return 'Unknown';
  }

  /// Check if user has custom geofence configurations
  static Future<bool> hasCustomConfigurations() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return false;

      return await EffectiveGeofenceResolver.hasCustomConfigurations(user.uid);
    } catch (e) {
      print('Error checking custom configurations: $e');
      return false;
    }
  }

  /// Get configuration summary for current user
  static Future<String> getSystemConfigurationSummary() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return 'No user authenticated';

      final userProfile = await _loadUserProfile(user.uid);
      if (userProfile == null) return 'Could not load user profile';

      final orgDefaults = await _createOrgDefaults();
      final hasCustom = await hasCustomConfigurations();

      return '''Advanced Geofencing System Configuration

User: ${user.uid}
Has Custom Geofences: ${hasCustom ? 'Yes' : 'No'}
Band Type: ${userProfile.bandType}
Outside Message Enabled: ${userProfile.outsideMessageEnabled}

Available Campuses:
${orgDefaults.availableCampuses.map((slug) => '- $slug').join('\n')}

Configuration loaded successfully.''';
    } catch (e) {
      return 'Error getting configuration summary: $e';
    }
  }

  /// Test geofence setup with current location
  static Future<GeofenceTestResult> testGeofenceSetup() async {
    try {
      final position = await GeofenceService.instance.getCurrentLocation();
      final effectiveGeofence = await getCurrentEffectiveGeofence();

      if (effectiveGeofence == null) {
        return GeofenceTestResult(
          success: false,
          message: 'Could not load effective geofence configuration',
        );
      }

      final checkInDistance = effectiveGeofence.checkIn.distanceTo(
        position.latitude,
        position.longitude,
      );

      final checkOutDistance = effectiveGeofence.checkOut.distanceTo(
        position.latitude,
        position.longitude,
      );

      final withinCheckIn =
          checkInDistance <= effectiveGeofence.checkIn.radiusMeters;
      final withinCheckOut =
          checkOutDistance <= effectiveGeofence.checkOut.radiusMeters;

      return GeofenceTestResult(
        success: true,
        message: 'Geofence test completed successfully',
        currentPosition: attendance.LocationPoint(
          lat: position.latitude,
          lng: position.longitude,
        ),
        checkInDistance: checkInDistance,
        checkOutDistance: checkOutDistance,
        withinCheckInRadius: withinCheckIn,
        withinCheckOutRadius: withinCheckOut,
        effectiveGeofence: effectiveGeofence,
      );
    } catch (e) {
      return GeofenceTestResult(
        success: false,
        message: 'Error testing geofence setup: $e',
      );
    }
  }
}

/// Result of geofence testing
class GeofenceTestResult {
  final bool success;
  final String message;
  final attendance.LocationPoint? currentPosition;
  final double? checkInDistance;
  final double? checkOutDistance;
  final bool? withinCheckInRadius;
  final bool? withinCheckOutRadius;
  final advanced.EffectiveGeofence? effectiveGeofence;

  const GeofenceTestResult({
    required this.success,
    required this.message,
    this.currentPosition,
    this.checkInDistance,
    this.checkOutDistance,
    this.withinCheckInRadius,
    this.withinCheckOutRadius,
    this.effectiveGeofence,
  });

  /// Get a detailed test report
  String get detailedReport {
    if (!success) return message;

    final buffer = StringBuffer();
    buffer.writeln('=== Geofence Test Report ===');
    buffer.writeln(
      'Current Position: ${currentPosition?.lat}, ${currentPosition?.lng}',
    );
    buffer.writeln(
      'Check-in Radius: ${effectiveGeofence?.checkIn.radiusMeters}m',
    );
    buffer.writeln(
      'Check-out Radius: ${effectiveGeofence?.checkOut.radiusMeters}m',
    );
    buffer.writeln('');

    if (checkInDistance != null) {
      buffer.writeln(
        'Check-in Distance: ${advanced.prettyDistance(checkInDistance!)}',
      );
      buffer.writeln(
        'Within Check-in Radius: ${withinCheckInRadius == true ? "YES" : "NO"}',
      );
    }

    if (checkOutDistance != null) {
      buffer.writeln(
        'Check-out Distance: ${advanced.prettyDistance(checkOutDistance!)}',
      );
      buffer.writeln(
        'Within Check-out Radius: ${withinCheckOutRadius == true ? "YES" : "NO"}',
      );
    }

    return buffer.toString();
  }
}
