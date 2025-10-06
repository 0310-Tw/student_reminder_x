/// Advanced Attendance Service
///
/// This service provides advanced attendance tracking functionality using the
/// new geofencing system with band types, outside policies, and effective geofences.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import 'advanced_geofence_models.dart';
import 'effective_geofence_resolver.dart';

/// Enhanced attendance service with advanced geofencing
class AdvancedAttendanceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Record attendance with advanced geofence validation
  static Future<AttendanceResult> recordAttendance({
    required String userId,
    required Position currentPosition,
    required DateTime scheduledStart,
    required int graceMinutes,
    required AttendanceType attendanceType, // checkIn or checkOut
    required OrgDefaults orgDefaults,
  }) async {
    try {
      // Load user profile
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return AttendanceResult.error('User profile not found');
      }

      final userProfile = UserProfile.fromMap(userDoc.data()!, userId);
      final currentDay = GeofenceResolutionUtils.getCurrentDayOfWeek();

      // Resolve effective geofence for today
      final effectiveGeofence =
          await EffectiveGeofenceResolver.resolveEffectiveGeofence(
            user: userProfile,
            dow: currentDay,
            defaults: orgDefaults,
          );

      // Select appropriate geofence (checkIn or checkOut)
      final targetGeofence = attendanceType == AttendanceType.checkIn
          ? effectiveGeofence.checkIn
          : effectiveGeofence.checkOut;

      // Calculate distance to geofence center
      final distanceToCenter = targetGeofence.distanceTo(
        currentPosition.latitude,
        currentPosition.longitude,
      );

      // Resolve attendance status
      final status = resolveStatus(
        now: DateTime.now(),
        start: scheduledStart,
        graceMinutes: graceMinutes,
        distanceMeters: distanceToCenter,
        radiusMeters: targetGeofence.radiusMeters,
      );

      // Check if attendance is allowed based on band type and outside policy
      final attendanceAllowed = _isAttendanceAllowed(
        status: status,
        effectiveGeofence: effectiveGeofence,
      );

      if (!attendanceAllowed.allowed) {
        return AttendanceResult.blocked(
          attendanceAllowed.reason!,
          distanceToCenter,
          targetGeofence.radiusMeters,
        );
      }

      // Record the attendance
      final attendanceRecord = AttendanceRecord(
        userId: userId,
        timestamp: DateTime.now(),
        position: LocationPoint(
          lat: currentPosition.latitude,
          lng: currentPosition.longitude,
        ),
        scheduledStart: scheduledStart,
        status: status,
        attendanceType: attendanceType,
        geofenceUsed: targetGeofence,
        effectiveGeofence: effectiveGeofence,
        distanceFromCenter: distanceToCenter,
        graceMinutes: graceMinutes,
      );

      // Save to Firestore
      await _saveAttendanceRecord(attendanceRecord);

      return AttendanceResult.success(
        attendanceRecord,
        effectiveGeofence.outsideMessageText,
      );
    } catch (e) {
      print('Error recording attendance: $e');
      return AttendanceResult.error('Failed to record attendance: $e');
    }
  }

  /// Check if attendance is allowed based on policies
  static AttendanceAllowedResult _isAttendanceAllowed({
    required AttStatus status,
    required EffectiveGeofence effectiveGeofence,
  }) {
    // If student is not attempting from outside, always allow
    if (status != AttStatus.outsideAttempt) {
      return const AttendanceAllowedResult(allowed: true);
    }

    // Handle outside attempts based on band type and policy
    switch (effectiveGeofence.bandType) {
      case BandType.floating:
        // Floating geofences always allow (they adapt to location)
        return const AttendanceAllowedResult(allowed: true);

      case BandType.fixed:
        switch (effectiveGeofence.outsidePolicy) {
          case OutsidePolicy.allowAndFlag:
            return const AttendanceAllowedResult(allowed: true);
          case OutsidePolicy.block:
            return AttendanceAllowedResult(
              allowed: false,
              reason:
                  effectiveGeofence.outsideMessageText ??
                  'You must be within the designated area to record attendance.',
            );
          case null:
            // This shouldn't happen for fixed band type, but default to block
            return const AttendanceAllowedResult(
              allowed: false,
              reason: 'Attendance not allowed from outside the geofence area.',
            );
        }
    }
  }

  /// Save attendance record to Firestore
  static Future<void> _saveAttendanceRecord(AttendanceRecord record) async {
    final docRef = _firestore
        .collection('attendance')
        .doc('${record.userId}_${record.timestamp.millisecondsSinceEpoch}');

    await docRef.set(record.toMap());

    // Also update daily summary
    await _updateDailySummary(record);
  }

  /// Update daily attendance summary
  static Future<void> _updateDailySummary(AttendanceRecord record) async {
    final dateStr = _formatDate(record.timestamp);
    final summaryRef = _firestore
        .collection('daily_attendance')
        .doc('${record.userId}_$dateStr');

    await summaryRef.set({
      'userId': record.userId,
      'date': dateStr,
      'lastAttendance': record.timestamp,
      'checkInStatus': record.attendanceType == AttendanceType.checkIn
          ? record.status.name
          : FieldValue.delete(),
      'checkOutStatus': record.attendanceType == AttendanceType.checkOut
          ? record.status.name
          : FieldValue.delete(),
      'bandType': record.effectiveGeofence.bandType.name,
      'flaggedForReview':
          record.status == AttStatus.outsideAttempt &&
          record.effectiveGeofence.outsidePolicy == OutsidePolicy.allowAndFlag,
    }, SetOptions(merge: true));
  }

  /// Get attendance history with advanced filtering
  static Future<List<AttendanceRecord>> getAttendanceHistory({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    AttStatus? statusFilter,
    AttendanceType? typeFilter,
    BandType? bandTypeFilter,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore
          .collection('attendance')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true);

      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: endDate);
      }
      if (statusFilter != null) {
        query = query.where('status', isEqualTo: statusFilter.name);
      }
      if (typeFilter != null) {
        query = query.where('attendanceType', isEqualTo: typeFilter.name);
      }

      query = query.limit(limit);

      final snapshot = await query.get();

      final records = <AttendanceRecord>[];
      for (final doc in snapshot.docs) {
        try {
          final record = AttendanceRecord.fromMap(
            doc.data() as Map<String, dynamic>,
          );

          // Apply client-side filtering for band type (not easily queryable in Firestore)
          if (bandTypeFilter == null ||
              record.effectiveGeofence.bandType == bandTypeFilter) {
            records.add(record);
          }
        } catch (e) {
          print('Error parsing attendance record ${doc.id}: $e');
        }
      }

      return records;
    } catch (e) {
      print('Error getting attendance history: $e');
      return [];
    }
  }

  /// Get flagged attendance records for review
  static Future<List<AttendanceRecord>> getFlaggedAttendance({
    DateTime? since,
    int limit = 100,
  }) async {
    try {
      Query query = _firestore
          .collection('attendance')
          .where('status', isEqualTo: AttStatus.outsideAttempt.name)
          .orderBy('timestamp', descending: true);

      if (since != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: since);
      }

      query = query.limit(limit);

      final snapshot = await query.get();

      final flaggedRecords = <AttendanceRecord>[];
      for (final doc in snapshot.docs) {
        try {
          final record = AttendanceRecord.fromMap(
            doc.data() as Map<String, dynamic>,
          );

          // Only include records with allowAndFlag policy
          if (record.effectiveGeofence.outsidePolicy ==
              OutsidePolicy.allowAndFlag) {
            flaggedRecords.add(record);
          }
        } catch (e) {
          print('Error parsing flagged attendance record ${doc.id}: $e');
        }
      }

      return flaggedRecords;
    } catch (e) {
      print('Error getting flagged attendance: $e');
      return [];
    }
  }

  /// Calculate attendance statistics for a user
  static Future<AttendanceStatistics> calculateStatistics({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final records = await getAttendanceHistory(
        userId: userId,
        startDate: startDate,
        endDate: endDate,
        limit: 1000, // Get more records for accurate statistics
      );

      return AttendanceStatistics.fromRecords(records, startDate, endDate);
    } catch (e) {
      print('Error calculating attendance statistics: $e');
      return AttendanceStatistics.empty();
    }
  }

  /// Format date for daily summary keys
  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// Types of attendance events
enum AttendanceType { checkIn, checkOut }

/// Location point for attendance records
class LocationPoint {
  final double lat;
  final double lng;

  const LocationPoint({required this.lat, required this.lng});

  factory LocationPoint.fromMap(Map<String, dynamic> map) {
    return LocationPoint(
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {'lat': lat, 'lng': lng};

  double distanceTo(LocationPoint other) {
    return calculateHaversineDistance(lat, lng, other.lat, other.lng);
  }
}

/// Complete attendance record
class AttendanceRecord {
  final String userId;
  final DateTime timestamp;
  final LocationPoint position;
  final DateTime scheduledStart;
  final AttStatus status;
  final AttendanceType attendanceType;
  final Geofence geofenceUsed;
  final EffectiveGeofence effectiveGeofence;
  final double distanceFromCenter;
  final int graceMinutes;

  const AttendanceRecord({
    required this.userId,
    required this.timestamp,
    required this.position,
    required this.scheduledStart,
    required this.status,
    required this.attendanceType,
    required this.geofenceUsed,
    required this.effectiveGeofence,
    required this.distanceFromCenter,
    required this.graceMinutes,
  });

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      userId: map['userId'] as String,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      position: LocationPoint.fromMap(map['position'] as Map<String, dynamic>),
      scheduledStart: (map['scheduledStart'] as Timestamp).toDate(),
      status: AttStatus.values.firstWhere((e) => e.name == map['status']),
      attendanceType: AttendanceType.values.firstWhere(
        (e) => e.name == map['attendanceType'],
      ),
      geofenceUsed: Geofence.fromMap(
        map['geofenceUsed'] as Map<String, dynamic>,
      ),
      effectiveGeofence: EffectiveGeofence.fromMap(
        map['effectiveGeofence'] as Map<String, dynamic>,
      ),
      distanceFromCenter: (map['distanceFromCenter'] as num).toDouble(),
      graceMinutes: map['graceMinutes'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'timestamp': Timestamp.fromDate(timestamp),
      'position': position.toMap(),
      'scheduledStart': Timestamp.fromDate(scheduledStart),
      'status': status.name,
      'attendanceType': attendanceType.name,
      'geofenceUsed': geofenceUsed.toMap(),
      'effectiveGeofence': effectiveGeofence.toMap(),
      'distanceFromCenter': distanceFromCenter,
      'graceMinutes': graceMinutes,
    };
  }

  bool get wasOnTime => status == AttStatus.present;
  bool get wasLate => status == AttStatus.late;
  bool get wasOutside => status == AttStatus.outsideAttempt;
  bool get isSuccessful => status.isSuccessful;
}

/// Result of an attendance recording attempt
class AttendanceResult {
  final bool success;
  final String? errorMessage;
  final AttendanceRecord? record;
  final String? customMessage;
  final double? distance;
  final double? radius;

  const AttendanceResult._({
    required this.success,
    this.errorMessage,
    this.record,
    this.customMessage,
    this.distance,
    this.radius,
  });

  factory AttendanceResult.success(
    AttendanceRecord record, [
    String? customMessage,
  ]) {
    return AttendanceResult._(
      success: true,
      record: record,
      customMessage: customMessage,
    );
  }

  factory AttendanceResult.blocked(
    String reason,
    double distance,
    double radius,
  ) {
    return AttendanceResult._(
      success: false,
      errorMessage: reason,
      distance: distance,
      radius: radius,
    );
  }

  factory AttendanceResult.error(String message) {
    return AttendanceResult._(success: false, errorMessage: message);
  }

  String get displayMessage {
    if (success && record != null) {
      final status = record!.status.displayName;
      final type = record!.attendanceType == AttendanceType.checkIn
          ? 'Check-in'
          : 'Check-out';
      return '$type recorded: $status';
    }
    return errorMessage ?? 'Unknown error occurred';
  }
}

/// Result of checking if attendance is allowed
class AttendanceAllowedResult {
  final bool allowed;
  final String? reason;

  const AttendanceAllowedResult({required this.allowed, this.reason});
}

/// Attendance statistics for analysis
class AttendanceStatistics {
  final int totalRecords;
  final int presentCount;
  final int lateCount;
  final int outsideAttemptCount;
  final int checkInCount;
  final int checkOutCount;
  final double attendanceRate;
  final double punctualityRate;
  final DateTime startDate;
  final DateTime endDate;

  const AttendanceStatistics({
    required this.totalRecords,
    required this.presentCount,
    required this.lateCount,
    required this.outsideAttemptCount,
    required this.checkInCount,
    required this.checkOutCount,
    required this.attendanceRate,
    required this.punctualityRate,
    required this.startDate,
    required this.endDate,
  });

  factory AttendanceStatistics.fromRecords(
    List<AttendanceRecord> records,
    DateTime startDate,
    DateTime endDate,
  ) {
    final totalRecords = records.length;
    final presentCount = records
        .where((r) => r.status == AttStatus.present)
        .length;
    final lateCount = records.where((r) => r.status == AttStatus.late).length;
    final outsideAttemptCount = records
        .where((r) => r.status == AttStatus.outsideAttempt)
        .length;
    final checkInCount = records
        .where((r) => r.attendanceType == AttendanceType.checkIn)
        .length;
    final checkOutCount = records
        .where((r) => r.attendanceType == AttendanceType.checkOut)
        .length;

    final successfulAttendance = presentCount + lateCount;
    final attendanceRate = totalRecords > 0
        ? successfulAttendance / totalRecords
        : 0.0;
    final punctualityRate = successfulAttendance > 0
        ? presentCount / successfulAttendance
        : 0.0;

    return AttendanceStatistics(
      totalRecords: totalRecords,
      presentCount: presentCount,
      lateCount: lateCount,
      outsideAttemptCount: outsideAttemptCount,
      checkInCount: checkInCount,
      checkOutCount: checkOutCount,
      attendanceRate: attendanceRate,
      punctualityRate: punctualityRate,
      startDate: startDate,
      endDate: endDate,
    );
  }

  factory AttendanceStatistics.empty() {
    final now = DateTime.now();
    return AttendanceStatistics(
      totalRecords: 0,
      presentCount: 0,
      lateCount: 0,
      outsideAttemptCount: 0,
      checkInCount: 0,
      checkOutCount: 0,
      attendanceRate: 0.0,
      punctualityRate: 0.0,
      startDate: now,
      endDate: now,
    );
  }
}
