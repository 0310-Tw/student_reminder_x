import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:students_reminder/src/admin/models/advance_geofence.dart';


enum AttendanceType { checkIn, checkOut }

class LocationPoint {
  final double lat;
  final double lng;
  const LocationPoint({required this.lat, required this.lng});

  Map<String, dynamic> toMap() => {'lat': lat, 'lng': lng};
}

class AttendanceResult {
  final bool success;
  final String message;

  AttendanceResult(this.success, this.message);
  factory AttendanceResult.success(String msg) => AttendanceResult(true, msg);
  factory AttendanceResult.error(String msg) => AttendanceResult(false, msg);
}

class AttendanceRecord {
  final String id;
  final String userId;
  final AttendanceType type;
  final DateTime timestamp;
  final AttStatus status;
  final double distanceMeters;

  AttendanceRecord({
    required this.id,
    required this.userId,
    required this.type,
    required this.timestamp,
    required this.status,
    required this.distanceMeters,
  });

  factory AttendanceRecord.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AttendanceRecord(
      id: doc.id,
      userId: d['userId'],
      type: d['type'] == 'checkIn'
          ? AttendanceType.checkIn
          : AttendanceType.checkOut,
      timestamp: (d['timestamp'] as Timestamp).toDate(),
      status: AttStatus.values.firstWhere(
        (s) => s.toString().split('.').last == d['status'],
        orElse: () => AttStatus.unknown,
      ),
      distanceMeters: (d['distance'] ?? 0).toDouble(),
    );
  }
}

class AttendanceStatistics {
  final int total;
  final int onTime;
  final int late;
  final int outside;

  AttendanceStatistics({
    required this.total,
    required this.onTime,
    required this.late,
    required this.outside,
  });
}

class AdvancedAttendanceService {
  static final _firestore = FirebaseFirestore.instance;

  static Future<AttendanceResult> recordAttendance({
    required String userId,
    required Position currentPosition,
    required DateTime scheduledStart,
    required int graceMinutes,
    required AttendanceType attendanceType,
    required OrgDefaults orgDefaults,
  }) async {
    try {
      final now = DateTime.now();
      final effective = (now.weekday == 3 || now.weekday == 4)
          ? orgDefaults.campuses['stony_hill']
          : orgDefaults.campuses['up_park_camp'];

      if (effective == null) {
        return AttendanceResult.error('No geofence defined for today');
      }

      final distance = GeofenceSlot(
        lat: effective.lat,
        lng: effective.lng,
        radiusMeters: effective.defaultRadiusMeters,
      ).distanceTo(currentPosition.latitude, currentPosition.longitude);

      final status = resolveStatus(
        now: now,
        start: scheduledStart,
        graceMinutes: graceMinutes,
        distanceMeters: distance,
        radiusMeters: effective.defaultRadiusMeters,
      );

      await _firestore.collection('advanced_attendance').add({
        'userId': userId,
        'timestamp': Timestamp.now(),
        'type': attendanceType.name,
        'status': status.name,
        'distance': distance,
        'campus': effective.name,
      });

      return AttendanceResult.success('Attendance recorded as ${status.name}');
    } catch (e) {
      return AttendanceResult.error('Error: $e');
    }
  }

  static Future<List<AttendanceRecord>> getAttendanceHistory({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    AttStatus? statusFilter,
    AttendanceType? typeFilter,
    int limit = 50,
  }) async {
    var query = _firestore
        .collection('advanced_attendance')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit);

    final snapshot = await query.get();
    return snapshot.docs.map((d) => AttendanceRecord.fromDoc(d)).toList();
  }

  static Future<AttendanceStatistics> calculateStatistics({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final records = await getAttendanceHistory(userId: userId);
    int onTime = 0, late = 0, outside = 0;
    for (final r in records) {
      if (r.status == AttStatus.onTime) onTime++;
      if (r.status == AttStatus.late) late++;
      if (r.status == AttStatus.outside) outside++;
    }
    return AttendanceStatistics(
      total: records.length,
      onTime: onTime,
      late: late,
      outside: outside,
    );
  }

  static Future<List<AttendanceRecord>> getFlaggedAttendance({
    DateTime? since,
    int limit = 100,
  }) async {
    var q = _firestore
        .collection('advanced_attendance')
        .where('status', whereIn: ['outside', 'late'])
        .orderBy('timestamp', descending: true)
        .limit(limit);
    final s = await q.get();
    return s.docs.map((d) => AttendanceRecord.fromDoc(d)).toList();
  }
}
