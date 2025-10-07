// lib/src/services/attendance_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart'; // for DateUtils.dateOnly
import 'package:geolocator/geolocator.dart';

// Models / campus locations (adjust paths if your layout differs)
import '../admin/models/geofence_profile.dart' show GeofenceProfile;
import '../admin/pages/campus_location.dart' show campusLocations;

/* ----------------------- JmTime (time helpers) ----------------------- */
class JmTime {
  // Local "now"
  static DateTime nowLocal() => DateTime.now();

  // Lexicographically sortable day id, e.g., "2025-09-01"
  static String dateId(DateTime d) {
    final day = DateUtils.dateOnly(d);
    final mm = day.month.toString().padLeft(2, '0');
    final dd = day.day.toString().padLeft(2, '0');
    return '${day.year}-$mm-$dd';
  }

  static DateTime onDate(DateTime d, int hour, int minute) =>
      DateTime(d.year, d.month, d.day, hour, minute);

  /// Attendance windows for a given calendar day:
  /// start: 08:00 (earliest clock-in)
  /// lateEdge: 08:30 (after this = "late")
  /// cutoff: 16:00 (auto clock-out threshold)
  static ({DateTime start, DateTime lateEdge, DateTime cutoff}) windows(
    DateTime d,
  ) {
    final day = DateUtils.dateOnly(d);
    final start = onDate(day, 8, 0);
    final late = onDate(day, 8, 30);
    final cutoff = onDate(day, 16, 0);
    return (start: start, lateEdge: late, cutoff: cutoff);
  }
}

/* ------------------------ AttendanceService ------------------------ */
class AttendanceService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /* ----- streams ----- */

  /// Last 14 days (newest → oldest). UI builds a fixed 14-day window around this.
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamLast14Days(
    String uid,
  ) {
    // Simplified query to avoid index requirements - using ascending order
    return _db
        .collection('attendance')
        .doc(uid)
        .collection('days')
        .orderBy('dayId') // ascending order to avoid index requirements
        .limit(30) // Get more than 14 to ensure we have recent data
        .snapshots();
  }

  /* ------------------ Geofence helpers & resolution ------------------ */

  /// Returns a map describing resolved geofence info for today.
  /// Map keys:
  ///  - 'checkIn': {lat, lng, radius}
  ///  - 'checkOut': {lat, lng, radius}
  ///  - 'bandType': 'fixed'|'floating'
  ///  - 'outsidePolicy': 'block'|'allow_flag'
  ///  - 'outsideMessage': string?
  static Future<Map<String, dynamic>> _resolveProfileForToday(String uid) async {
    final now = DateTime.now();
    final dowIndex = (now.weekday == 7) ? 0 : now.weekday; // 0..6 (Sun=0)
    final dowStr = (dowIndex % 7).toString();

    // Try to load per-user per-day profile
    try {
      final profSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('geofence_profiles')
          .doc(dowStr)
          .get();

      if (profSnap.exists && profSnap.data() != null) {
        final profile = GeofenceProfile.fromDoc(profSnap);
        return {
          'checkIn': {
            'lat': profile.inLat,
            'lng': profile.inLng,
            'radius': profile.inRadius
          },
          'checkOut': {
            'lat': profile.outLat,
            'lng': profile.outLng,
            'radius': profile.outRadius
          },
          'bandType': profile.bandType.name, // 'fixed'|'floating'
          'outsidePolicy': profile.outsidePolicy.name, // 'block'|'allowAndFlag' etc
          'outsideMessage': profile.outsideMessage,
          'hasProfile': true,
        };
      }
    } catch (e) {
      // ignore and fallback
    }

    // Fallback to campus defaults by dow: Wed(3) & Thu(4) -> stony_hill else up_park_camp
    final slug = (dowIndex == 3 || dowIndex == 4) ? 'stony_hill' : 'up_park_camp';
    final campus = campusLocations[slug];
    if (campus != null) {
      return {
        'checkIn': {'lat': campus.latitude, 'lng': campus.longitude, 'radius': campus.radiusMeters},
        'checkOut': {'lat': campus.latitude, 'lng': campus.longitude, 'radius': campus.radiusMeters},
        'bandType': 'fixed',
        'outsidePolicy': 'block',
        'outsideMessage': null,
        'hasProfile': false,
        'campusSlug': slug,
      };
    }

    // Final fallback (shouldn't happen)
    return {
      'checkIn': {'lat': 18.005, 'lng': -76.7936, 'radius': 150},
      'checkOut': {'lat': 18.005, 'lng': -76.7936, 'radius': 150},
      'bandType': 'fixed',
      'outsidePolicy': 'block',
      'outsideMessage': null,
      'hasProfile': false,
      'campusSlug': null,
    };
  }

  static double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  static Future<String> _createIncident({
    required String studentUid,
    String? classId,
    String? sessionId,
    required String direction, // 'checkin' | 'checkout'
    required Map<String, dynamic> designatedLocation, // lat,lng,radiusMeters
    required Position actualPosition,
    required double distanceMeters,
    required String outsidePolicy,
    String? outsideMessageShown,
    String? outsideMessageText,
  }) async {
    final incidentRef = _db.collection('geofence_incidents').doc();
    final data = {
      'studentUid': studentUid,
      'classId': classId,
      'sessionId': sessionId,
      'direction': direction,
      'occurredAt': FieldValue.serverTimestamp(),
      'bandTypeAtTime': 'fixed',
      'designatedLocation': designatedLocation,
      'actualLocation': {
        'lat': actualPosition.latitude,
        'lng': actualPosition.longitude,
        'accuracy': actualPosition.accuracy
      },
      'distanceMeters': distanceMeters,
      'outsideMessageShown': outsideMessageShown != null,
      'outsideMessageText': outsideMessageText,
      'status': 'open',
    };

    await incidentRef.set(data);
    return incidentRef.id;
  }

  /* ------------------ Clock In / Out (geofence-aware) ------------------ */

  /// Enhanced clock in. Accepts a Position (device) and placeName (reverse-geocoded).
  /// Throws Exception(...) if blocked by policy. Otherwise completes normally.
  static Future<void> clockIn(String uid, Position pos, String placeName,
      {String? classId, String? sessionId}) async {
    final now = DateTime.now();
    final dayId = JmTime.dateId(now);

    // Resolve geofence profile (today)
    final profile = await _resolveProfileForToday(uid);
    final inSlot = profile['checkIn'] as Map<String, dynamic>;
    final designatedLat = (inSlot['lat'] as num).toDouble();
    final designatedLng = (inSlot['lng'] as num).toDouble();
    final designatedRadius = (inSlot['radius'] as num).toDouble();

    final bandType = (profile['bandType'] as String?) ?? 'fixed';
    final outsidePolicy = (profile['outsidePolicy'] as String?) ?? 'block';
    final outsideMessage = profile['outsideMessage'] as String?;

    final distance = _distanceMeters(
      pos.latitude,
      pos.longitude,
      designatedLat,
      designatedLng,
    );

    // Determine timing status (present / late)
    final windows = JmTime.windows(now);
    final timingStatus = (now.isAfter(windows.start) && now.isBefore(windows.lateEdge))
        ? 'early'
        : (now.isAfter(windows.lateEdge) && now.isBefore(windows.cutoff))
            ? 'late'
            : 'out_of_window';

    // Compose base attendance data
    final attendanceRef = _db.collection('attendance').doc(uid).collection('days').doc(dayId);

    final attendancePatch = <String, dynamic>{
      'dayId': dayId,
      'inAt': Timestamp.fromDate(now),
      'inLoc': GeoPoint(pos.latitude, pos.longitude),
      'placeIn': placeName,
      'timingStatus': timingStatus,
      'bandTypeAtTime': bandType,
      'designatedLocation': {
        'lat': designatedLat,
        'lng': designatedLng,
        'radiusMeters': designatedRadius,
      },
      'distanceMeters': distance,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Geofence enforcement logic
    if (bandType == 'floating') {
      // Always allow
      attendancePatch['status'] = (timingStatus == 'late') ? 'late' : 'present';
      await attendanceRef.set(attendancePatch, SetOptions(merge: true));
      return;
    }

    // Fixed band -> check distance
    final inside = distance <= designatedRadius;

    if (inside) {
      attendancePatch['status'] = (timingStatus == 'late') ? 'late' : 'present';
      await attendanceRef.set(attendancePatch, SetOptions(merge: true));
      return;
    } else {
      // Outside the geofence — create incident
      final designatedMap = attendancePatch['designatedLocation'] as Map<String, dynamic>;
      final incidentId = await _createIncident(
        studentUid: uid,
        classId: classId,
        sessionId: sessionId,
        direction: 'checkin',
        designatedLocation: designatedMap,
        actualPosition: pos,
        distanceMeters: distance,
        outsidePolicy: outsidePolicy,
        outsideMessageShown: outsideMessage != null ? 'true' : null,
        outsideMessageText: outsideMessage,
      );

      attendancePatch['status'] = 'OutsideAttempt';
      attendancePatch['incidentId'] = incidentId;
      attendancePatch['distanceMeters'] = distance;

      // If policy is block => write record and throw to block UI
      if (outsidePolicy == 'block') {
        await attendanceRef.set(attendancePatch, SetOptions(merge: true));
        throw Exception(outsideMessage ?? 'Check-in blocked: outside designated area.');
      } else {
        // allow_and_flag / allow_flag: mark present but flagged
        attendancePatch['status'] = (timingStatus == 'late') ? 'late' : 'present';
        attendancePatch['flaggedOutside'] = true;
        await attendanceRef.set(attendancePatch, SetOptions(merge: true));
        return;
      }
    }
  }

  /// Enhanced clock out. Similar logic to clockIn (uses checkOut slot).
  static Future<void> clockOut(String uid, Position pos, String placeName,
      {String? classId, String? sessionId}) async {
    final now = DateTime.now();
    final dayId = JmTime.dateId(now);

    // Resolve geofence profile (today)
    final profile = await _resolveProfileForToday(uid);
    final outSlot = profile['checkOut'] as Map<String, dynamic>;
    final designatedLat = (outSlot['lat'] as num).toDouble();
    final designatedLng = (outSlot['lng'] as num).toDouble();
    final designatedRadius = (outSlot['radius'] as num).toDouble();

    final bandType = (profile['bandType'] as String?) ?? 'fixed';
    final outsidePolicy = (profile['outsidePolicy'] as String?) ?? 'block';
    final outsideMessage = profile['outsideMessage'] as String?;

    final distance = _distanceMeters(
      pos.latitude,
      pos.longitude,
      designatedLat,
      designatedLng,
    );

    final attendanceRef = _db.collection('attendance').doc(uid).collection('days').doc(dayId);

    final attendancePatch = <String, dynamic>{
      'dayId': dayId,
      'outAt': Timestamp.fromDate(now),
      'outLoc': GeoPoint(pos.latitude, pos.longitude),
      'placeOut': placeName,
      'bandTypeAtTime': bandType,
      'designatedLocationOut': {
        'lat': designatedLat,
        'lng': designatedLng,
        'radiusMeters': designatedRadius,
      },
      'distanceMetersOut': distance,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (bandType == 'floating') {
      // always allow
      await attendanceRef.set(attendancePatch, SetOptions(merge: true));
      return;
    }

    final inside = distance <= designatedRadius;

    if (inside) {
      await attendanceRef.set(attendancePatch, SetOptions(merge: true));
      return;
    } else {
      // Outside -> create incident then apply policy
      final incidentId = await _createIncident(
        studentUid: uid,
        classId: classId,
        sessionId: sessionId,
        direction: 'checkout',
        designatedLocation: attendancePatch['designatedLocationOut'] as Map<String, dynamic>,
        actualPosition: pos,
        distanceMeters: distance,
        outsidePolicy: outsidePolicy,
        outsideMessageShown: outsideMessage != null ? 'true' : null,
        outsideMessageText: outsideMessage,
      );

      attendancePatch['incidentIdOut'] = incidentId;

      if (outsidePolicy == 'block') {
        await attendanceRef.set(attendancePatch, SetOptions(merge: true));
        throw Exception(outsideMessage ?? 'Check-out blocked: outside designated area.');
      } else {
        // allow and flag
        attendancePatch['flaggedOutsideOut'] = true;
        await attendanceRef.set(attendancePatch, SetOptions(merge: true));
        return;
      }
    }
  }

  /* ----- Admin Methods (existing ones retained) ----- */

  /// Get attendance for all users on a specific date (for admin)
  static Stream<QuerySnapshot<Map<String, dynamic>>>
      streamAllUsersAttendanceForDate(DateTime date) {
    final dateId = JmTime.dateId(date);
    return FirebaseFirestore.instance
        .collectionGroup('days')
        .where('dayId', isEqualTo: dateId)
        .snapshots();
  }

  /// Get attendance for a specific user over date range (for admin)
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamUserAttendanceRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) {
    final startId = JmTime.dateId(startDate);
    final endId = JmTime.dateId(endDate);
    return FirebaseFirestore.instance
        .collection('attendance')
        .doc(userId)
        .collection('days')
        .where('dayId', isGreaterThanOrEqualTo: startId)
        .where('dayId', isLessThanOrEqualTo: endId)
        .orderBy('dayId') // Remove descending to avoid index requirement
        .snapshots();
  }

  /// Get all users' attendance for the current week (for admin dashboard)
  static Stream<QuerySnapshot<Map<String, dynamic>>>
      streamCurrentWeekAttendance() {
    final now = JmTime.nowLocal();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startId = JmTime.dateId(DateUtils.dateOnly(startOfWeek));

    return FirebaseFirestore.instance
        .collectionGroup('days')
        .where('dayId', isGreaterThanOrEqualTo: startId)
        .orderBy('dayId') // Remove descending to avoid index requirement
        .snapshots();
  }

  /// Get attendance summary for a user (total present/absent/late days)
  static Future<Map<String, int>> getAttendanceSummary(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final start =
        startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now();

    final startId = JmTime.dateId(start);
    final endId = JmTime.dateId(end);

    final snapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .doc(userId)
        .collection('days')
        .where('dayId', isGreaterThanOrEqualTo: startId)
        .where('dayId', isLessThanOrEqualTo: endId)
        .get();

    int present = 0, absent = 0, late = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final status = data['status'] as String? ?? 'absent';

      switch (status) {
        case 'present':
          present++;
          break;
        case 'late':
          late++;
          break;
        case 'absent':
        default:
          absent++;
          break;
      }
    }

    return {
      'present': present,
      'late': late,
      'absent': absent,
      'total': present + late + absent,
    };
  }

  /* ----- Admin Methods (Extended) ----- */

  /// Admin marks a student as present for a specific date
  static Future<void> adminMarkPresent(
    String adminUid,
    String targetUid,
    String dateId,
  ) async {
    try {
      // Get admin and target user info for notifications
      final appUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(adminUid)
          .get();

      final targetUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .get();

      final adminData = appUserDoc.data() ?? {};
      final targetData = targetUserDoc.data() ?? {};

      final adminName =
          '${adminData['firstName'] ?? ''} ${adminData['lastName'] ?? ''}'
              .trim();
      final adminEmail = adminData['email'] ?? 'Admin';
      final targetName =
          '${targetData['firstName'] ?? ''} ${targetData['lastName'] ?? ''}'
              .trim();
      final targetEmail = targetData['email'] ?? '';

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Reference to the attendance day document
        final dayRef = FirebaseFirestore.instance
            .collection('attendance')
            .doc(targetUid)
            .collection('days')
            .doc(dateId);

        // Reference to the event document
        final eventRef = FirebaseFirestore.instance
            .collection('attendance')
            .doc(targetUid)
            .collection('events')
            .doc();

        // Update attendance day with same structure as clockIn
        // Get existing data to preserve timing info if it exists
        final existingDoc = await transaction.get(dayRef);
        final existingData = existingDoc.data() ?? {};

        transaction.set(dayRef, {
          'dayId': dateId,
          'status': 'present',
          'timingStatus':
              existingData['timingStatus'], // Preserve existing timing
          'inAt': existingData['inAt'] ?? FieldValue.serverTimestamp(),
          'clockInAt':
              existingData['clockInAt'] ?? FieldValue.serverTimestamp(),
          'inLoc': existingData['inLoc'],
          'clockInLoc': existingData['clockInLoc'],
          'outAt': existingData['outAt'],
          'clockOutAt': existingData['clockOutAt'],
          'outLoc': existingData['outLoc'],
          'clockOutLoc': existingData['clockOutLoc'],
          'lateReason': existingData['lateReason'],
          'adminMarked': true,
          'markedByAdmin': adminUid,
          'markedByAdminEmail': adminEmail,
          'markedByAdminName': adminName,
          'markedAt': FieldValue.serverTimestamp(),
          'createdAt':
              existingData['createdAt'] ?? FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Create audit event
        transaction.set(eventRef, {
          'type': 'admin_action',
          'at': FieldValue.serverTimestamp(),
          'meta': {
            'adminId': adminUid,
            'adminName': adminName,
            'adminEmail': adminEmail,
            'action': 'mark_present',
            'targetDate': dateId,
            'targetUserId': targetUid,
            'targetUserName': targetName,
            'targetUserEmail': targetEmail,
          },
        });
      });

      // Send notification to the user after successful update
      await _sendAdminActionNotification(
        targetUid: targetUid,
        adminUid: adminUid,
        action: 'marked_present',
        title: 'Attendance Updated',
        body:
            'Your attendance for $dateId has been marked as Present by admin ($adminName)',
        dateId: dateId,
      );

      // Log comprehensive admin action for audit trail
      await FirebaseFirestore.instance.collection('adminActions').add({
        'action': 'mark_present',
        'adminId': adminUid,
        'adminName': adminName,
        'adminEmail': adminEmail,
        'targetUserId': targetUid,
        'targetUserName': targetName,
        'targetUserEmail': targetEmail,
        'attendanceDate': dateId,
        'timestamp': FieldValue.serverTimestamp(),
        'details': 'Admin manually marked user as present for $dateId',
      });
    } catch (e) {
      throw Exception('Failed to mark student present: $e');
    }
  }

  /// Admin marks a student as absent for a specific date
  static Future<void> adminMarkAbsent(
    String adminUid,
    String targetUid,
    String dateId, {
    String? reason,
  }) async {
    try {
      // Get admin and target user info for notifications
      final appUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(adminUid)
          .get();

      final targetUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .get();

      final adminData = appUserDoc.data() ?? {};
      final targetData = targetUserDoc.data() ?? {};

      final adminName =
          '${adminData['firstName'] ?? ''} ${adminData['lastName'] ?? ''}'
              .trim();
      final adminEmail = adminData['email'] ?? 'Admin';
      final targetName =
          '${targetData['firstName'] ?? ''} ${targetData['lastName'] ?? ''}'
              .trim();
      final targetEmail = targetData['email'] ?? '';

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Reference to the attendance day document
        final dayRef = FirebaseFirestore.instance
            .collection('attendance')
            .doc(targetUid)
            .collection('days')
            .doc(dateId);

        // Reference to the event document
        final eventRef = FirebaseFirestore.instance
            .collection('attendance')
            .doc(targetUid)
            .collection('events')
            .doc();

        // Get existing data to preserve some fields if they exist
        final existingDoc = await transaction.get(dayRef);
        final existingData = existingDoc.data() ?? {};

        // Prepare update data - mark absent but preserve timing info if user had checked in
        Map<String, dynamic> updateData = {
          'dayId': dateId,
          'status': 'absent',
          'timingStatus': null,
          'inAt': null,
          'clockInAt': null,
          'inLoc': null,
          'clockInLoc': null,
          'outAt': null,
          'clockOutAt': null,
          'outLoc': null,
          'clockOutLoc': null,
          'adminMarked': true,
          'markedByAdmin': adminUid,
          'markedByAdminEmail': adminEmail,
          'markedByAdminName': adminName,
          'markedAt': FieldValue.serverTimestamp(),
          'createdAt':
              existingData['createdAt'] ?? FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (reason != null) {
          updateData['lateReason'] = reason;
          updateData['absentReason'] = reason;
        }

        // Update attendance day
        transaction.set(dayRef, updateData, SetOptions(merge: true));

        // Create audit event
        Map<String, dynamic> eventMeta = {
          'adminId': adminUid,
          'adminName': adminName,
          'adminEmail': adminEmail,
          'action': 'mark_absent',
          'targetDate': dateId,
          'targetUserId': targetUid,
          'targetUserName': targetName,
          'targetUserEmail': targetEmail,
        };

        if (reason != null) {
          eventMeta['reason'] = reason;
        }

        transaction.set(eventRef, {
          'type': 'admin_action',
          'at': FieldValue.serverTimestamp(),
          'meta': eventMeta,
        });
      });

      // Send notification to the user after successful update
      final reasonText = reason != null ? ' Reason: $reason' : '';
      await _sendAdminActionNotification(
        targetUid: targetUid,
        adminUid: adminUid,
        action: 'marked_absent',
        title: 'Attendance Updated',
        body:
            'Your attendance for $dateId has been marked as Absent by admin ($adminName).$reasonText',
        dateId: dateId,
      );

      // Log comprehensive admin action for audit trail
      await FirebaseFirestore.instance.collection('adminActions').add({
        'action': 'mark_absent',
        'adminId': adminUid,
        'adminName': adminName,
        'adminEmail': adminEmail,
        'targetUserId': targetUid,
        'targetUserName': targetName,
        'targetUserEmail': targetEmail,
        'attendanceDate': dateId,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'details': reason != null
            ? 'Admin manually marked user as absent for $dateId with reason: $reason'
            : 'Admin manually marked user as absent for $dateId',
      });
    } catch (e) {
      throw Exception('Failed to mark student absent: $e');
    }
  }

  /// Admin edits the late reason for a student's attendance
  static Future<void> adminEditLateReason(
    String adminUid,
    String targetUid,
    String dateId,
    String lateReason,
  ) async {
    try {
      // Get admin and target user info for notifications
      final appUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(adminUid)
          .get();

      final targetUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .get();

      final adminData = appUserDoc.data() ?? {};
      final targetData = targetUserDoc.data() ?? {};

      final adminName =
          '${adminData['firstName'] ?? ''} ${adminData['lastName'] ?? ''}'
              .trim();
      final adminEmail = adminData['email'] ?? 'Admin';
      final targetName =
          '${targetData['firstName'] ?? ''} ${targetData['lastName'] ?? ''}'
              .trim();
      final targetEmail = targetData['email'] ?? '';

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Reference to the attendance day document
        final dayRef = FirebaseFirestore.instance
            .collection('attendance')
            .doc(targetUid)
            .collection('days')
            .doc(dateId);

        // Reference to the event document
        final eventRef = FirebaseFirestore.instance
            .collection('attendance')
            .doc(targetUid)
            .collection('events')
            .doc();

        // Update late reason with admin tracking
        transaction.set(dayRef, {
          'lateReason': lateReason,
          'lateReasonEditedBy': adminUid,
          'lateReasonEditedByName': adminName,
          'lateReasonEditedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Create audit event
        transaction.set(eventRef, {
          'type': 'admin_action',
          'at': FieldValue.serverTimestamp(),
          'meta': {
            'adminId': adminUid,
            'adminName': adminName,
            'adminEmail': adminEmail,
            'action': 'edit_late_reason',
            'targetDate': dateId,
            'targetUserId': targetUid,
            'targetUserName': targetName,
            'targetUserEmail': targetEmail,
            'reason': lateReason,
          },
        });
      });

      // Send notification to the user after successful update
      await _sendAdminActionNotification(
        targetUid: targetUid,
        adminUid: adminUid,
        action: 'edited_late_reason',
        title: 'Late Reason Updated',
        body:
            'Your late reason for $dateId has been updated by admin ($adminName): $lateReason',
        dateId: dateId,
      );

      // Log comprehensive admin action for audit trail
      await FirebaseFirestore.instance.collection('adminActions').add({
        'action': 'edit_late_reason',
        'adminId': adminUid,
        'adminName': adminName,
        'adminEmail': adminEmail,
        'targetUserId': targetUid,
        'targetUserName': targetName,
        'targetUserEmail': targetEmail,
        'attendanceDate': dateId,
        'newLateReason': lateReason,
        'timestamp': FieldValue.serverTimestamp(),
        'details': 'Admin edited late reason for $dateId to: $lateReason',
      });
    } catch (e) {
      throw Exception('Failed to edit late reason: $e');
    }
  }

  /// Check if current user is admin
  static Future<bool> isCurrentUserAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      return userDoc.data()?['role'] == 'admin';
    } catch (e) {
      return false;
    }
  }

  /// Get students for admin panel
  static Stream<QuerySnapshot> getStudentsStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .orderBy('lastName', descending: false)
        .snapshots();
  }

  /// Get attendance data for a student within date range
  static Stream<QuerySnapshot> getStudentAttendanceStream(
    String studentUid,
    DateTime startDate,
    DateTime endDate,
  ) {
    // Use JmTime.dateId format (YYYY-MM-DD) to match how attendance is stored
    final startDateStr = JmTime.dateId(startDate);
    final endDateStr = JmTime.dateId(endDate);

    return FirebaseFirestore.instance
        .collection('attendance')
        .doc(studentUid)
        .collection('days')
        .where('dayId', isGreaterThanOrEqualTo: startDateStr)
        .where('dayId', isLessThanOrEqualTo: endDateStr)
        .orderBy('dayId')
        .snapshots();
  }

  /// Send notification to user for admin actions on their attendance
  static Future<void> _sendAdminActionNotification({
    required String targetUid,
    required String adminUid,
    required String action,
    required String title,
    required String body,
    String? dateId,
  }) async {
    try {
      // Get user's FCM token from their user document
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final fcmToken = userData['fcmToken'];
        final userName =
            '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                .trim();

        // Enhanced notification data for foreground handling
        final notificationData = {
          'type': 'attendance_update',
          'userId': targetUid,
          'title': title,
          'body': body,
          'action': action,
          'adminId': adminUid,
          'attendanceDate': dateId,
          'timestamp': DateTime.now().toIso8601String(),
          'priority': 'high',
          'show_in_foreground': 'true', // Key flag for foreground display
        };

        // Send enhanced push notification using FCM Messages collection
        if (fcmToken != null && fcmToken.toString().isNotEmpty) {
          try {
            await FirebaseFirestore.instance.collection('fcm_messages').add({
              'token': fcmToken,
              'notification': {'title': title, 'body': body},
              'data': notificationData,
              'android': {
                'notification': {
                  'channel_id': 'admin_actions',
                  'priority': 'high',
                  'notification_priority': 'PRIORITY_HIGH',
                  'visibility': 'public',
                  'default_sound': true,
                  'default_vibrate_timings': true,
                  'show_when': true,
                },
              },
              'apns': {
                'payload': {
                  'aps': {
                    'alert': {'title': title, 'body': body},
                    'badge': 1,
                    'sound': 'default',
                    'content-available':
                        1, // Ensures delivery even in foreground
                    'mutable-content': 1,
                  },
                },
              },
            });

            print('Enhanced push notification sent successfully to $userName');
          } catch (e) {
            print('Push notification failed: $e');
          }
        }

        // Always add to user's notifications subcollection for in-app notifications
        await FirebaseFirestore.instance
            .collection('users')
            .doc(targetUid)
            .collection('notifications')
            .add({
              'title': title,
              'body': body,
              'type': 'attendance_update',
              'priority': 'high',
              'read': false,
              'actionBy': adminUid,
              'action': action,
              'attendanceDate': dateId,
              'data': notificationData,
              'createdAt': FieldValue.serverTimestamp(),
            });

        print('Enhanced notification sent and stored for user $userName');
      }
    } catch (e) {
      print('Error sending admin action notification: $e');
    }
  }
}
