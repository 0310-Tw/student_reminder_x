/// Enhanced Attendance Service Integration
///
/// This service extends the existing AttendanceService to include
/// geofence validation and incident creation.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:students_reminder/src/admin/models/advanced_geofence.dart';
import '../services/student_geofence_profile_service.dart';

/// Enhanced attendance service with geofence integration
class GeofenceAttendanceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Enhanced clock-in with geofence validation
  static Future<AttendanceResult> clockInWithGeofence({
    required String userId,
    required Position position,
    required String placeName,
    required BuildContext? context,
  }) async {
    try {
      // Validate geofence first
      final validation = await StudentGeofenceProfileService.validateAttendanceAttempt(
        studentId: userId,
        date: DateTime.now(),
        slot: GeofenceSlot.checkIn,
        currentPosition: position,
        context: context,
      );

      if (!validation.allowed) {
        return AttendanceResult(
          success: false,
          message: 'Clock-in blocked due to geofence policy',
          status: validation.status,
          distance: validation.distance,
        );
      }

      // Proceed with regular clock-in
      final now = DateTime.now();
      final dateId = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      
      final attendanceData = {
        'uid': userId,
        'inAt': Timestamp.now(),
        'inLat': position.latitude,
        'inLng': position.longitude,
        'inPlace': placeName,
        'status': _getAttendanceStatus(validation.status),
        'geofenceDistance': validation.distance,
        'geofenceValidated': true,
        'updatedAt': Timestamp.now(),
      };

      await _firestore
          .collection('attendance')
          .doc(userId)
          .collection('days')
          .doc(dateId)
          .set(attendanceData, SetOptions(merge: true));

      return AttendanceResult(
        success: true,
        message: 'Clock-in successful at $placeName',
        status: validation.status,
        distance: validation.distance,
      );
    } catch (e) {
      return AttendanceResult(
        success: false,
        message: 'Clock-in failed: $e',
        status: AttStatus.outsideAttempt,
        distance: 0,
      );
    }
  }

  /// Enhanced clock-out with geofence validation
  static Future<AttendanceResult> clockOutWithGeofence({
    required String userId,
    required Position position,
    required String placeName,
    required BuildContext? context,
  }) async {
    try {
      // Validate geofence first
      final validation = await StudentGeofenceProfileService.validateAttendanceAttempt(
        studentId: userId,
        date: DateTime.now(),
        slot: GeofenceSlot.checkOut,
        currentPosition: position,
        context: context,
      );

      if (!validation.allowed) {
        return AttendanceResult(
          success: false,
          message: 'Clock-out blocked due to geofence policy',
          status: validation.status,
          distance: validation.distance,
        );
      }

      // Proceed with regular clock-out
      final now = DateTime.now();
      final dateId = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      
      await _firestore
          .collection('attendance')
          .doc(userId)
          .collection('days')
          .doc(dateId)
          .update({
        'outAt': Timestamp.now(),
        'outLat': position.latitude,
        'outLng': position.longitude,
        'outPlace': placeName,
        'outGeofenceDistance': validation.distance,
        'outGeofenceValidated': true,
        'updatedAt': Timestamp.now(),
      });

      return AttendanceResult(
        success: true,
        message: 'Clock-out successful at $placeName',
        status: validation.status,
        distance: validation.distance,
      );
    } catch (e) {
      return AttendanceResult(
        success: false,
        message: 'Clock-out failed: $e',
        status: AttStatus.outsideAttempt,
        distance: 0,
      );
    }
  }

  /// Bulk validate students for attendance compliance
  static Future<List<StudentComplianceStatus>> validateStudentCompliance({
    required List<String> studentIds,
    required DateTime date,
  }) async {
    final results = <StudentComplianceStatus>[];

    for (final studentId in studentIds) {
      try {
        final effective = await StudentGeofenceProfileService.getEffectiveGeofence(
          studentId, 
          date
        );
        
        // Get today's attendance record
        final dateId = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final attendanceDoc = await _firestore
            .collection('attendance')
            .doc(studentId)
            .collection('days')
            .doc(dateId)
            .get();

        StudentComplianceStatus status;
        
        if (!attendanceDoc.exists) {
          status = StudentComplianceStatus(
            studentId: studentId,
            date: date,
            isCompliant: false,
            complianceLevel: ComplianceLevel.absent,
            message: 'No attendance record',
            checkInDistance: null,
            checkOutDistance: null,
          );
        } else {
          final data = attendanceDoc.data()!;
          status = _analyzeCompliance(studentId, date, data, effective);
        }

        results.add(status);
      } catch (e) {
        results.add(StudentComplianceStatus(
          studentId: studentId,
          date: date,
          isCompliant: false,
          complianceLevel: ComplianceLevel.error,
          message: 'Validation error: $e',
          checkInDistance: null,
          checkOutDistance: null,
        ));
      }
    }

    return results;
  }

  /// Analyzes compliance based on attendance data and effective geofence
  static StudentComplianceStatus _analyzeCompliance(
    String studentId,
    DateTime date,
    Map<String, dynamic> attendanceData,
    EffectiveGeofence effective,
  ) {
    final hasCheckIn = attendanceData['inAt'] != null;
    final hasCheckOut = attendanceData['outAt'] != null;
    
    // For floating bands, always compliant if checked in
    if (effective.bandType == BandType.floating) {
      return StudentComplianceStatus(
        studentId: studentId,
        date: date,
        isCompliant: hasCheckIn,
        complianceLevel: hasCheckIn 
            ? ComplianceLevel.full 
            : ComplianceLevel.absent,
        message: hasCheckIn 
            ? 'Floating band - compliant' 
            : 'No check-in recorded',
        checkInDistance: null,
        checkOutDistance: null,
      );
    }

    // Fixed band compliance check
    double? checkInDistance;
    double? checkOutDistance;
    ComplianceLevel level = ComplianceLevel.full;
    String message = 'Fully compliant';

    if (hasCheckIn) {
      final inLat = attendanceData['inLat'] as double?;
      final inLng = attendanceData['inLng'] as double?;
      if (inLat != null && inLng != null) {
        checkInDistance = effective.checkIn.distanceTo(inLat, inLng);
        if (checkInDistance > effective.checkIn.radiusMeters) {
          level = ComplianceLevel.partial;
          message = 'Check-in outside geofence';
        }
      }
    } else {
      level = ComplianceLevel.absent;
      message = 'No check-in recorded';
    }

    if (hasCheckOut) {
      final outLat = attendanceData['outLat'] as double?;
      final outLng = attendanceData['outLng'] as double?;
      if (outLat != null && outLng != null) {
        checkOutDistance = effective.checkOut.distanceTo(outLat, outLng);
        if (checkOutDistance > effective.checkOut.radiusMeters) {
          if (level == ComplianceLevel.full) {
            level = ComplianceLevel.partial;
            message = 'Check-out outside geofence';
          } else if (level == ComplianceLevel.partial) {
            message = 'Both check-in and check-out outside geofence';
          }
        }
      }
    }

    return StudentComplianceStatus(
      studentId: studentId,
      date: date,
      isCompliant: level == ComplianceLevel.full,
      complianceLevel: level,
      message: message,
      checkInDistance: checkInDistance,
      checkOutDistance: checkOutDistance,
    );
  }

  /// Converts AttStatus to attendance status string
  static String _getAttendanceStatus(AttStatus status) {
    switch (status) {
      case AttStatus.present:
        return 'present';
      case AttStatus.late:
        return 'late';
      case AttStatus.outsideAttempt:
        return 'outside';
    }
  }

  /// Gets geofence statistics for admin dashboard
  static Future<GeofenceStatistics> getGeofenceStatistics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Implementation would query attendance and incidents collections
    // This is a placeholder for the statistics calculation
    return const GeofenceStatistics(
      totalAttempts: 0,
      compliantAttempts: 0,
      outsideAttempts: 0,
      blockedAttempts: 0,
      incidentsCreated: 0,
    );
  }
}

/// Result of attendance operation with geofence validation
class AttendanceResult {
  final bool success;
  final String message;
  final AttStatus status;
  final double distance;

  const AttendanceResult({
    required this.success,
    required this.message,
    required this.status,
    required this.distance,
  });
}

/// Student compliance status for geofence validation
class StudentComplianceStatus {
  final String studentId;
  final DateTime date;
  final bool isCompliant;
  final ComplianceLevel complianceLevel;
  final String message;
  final double? checkInDistance;
  final double? checkOutDistance;

  const StudentComplianceStatus({
    required this.studentId,
    required this.date,
    required this.isCompliant,
    required this.complianceLevel,
    required this.message,
    this.checkInDistance,
    this.checkOutDistance,
  });

  /// Get color for UI display
  Color get statusColor {
    switch (complianceLevel) {
      case ComplianceLevel.full:
        return Colors.green;
      case ComplianceLevel.partial:
        return Colors.orange;
      case ComplianceLevel.absent:
        return Colors.red;
      case ComplianceLevel.error:
        return Colors.grey;
    }
  }

  /// Get icon for UI display
  IconData get statusIcon {
    switch (complianceLevel) {
      case ComplianceLevel.full:
        return Icons.check_circle;
      case ComplianceLevel.partial:
        return Icons.warning;
      case ComplianceLevel.absent:
        return Icons.cancel;
      case ComplianceLevel.error:
        return Icons.error;
    }
  }
}

/// Levels of geofence compliance
enum ComplianceLevel {
  full,     // Fully compliant with geofences
  partial,  // Some violations but present
  absent,   // No attendance record
  error,    // Error in validation
}

/// Geofence statistics for dashboard
class GeofenceStatistics {
  final int totalAttempts;
  final int compliantAttempts;
  final int outsideAttempts;
  final int blockedAttempts;
  final int incidentsCreated;

  const GeofenceStatistics({
    required this.totalAttempts,
    required this.compliantAttempts,
    required this.outsideAttempts,
    required this.blockedAttempts,
    required this.incidentsCreated,
  });

  /// Calculate compliance rate as percentage
  double get complianceRate {
    if (totalAttempts == 0) return 100.0;
    return (compliantAttempts / totalAttempts) * 100;
  }

  /// Calculate incident rate as percentage
  double get incidentRate {
    if (totalAttempts == 0) return 0.0;
    return (incidentsCreated / totalAttempts) * 100;
  }
}