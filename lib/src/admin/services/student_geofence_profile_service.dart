/// Enhanced Student Geofence Profile System
///
/// This service integrates with the existing attendance system to provide
/// per-student geofence profiles with default fallbacks and outside policy handling.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import '../models/advanced_geofence_models.dart';
import '../models/geofence_profile_service.dart';
import '../services/org_config_service.dart';
import '../services/geofence_incident_service.dart';
import '../models/geofence_incident_models.dart';

/// Enhanced profile service that resolves effective geofence configurations
class StudentGeofenceProfileService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Resolves the effective geofence configuration for a student on a specific day
  static Future<EffectiveGeofence> getEffectiveGeofence(
    String studentId,
    DateTime date,
  ) async {
    final dayOfWeek = date.weekday % 7; // Convert to 0-6 format
    
    // Try to get student-specific profile first
    final customProfile = await GeofenceProfileService.loadGeofenceProfile(
      studentId, 
      dayOfWeek
    );

    if (customProfile != null && customProfile.checkInSlot != null) {
      // Use custom profile
      return EffectiveGeofence(
        checkIn: customProfile.checkInSlot!.toGeofence(),
        checkOut: customProfile.checkOutSlot?.toGeofence() ?? 
                  customProfile.checkInSlot!.toGeofence(),
        bandType: customProfile.bandTypeOverride ?? BandType.fixed,
        outsidePolicy: customProfile.outsidePolicy ?? OutsidePolicy.block,
        outsideMessageText: customProfile.outsideMessageText,
      );
    }

    // Fall back to organization defaults
    final defaultCampusId = OrgConfigService.getDefaultCampusForDay(dayOfWeek);
    final defaultGeofence = await _createDefaultGeofence(defaultCampusId);
    
    return EffectiveGeofence(
      checkIn: defaultGeofence,
      checkOut: defaultGeofence,
      bandType: BandType.fixed, // Default to fixed
      outsidePolicy: OutsidePolicy.block, // Default to block
      outsideMessageText: null,
    );
  }

  /// Creates a default geofence based on campus configuration
  static Future<Geofence> _createDefaultGeofence(String campusId) async {
    // Default coordinates based on campus
    final Map<String, Map<String, double>> campusDefaults = {
      'stony_hill': {
        'lat': 18.0179,
        'lng': -76.7491,
        'radius': 100.0,
      },
      'up_park_camp': {
        'lat': 17.9778,
        'lng': -76.7947,
        'radius': 150.0,
      },
    };

    final coords = campusDefaults[campusId] ?? campusDefaults['up_park_camp']!;
    
    return Geofence(
      coords['lat']!,
      coords['lng']!,
      coords['radius']!,
      campusSlug: campusId,
    );
  }

  /// Validates attendance attempt against geofence rules
  static Future<GeofenceValidationResult> validateAttendanceAttempt({
    required String studentId,
    required DateTime date,
    required GeofenceSlot slot,
    required Position currentPosition,
    required BuildContext? context,
  }) async {
    final effective = await getEffectiveGeofence(studentId, date);
    final targetGeofence = slot == GeofenceSlot.checkIn 
        ? effective.checkIn 
        : effective.checkOut;

    final distance = targetGeofence.distanceTo(
      currentPosition.latitude, 
      currentPosition.longitude
    );
    
    final isInside = distance <= targetGeofence.radiusMeters;

    // If floating band, always allow
    if (effective.bandType == BandType.floating) {
      return GeofenceValidationResult(
        allowed: true,
        status: AttStatus.present,
        distance: distance,
        geofence: targetGeofence,
      );
    }

    // Fixed band logic
    if (isInside) {
      return GeofenceValidationResult(
        allowed: true,
        status: AttStatus.present,
        distance: distance,
        geofence: targetGeofence,
      );
    }

    // Outside geofence - handle based on policy
    if (effective.outsidePolicy == OutsidePolicy.block) {
      // Show message if provided
      if (effective.outsideMessageText != null && 
          effective.outsideMessageText!.isNotEmpty && 
          context != null) {
        await _showOutsideMessage(context, effective.outsideMessageText!);
      }
      
      return GeofenceValidationResult(
        allowed: false,
        status: AttStatus.outsideAttempt,
        distance: distance,
        geofence: targetGeofence,
      );
    } else {
      // Allow and flag - create incident
      await _createGeofenceIncident(
        studentId: studentId,
        date: date,
        slot: slot,
        currentPosition: currentPosition,
        targetGeofence: targetGeofence,
        distance: distance,
      );

      // Show message if provided
      if (effective.outsideMessageText != null && 
          effective.outsideMessageText!.isNotEmpty && 
          context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(effective.outsideMessageText!))
        );
      }

      return GeofenceValidationResult(
        allowed: true,
        status: AttStatus.outsideAttempt,
        distance: distance,
        geofence: targetGeofence,
      );
    }
  }

  /// Shows outside geofence message dialog
  static Future<void> _showOutsideMessage(BuildContext context, String message) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Outside Designated Area'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Creates a geofence incident for outside attempts
  static Future<void> _createGeofenceIncident({
    required String studentId,
    required DateTime date,
    required GeofenceSlot slot,
    required Position currentPosition,
    required Geofence targetGeofence,
    required double distance,
  }) async {
    // Get student name for the incident
    String studentName = 'Unknown Student';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        studentName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
        if (studentName.isEmpty) {
          studentName = userData['email'] ?? 'Unknown Student';
        }
      }
    } catch (e) {
      // Use fallback name if error
    }

    final incident = GeofenceIncident(
      id: '', // Will be set by Firestore
      studentId: studentId,
      studentName: studentName,
      direction: slot == GeofenceSlot.checkIn ? 'check_in' : 'check_out',
      occurredAt: DateTime.now(),
      distance: distance,
      designatedLocation: IncidentLocation(
        lat: targetGeofence.lat,
        lng: targetGeofence.lng,
        radius: targetGeofence.radiusMeters,
        name: targetGeofence.campusSlug ?? 'Unknown Campus',
      ),
      actualLocation: IncidentLocation(
        lat: currentPosition.latitude,
        lng: currentPosition.longitude,
        name: 'Current Location',
      ),
      bandType: 'fixed', // Since we only create incidents for fixed bands
      status: 'pending',
      createdAt: DateTime.now(),
    );

    await GeofenceIncidentService.createIncident(incident);
  }

  /// Gets student's geofence profile summary
  static Future<StudentGeofenceProfileSummary> getStudentProfileSummary(
    String studentId
  ) async {
    final customProfiles = <int, bool>{};
    
    for (int day = 0; day <= 6; day++) {
      final profile = await GeofenceProfileService.loadGeofenceProfile(
        studentId, 
        day
      );
      customProfiles[day] = profile != null;
    }

    return StudentGeofenceProfileSummary(
      studentId: studentId,
      hasCustomProfiles: customProfiles,
      totalCustomDays: customProfiles.values.where((has) => has).length,
    );
  }

  /// Updates student's geofence configuration in bulk
  static Future<void> bulkUpdateStudentProfiles({
    required String studentId,
    required Map<int, EffectiveGeofence> dayConfigurations,
  }) async {
    final batch = _firestore.batch();
    
    for (final entry in dayConfigurations.entries) {
      final dayOfWeek = entry.key;
      final config = entry.value;
      
      final profile = GeofenceProfile(
        dayOfWeek: dayOfWeek,
        userId: studentId,
        bandTypeOverride: config.bandType,
        outsidePolicy: config.outsidePolicy,
        outsideMessageText: config.outsideMessageText,
        checkInSlot: GeofenceSlotConfig(
          lat: config.checkIn.lat,
          lng: config.checkIn.lng,
          radiusMeters: config.checkIn.radiusMeters,
          campusSlug: config.checkIn.campusSlug,
        ),
        checkOutSlot: GeofenceSlotConfig(
          lat: config.checkOut.lat,
          lng: config.checkOut.lng,
          radiusMeters: config.checkOut.radiusMeters,
          campusSlug: config.checkOut.campusSlug,
        ),
      );

      final docRef = _firestore
          .collection('geofence_profiles')
          .doc(studentId)
          .collection('days')
          .doc(dayOfWeek.toString());

      batch.set(docRef, profile.toMap());
    }

    await batch.commit();
  }

  /// Removes custom profiles for specific days (revert to defaults)
  static Future<void> removeCustomProfiles(
    String studentId, 
    List<int> daysOfWeek
  ) async {
    final batch = _firestore.batch();
    
    for (final dayOfWeek in daysOfWeek) {
      final docRef = _firestore
          .collection('geofence_profiles')
          .doc(studentId)
          .collection('days')
          .doc(dayOfWeek.toString());

      batch.delete(docRef);
    }

    await batch.commit();
  }
}

/// Result of geofence validation
class GeofenceValidationResult {
  final bool allowed;
  final AttStatus status;
  final double distance;
  final Geofence geofence;

  const GeofenceValidationResult({
    required this.allowed,
    required this.status,
    required this.distance,
    required this.geofence,
  });
}

/// Summary of student's geofence profile configuration
class StudentGeofenceProfileSummary {
  final String studentId;
  final Map<int, bool> hasCustomProfiles;
  final int totalCustomDays;

  const StudentGeofenceProfileSummary({
    required this.studentId,
    required this.hasCustomProfiles,
    required this.totalCustomDays,
  });

  /// Get display text for profile status
  String get profileStatusText {
    if (totalCustomDays == 0) {
      return 'Using organization defaults for all days';
    } else if (totalCustomDays == 7) {
      return 'Custom profiles for all days';
    } else {
      return 'Custom profiles for $totalCustomDays day${totalCustomDays == 1 ? '' : 's'}';
    }
  }

  /// Get the days that have custom profiles
  List<int> get customDays {
    return hasCustomProfiles.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get the days that use defaults
  List<int> get defaultDays {
    return hasCustomProfiles.entries
        .where((entry) => !entry.value)
        .map((entry) => entry.key)
        .toList();
  }
}