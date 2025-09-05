// file: lib/src/admin/services/attendance_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AttendanceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Admin marks a student as present for a specific date
  static Future<void> adminMarkPresent(
    String adminUid,
    String targetUid,
    String yyyyMMdd,
  ) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Reference to the attendance day document
        final dayRef = _firestore
            .collection('attendance')
            .doc(targetUid)
            .collection('days')
            .doc(yyyyMMdd);

        // Reference to the event document
        final eventRef = _firestore
            .collection('attendance')
            .doc(targetUid)
            .collection('events')
            .doc();

        // Update attendance day with merge option to preserve existing fields
        transaction.set(dayRef, {
          'date': yyyyMMdd,
          'status': 'present',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Create audit event
        transaction.set(eventRef, {
          'type': 'admin_action',
          'at': FieldValue.serverTimestamp(),
          'meta': {
            'adminId': adminUid,
            'action': 'mark_present',
            'targetDate': yyyyMMdd,
          },
        });
      });
    } catch (e) {
      throw Exception('Failed to mark student present: $e');
    }
  }

  /// Admin marks a student as absent for a specific date
  static Future<void> adminMarkAbsent(
    String adminUid,
    String targetUid,
    String yyyyMMdd, {
    String? reason,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Reference to the attendance day document
        final dayRef = _firestore
            .collection('attendance')
            .doc(targetUid)
            .collection('days')
            .doc(yyyyMMdd);

        // Reference to the event document
        final eventRef = _firestore
            .collection('attendance')
            .doc(targetUid)
            .collection('events')
            .doc();

        // Prepare update data
        Map<String, dynamic> updateData = {
          'date': yyyyMMdd,
          'status': 'absent',
          'clockInAt': null,
          'clockInLoc': null,
          'clockOutAt': null,
          'clockOutLoc': null,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (reason != null) {
          updateData['lateReason'] = reason;
        }

        // Update attendance day
        transaction.set(dayRef, updateData, SetOptions(merge: true));

        // Create audit event
        Map<String, dynamic> eventMeta = {
          'adminId': adminUid,
          'action': 'mark_absent',
          'targetDate': yyyyMMdd,
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
    } catch (e) {
      throw Exception('Failed to mark student absent: $e');
    }
  }

  /// Admin edits the late reason for a student's attendance
  static Future<void> adminEditLateReason(
    String adminUid,
    String targetUid,
    String yyyyMMdd,
    String lateReason,
  ) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Reference to the attendance day document
        final dayRef = _firestore
            .collection('attendance')
            .doc(targetUid)
            .collection('days')
            .doc(yyyyMMdd);

        // Reference to the event document
        final eventRef = _firestore
            .collection('attendance')
            .doc(targetUid)
            .collection('events')
            .doc();

        // Update late reason
        transaction.set(dayRef, {
          'lateReason': lateReason,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Create audit event
        transaction.set(eventRef, {
          'type': 'admin_action',
          'at': FieldValue.serverTimestamp(),
          'meta': {
            'adminId': adminUid,
            'action': 'edit_late_reason',
            'targetDate': yyyyMMdd,
            'reason': lateReason,
          },
        });
      });
    } catch (e) {
      throw Exception('Failed to edit late reason: $e');
    }
  }

  /// Check if current user is admin
  static Future<bool> isCurrentUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      return userDoc.data()?['role'] == 'admin';
    } catch (e) {
      return false;
    }
  }

  /// Get students for admin panel
  static Stream<QuerySnapshot> getStudentsStream() {
    // Get all users and filter out admins in the UI if needed
    // This ensures we capture users who might not have a 'role' field set
    return _firestore
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
    final startDateStr = _formatDate(startDate);
    final endDateStr = _formatDate(endDate);

    return _firestore
        .collection('attendance')
        .doc(studentUid)
        .collection('days')
        .where('date', isGreaterThanOrEqualTo: startDateStr)
        .where('date', isLessThanOrEqualTo: endDateStr)
        .orderBy('date')
        .snapshots();
  }

  /// Helper method to format date as YYYYMMDD
  static String _formatDate(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  /// Get today's date as YYYYMMDD string
  static String getTodayString() {
    return _formatDate(DateTime.now());
  }
}
