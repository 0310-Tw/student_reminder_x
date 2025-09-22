import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:students_reminder/src/services/auth_service.dart';

class UserService {
  UserService._();
  static final instance = UserService._();

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  Stream<DocumentSnapshot<Map<String, dynamic>>> getUser(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  Future<bool> isCurrentUserSuspended() async {
    try {
      final user = await _db
          .collection('users')
          .doc(AuthService.instance.currentUser?.uid)
          .get();
      final userData = user.data();
      return userData?['status'] == 'suspended';
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getUserSuspensionDetails(String uid) async {
    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      final userData = userDoc.data();

      if (userData?['status'] == 'suspended') {
        return {
          'suspended': true,
          'reason': userData?['suspensionReason'] ?? 'No reason provided',
          'suspendedAt': userData?['suspendedAt'],
        };
      }
      return {'suspended': false};
    } catch (e) {
      return {'suspended': false};
    }
  }

  // Students by course group
  Stream<QuerySnapshot<Map<String, dynamic>>> watchUserByCourseGroup(String course) {
    return _db
        .collection('users')
        .where('courseGroup', isEqualTo: course)
        .orderBy('lastName')
        .snapshots();
  }

  // Students with pending tasks (server-side filtered)
  Stream<QuerySnapshot<Map<String, dynamic>>> watchStudentsWithPendingTasks() {
    return _db
        .collection('users')
        .where('tasksPendingCount', isGreaterThan: 0)
        .snapshots();
  }

  // Students with reports
  Stream<QuerySnapshot<Map<String, dynamic>>> watchStudentsWithReports() {
    return _db
        .collection('users')
        .where('reportsCount', isGreaterThan: 0)
        .snapshots();
  }

  // Students with unread announcements (server-side filtered)
  Stream<QuerySnapshot<Map<String, dynamic>>> watchStudentsWithUnreadAnnouncements() {
    return _db
        .collection('users')
        .where('hasUnreadAnnouncements', isEqualTo: true)
        .snapshots();
  }

  // Students with upcoming events (server-side filtered)
  Stream<QuerySnapshot<Map<String, dynamic>>> watchStudentsWithUpcomingEvents() {
    return _db
        .collection('users')
        .where('upcomingEventsCount', isGreaterThan: 0)
        .snapshots();
  }

  // Stream of all students (for totals row)
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllStudents() {
    return _db
        .collection('users')
        .orderBy('lastName')
        .snapshots();
  }

  Future<void> updateMyProfile(
    String uid, {
    String? firstName,
    String? lastName,
    String? displayName,
    String? gender,
    String? phone,
    String? bio,
  }) async {
    final data = <String, dynamic>{};
    if (firstName != null) data['firstName'] = firstName;
    if (lastName != null) data['lastName'] = lastName;
    if (displayName != null) data['displayName'] = displayName;
    if (gender != null) data['gender'] = gender;
    if (phone != null) data['phone'] = phone;
    if (bio != null) data['bio'] = bio;
    if (data.isNotEmpty) {
      await _db.collection('users').doc(uid).update(data);
    }
  }

  Future<String?> uploadProfilePhoto({
    required String uid,
    required File file,
  }) async {
    final ref = _storage.ref().child(
      'avatars/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await ref.putFile(file);
    final url = await ref.getDownloadURL();
    await _db.collection('users').doc(uid).update({'photoUrl': url});
    return url;
  }

  Future<void> updateCoverImage(String uid, String coverUrl) async {
    await _db.collection('users').doc(uid).update({'coverUrl': coverUrl});
  }
}
