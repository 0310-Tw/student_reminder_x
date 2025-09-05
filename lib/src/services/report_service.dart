import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:students_reminder/src/services/auth_service.dart';

class ReportService {
  ReportService._();
  static final instance = ReportService._();

  final _db = FirebaseFirestore.instance;

  // Report a note
  Future<void> reportNote({
    required String noteId,
    required String noteOwnerId,
    required String reason,
    String? description,
  }) async {
    await _db.collection('reports').add({
      'reportType': 'note',
      'targetId': noteId,
      'targetUserId': noteOwnerId,
      'reporterId': AuthService.instance.currentUser!.uid,
      'reporterEmail': AuthService.instance.currentUser!.email,
      'reason': reason,
      'description': description,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'metadata': {'noteId': noteId, 'noteOwnerId': noteOwnerId},
    });
  }

  // Report a user
  Future<void> reportUser({
    required String userId,
    required String reason,
    String? description,
  }) async {
    await _db.collection('reports').add({
      'reportType': 'user',
      'targetId': userId,
      'targetUserId': userId,
      'reporterId': AuthService.instance.currentUser!.uid,
      'reporterEmail': AuthService.instance.currentUser!.email,
      'reason': reason,
      'description': description,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'metadata': {'reportedUserId': userId},
    });
  }

  // Report inappropriate behavior
  Future<void> reportBehavior({
    required String reason,
    required String description,
    String? targetUserId,
    Map<String, dynamic>? additionalData,
  }) async {
    await _db.collection('reports').add({
      'reportType': 'behavior',
      'targetId': targetUserId ?? 'general',
      'targetUserId': targetUserId,
      'reporterId': AuthService.instance.currentUser!.uid,
      'reporterEmail': AuthService.instance.currentUser!.email,
      'reason': reason,
      'description': description,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'metadata': additionalData ?? {},
    });
  }

  // Get user's own reports
  Stream<QuerySnapshot<Map<String, dynamic>>> getMyReports() {
    return _db
        .collection('reports')
        .where('reporterId', isEqualTo: AuthService.instance.currentUser!.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get available report reasons
  List<String> getNoteReportReasons() {
    return [
      'Inappropriate content',
      'Harassment or bullying',
      'Spam',
      'False information',
      'Copyright violation',
      'Other',
    ];
  }

  List<String> getUserReportReasons() {
    return [
      'Harassment or bullying',
      'Inappropriate behavior',
      'Spam or fake account',
      'Impersonation',
      'Other',
    ];
  }

  List<String> getBehaviorReportReasons() {
    return [
      'Inappropriate language',
      'Bullying or harassment',
      'Discrimination',
      'Cheating or academic dishonesty',
      'Spam or unwanted content',
      'Other',
    ];
  }
}
