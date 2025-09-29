import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/services/attendance_service.dart';
import 'package:students_reminder/src/services/notification_service.dart';

class AdminService {
  AdminService._();
  static final instance = AdminService._();

  final _db = FirebaseFirestore.instance;

  // Helper function to check if current user is admin
  Future<bool> isCurrentUserAdmin() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return false;

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    return userData?['role'] == 'admin';
  }

  // REPORTS MANAGEMENT - Functions removed as they were unused

  // USER MANAGEMENT

  // Suspend a user
  Future<void> suspendUser(
    String userId, {
    String? reason,
    DateTime? until,
  }) async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final data = <String, dynamic>{
      'status': 'suspended',
      'suspendedAt': FieldValue.serverTimestamp(),
      'suspendedBy': currentUser.uid,
      'suspensionReason': reason,
    };

    if (until != null) {
      data['suspendedUntil'] = Timestamp.fromDate(until);
    }

    await _db.collection('users').doc(userId).update(data);

    // Send notification to user
    await _sendSuspensionNotification(
      userId,
      'suspended',
      reason: reason,
      until: until,
    );

    // Log admin action
    await _logAdminAction('user_suspend', {
      'userId': userId,
      'reason': reason,
      'until': until?.toIso8601String(),
    });
  }

  // Unsuspend a user
  Future<void> unsuspendUser(String userId) async {
    await _db.collection('users').doc(userId).update({
      'status': 'active',
      'suspendedAt': FieldValue.delete(),
      'suspendedBy': FieldValue.delete(),
      'suspensionReason': FieldValue.delete(),
      'suspendedUntil': FieldValue.delete(),
    });

    // Send notification to user
    await _sendSuspensionNotification(userId, 'unsuspended');

    // Log admin action
    await _logAdminAction('user_unsuspend', {'userId': userId});
  }

  // Flag a user (warning level)
  Future<void> flagUser(String userId, String reason) async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    await _db.collection('users').doc(userId).update({
      'flagged': true,
      'flaggedAt': FieldValue.serverTimestamp(),
      'flaggedBy': currentUser.uid,
      'flagReason': reason,
    });

    // Send notification to user
    await _sendFlagNotification(userId, 'flagged', reason: reason);

    // Log admin action
    await _logAdminAction('user_flag', {'userId': userId, 'reason': reason});
  }

  // Unflag a user
  Future<void> unflagUser(String userId) async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    await _db.collection('users').doc(userId).update({
      'flagged': FieldValue.delete(),
      'flaggedAt': FieldValue.delete(),
      'flaggedBy': FieldValue.delete(),
      'flagReason': FieldValue.delete(),
    });

    // Send notification to user
    await _sendFlagNotification(userId, 'unflagged');

    // Log admin action
    await _logAdminAction('user_unflag', {'userId': userId});
  }

  // Delete a user permanently
  Future<void> deleteUser(String userId) async {
    final batch = _db.batch();

    try {
      // 1. Delete user's notes
      final userNotesQuery = await _db
          .collection('users')
          .doc(userId)
          .collection('notes')
          .get();

      for (final noteDoc in userNotesQuery.docs) {
        batch.delete(noteDoc.reference);
      }

      // 2. Delete user's notifications
      final userNotificationsQuery = await _db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .get();

      for (final notificationDoc in userNotificationsQuery.docs) {
        batch.delete(notificationDoc.reference);
      }

      // 3. Delete user from public notes if any
      final publicNotesQuery = await _db
          .collection('public_notes')
          .where('userId', isEqualTo: userId)
          .get();

      for (final noteDoc in publicNotesQuery.docs) {
        batch.delete(noteDoc.reference);
      }

      // 4. Delete reports made by the user
      final reportsQuery = await _db
          .collection('reports')
          .where('reporterId', isEqualTo: userId)
          .get();

      for (final reportDoc in reportsQuery.docs) {
        batch.delete(reportDoc.reference);
      }

      // 5. Delete reports about the user
      final reportsAboutUserQuery = await _db
          .collection('reports')
          .where('targetUserId', isEqualTo: userId)
          .get();

      for (final reportDoc in reportsAboutUserQuery.docs) {
        batch.delete(reportDoc.reference);
      }

      // 6. Finally, delete the user document
      final userDocRef = _db.collection('users').doc(userId);
      batch.delete(userDocRef);

      // Commit the batch
      await batch.commit();

      // Log admin action
      await _logAdminAction('user_delete', {
        'userId': userId,
        'deletedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  // NOTE MODERATION

  // Flag a note
  Future<void> flagNote(String userId, String noteId, String reason) async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    await _db
        .collection('users')
        .doc(userId)
        .collection('notes')
        .doc(noteId)
        .update({
          'flagged': true,
          'flaggedAt': FieldValue.serverTimestamp(),
          'flaggedBy': currentUser.uid,
          'flagReason': reason,
        });

    // Log admin action
    await _logAdminAction('note_flag', {
      'userId': userId,
      'noteId': noteId,
      'reason': reason,
    });
  }

  // Unflag a note
  Future<void> unflagNote(String userId, String noteId) async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    await _db
        .collection('users')
        .doc(userId)
        .collection('notes')
        .doc(noteId)
        .update({
          'flagged': false,
          'unflaggedAt': FieldValue.serverTimestamp(),
          'unflaggedBy': currentUser.uid,
          'flagReason': FieldValue.delete(), // Remove the flag reason
        });

    // Log admin action
    await _logAdminAction('note_unflag', {'userId': userId, 'noteId': noteId});
  }

  // Delete a note
  Future<void> deleteNote(String userId, String noteId, String reason) async {
    // Log admin action before deletion
    await _logAdminAction('note_delete', {
      'userId': userId,
      'noteId': noteId,
      'reason': reason,
    });

    await _db
        .collection('users')
        .doc(userId)
        .collection('notes')
        .doc(noteId)
        .delete();
  }

  // ADMIN ACTIONS LOGGING

  Future<void> _logAdminAction(
    String actionType,
    Map<String, dynamic> details,
  ) async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    await _db.collection('adminActions').add({
      'actionType': actionType,
      'adminId': currentUser.uid,
      'adminEmail': currentUser.email,
      'timestamp': FieldValue.serverTimestamp(),
      'details': details,
    });
  }

  // REPORTING SYSTEM - Functions removed as they were unused

  // ATTENDANCE MANAGEMENT

  /// Get attendance overview for all students on a specific date
  Stream<QuerySnapshot<Map<String, dynamic>>> getAttendanceForDate(
    DateTime date,
  ) {
    return AttendanceService.streamAllUsersAttendanceForDate(date);
  }

  /// Get attendance for a specific user over a date range
  Stream<QuerySnapshot<Map<String, dynamic>>> getUserAttendanceRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) {
    return AttendanceService.streamUserAttendanceRange(
      userId,
      startDate,
      endDate,
    );
  }

  /// Get current week attendance overview
  Stream<QuerySnapshot<Map<String, dynamic>>> getCurrentWeekAttendance() {
    return AttendanceService.streamCurrentWeekAttendance();
  }

  /// Get attendance summary statistics for a user
  Future<Map<String, int>> getUserAttendanceSummary(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return AttendanceService.getAttendanceSummary(
      userId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Get attendance summary for all users in a course group
  Future<Map<String, Map<String, int>>> getCourseAttendanceSummary(
    String courseGroup, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Get all users in the course group
    final usersSnapshot = await _db
        .collection('users')
        .where('courseGroup', isEqualTo: courseGroup)
        .where('role', isEqualTo: 'student')
        .get();

    final summaries = <String, Map<String, int>>{};

    for (final userDoc in usersSnapshot.docs) {
      final userId = userDoc.id;
      final summary = await AttendanceService.getAttendanceSummary(
        userId,
        startDate: startDate,
        endDate: endDate,
      );
      summaries[userId] = summary;
    }

    return summaries;
  }

  /// Get students who are frequently absent (configurable threshold)
  Future<List<Map<String, dynamic>>> getFrequentAbsentees({
    int absentThreshold = 3, // days absent in the period
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final start =
        startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now();

    // Get all students
    final studentsSnapshot = await _db
        .collection('users')
        .where('role', isEqualTo: 'student')
        .get();

    final absentees = <Map<String, dynamic>>[];

    for (final studentDoc in studentsSnapshot.docs) {
      final userId = studentDoc.id;
      final userData = studentDoc.data();

      final summary = await AttendanceService.getAttendanceSummary(
        userId,
        startDate: start,
        endDate: end,
      );

      if (summary['absent']! >= absentThreshold) {
        absentees.add({
          'userId': userId,
          'name': '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
              .trim(),
          'email': userData['email'] ?? '',
          'courseGroup': userData['courseGroup'] ?? '',
          'attendanceSummary': summary,
        });
      }
    }

    // Sort by absence count (highest first)
    absentees.sort(
      (a, b) => (b['attendanceSummary']['absent'] as int).compareTo(
        a['attendanceSummary']['absent'] as int,
      ),
    );

    return absentees;
  }

  /// Mark a student absent for a specific date (admin override)
  Future<void> markStudentAbsent(
    String userId,
    DateTime date, {
    String? reason,
  }) async {
    final dateId = JmTime.dateId(date);
    final docRef = _db
        .collection('attendance')
        .doc(userId)
        .collection('days')
        .doc(dateId);

    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    await docRef.set({
      'dayId': dateId,
      'status': 'absent',
      'inAt': null,
      'inLoc': null,
      'outAt': null,
      'outLoc': null,
      'lateReason': reason,
      'adminOverride': true,
      'overrideBy': currentUser.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Update attendance status (admin correction)
  Future<void> updateAttendanceStatus(
    String userId,
    DateTime date,
    String status, {
    String? reason,
  }) async {
    final dateId = JmTime.dateId(date);
    final docRef = _db
        .collection('attendance')
        .doc(userId)
        .collection('days')
        .doc(dateId);

    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    await docRef.update({
      'status': status,
      'lateReason': reason,
      'adminOverride': true,
      'overrideBy': currentUser.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Send suspension/unsuspension notification to user
  Future<void> _sendSuspensionNotification(
    String userId,
    String action, {
    String? reason,
    DateTime? until,
  }) async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) return;

      // Get admin info
      final adminDoc = await _db.collection('users').doc(currentUser.uid).get();
      final adminData = adminDoc.data();
      final adminName = adminData != null
          ? '${adminData['firstName'] ?? ''} ${adminData['lastName'] ?? ''}'
                .trim()
          : 'Administrator';

      // Get user info
      final userDoc = await _db.collection('users').doc(userId).get();
      final userData = userDoc.data();
      final userName = userData != null
          ? '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                .trim()
          : 'User';

      String title, body;
      String notificationType;

      if (action == 'suspended') {
        title = 'Account Suspended';
        body = reason != null
            ? 'Your account has been suspended. Reason: $reason'
            : 'Your account has been suspended by an administrator.';
        if (until != null) {
          final untilStr = until.toLocal().toString().split(' ')[0];
          body += ' Suspension will be lifted on $untilStr.';
        }
        notificationType = 'account_suspended';
      } else {
        title = 'Account Restored';
        body =
            'Your account suspension has been lifted. You now have full access to the app.';
        notificationType = 'account_unsuspended';
      }

      // Store notification in user's notifications collection
      await _db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
            'title': title,
            'body': body,
            'type': notificationType,
            'priority': 'high',
            'read': false,
            'actionBy': currentUser.uid,
            'adminName': adminName,
            'action': action,
            'reason': reason,
            'suspendedUntil': until != null ? Timestamp.fromDate(until) : null,
            'createdAt': FieldValue.serverTimestamp(),
          });

      // Send push notification if user has FCM token
      if (userData?['fcmToken'] != null) {
        try {
          await NotificationService.sendPushNotification(
            deviceToken: userData!['fcmToken'],
            title: title,
            body: body,
          );
          print('Push notification sent to $userName for $action');
        } catch (e) {
          print('Failed to send push notification: $e');
        }
      }

      print('$action notification sent to user $userName');
    } catch (e) {
      print('Error sending suspension notification: $e');
    }
  }

  /// Send flag/unflag notification to user
  Future<void> _sendFlagNotification(
    String userId,
    String action, {
    String? reason,
  }) async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) return;

      // Get admin info
      final adminDoc = await _db.collection('users').doc(currentUser.uid).get();
      final adminData = adminDoc.data();
      final adminName = adminData != null
          ? '${adminData['firstName'] ?? ''} ${adminData['lastName'] ?? ''}'
                .trim()
          : 'Administrator';

      // Get user info
      final userDoc = await _db.collection('users').doc(userId).get();
      final userData = userDoc.data();
      final userName = userData != null
          ? '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                .trim()
          : 'User';

      String title, body;
      String notificationType;

      if (action == 'flagged') {
        title = 'Account Flagged';
        body = reason != null
            ? 'Your account has been flagged. Reason: $reason'
            : 'Your account has been flagged by an administrator.';
        body +=
            ' Please review your recent activity and follow community guidelines.';
        notificationType = 'account_flagged';
      } else {
        title = 'Flag Removed';
        body =
            'The flag on your account has been removed. Thank you for following community guidelines.';
        notificationType = 'account_unflagged';
      }

      // Store notification in user's notifications collection
      await _db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
            'title': title,
            'body': body,
            'type': notificationType,
            'priority': 'medium',
            'read': false,
            'actionBy': currentUser.uid,
            'adminName': adminName,
            'action': action,
            'reason': reason,
            'createdAt': FieldValue.serverTimestamp(),
          });

      // Send push notification if user has FCM token
      if (userData?['fcmToken'] != null) {
        try {
          await NotificationService.sendPushNotification(
            deviceToken: userData!['fcmToken'],
            title: title,
            body: body,
          );
          print('Push notification sent to $userName for $action');
        } catch (e) {
          print('Failed to send push notification: $e');
        }
      }

      print('$action notification sent to user $userName');
    } catch (e) {
      print('Error sending flag notification: $e');
    }
  }
}
