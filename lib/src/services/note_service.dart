import 'package:cloud_firestore/cloud_firestore.dart';

class NotesService {
  NotesService._();
  static final instance = NotesService._();
  final _db = FirebaseFirestore.instance;

  //Finding the destination for notes
  CollectionReference<Map<String, dynamic>> _notesCol(String uid) {
    return _db.collection('users').doc(uid).collection('notes');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMyNotes(String uid) {
    // Reduced logging to prevent excessive console output
    print('� NotesService: Starting notes stream for uid: $uid');

    try {
      // Create stream with ordering for consistent results
      final stream = _notesCol(
        uid,
      ).orderBy('aud_dt', descending: true).snapshots();

      // Add error handling without excessive logging
      return stream.handleError((error) {
        print('❌ NotesService stream error: $error');
      });
    } catch (e) {
      print('❌ NotesService setup error: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPublicNotes(String uid) {
    return _notesCol(uid)
        .where('visibility', isEqualTo: 'public')
        .orderBy('aud_dt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> publicFeeds() {
    return _db
        .collectionGroup('notes')
        .where('visibility', isEqualTo: 'public')
        .orderBy('aud_dt', descending: true)
        .limit(100)
        .snapshots();
  }

  Future<String> createNote(
    String uid, {
    required String title,
    required String body,
    required String visibility,
    DateTime? dueDate,
    List<String>? tags,
  }) async {
    final doc = await _notesCol(uid).add({
      'title': title,
      'body': body,
      'visibility': visibility,
      'authorId': uid, // Add authorId for security
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
      'tags': tags ?? [],
      'aud_dt': FieldValue.serverTimestamp(),
      // Initialize like-related fields
      'likesCount': 0,
      'likedBy': <String, dynamic>{},
    });
    return doc.id;
  }

  Future<void> updateNote(
    String uid,
    String noteId, {
    String? title,
    String? body,
    String? visibility,
    DateTime? dueDate,
    List<String>? tags,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (body != null) data['body'] = body;
    if (visibility != null) data['visibility'] = visibility;
    if (dueDate != null) {
      data['dueDate'] = Timestamp.fromDate(dueDate);
    }
    if (tags != null) data['tags'] = tags;
    await _notesCol(uid).doc(noteId).update(data);
  }

  Future<void> deleteNote(String uid, String noteId) {
    return _notesCol(uid).doc(noteId).delete();
  }

  Future<void> toggleLike({
    required DocumentReference<Map<String, dynamic>> noteRef,
    required String uid,
  }) async {
    print(
      '🔍 NotesService.toggleLike called with noteRef: ${noteRef.path}, uid: $uid',
    );
    final db = FirebaseFirestore.instance;

    await db.runTransaction((tx) async {
      print('🔍 Starting transaction for toggleLike');
      final snap = await tx.get(noteRef);
      if (!snap.exists) {
        print('❌ Note document does not exist: ${noteRef.path}');
        return;
      }

      final data = snap.data()!;
      print('🔍 Current note data keys: ${data.keys}');

      // Ensure likedBy and likesCount fields exist
      final Map<String, dynamic> likedBy = Map<String, dynamic>.from(
        data['likedBy'] ?? <String, dynamic>{},
      );
      final bool alreadyLiked = likedBy[uid] == true;
      final int currentCount = (data['likesCount'] ?? 0) as int;

      print('🔍 Current likedBy: $likedBy');
      print('🔍 User $uid already liked: $alreadyLiked');
      print('🔍 Current likes count: $currentCount');

      if (alreadyLiked) {
        // UNLIKE
        print('🔄 Performing UNLIKE operation');
        final newCount = (currentCount - 1).clamp(0, 1 << 30);
        tx.update(noteRef, {
          'likesCount': newCount,
          'likedBy.$uid': FieldValue.delete(),
        });
        print('✅ UNLIKE: New count will be $newCount');
      } else {
        // LIKE
        print('🔄 Performing LIKE operation');
        final newCount = currentCount + 1;
        // Initialize likedBy field if it doesn't exist
        final updateData = <String, dynamic>{
          'likesCount': newCount,
          'likedBy.$uid': true,
        };
        // If likedBy field doesn't exist in the document, initialize it
        if (!data.containsKey('likedBy')) {
          updateData['likedBy'] = <String, dynamic>{uid: true};
        }
        tx.update(noteRef, updateData);
        print('✅ LIKE: New count will be $newCount');
      }
    });
    print('✅ Transaction completed successfully');
  }

  Future<void> reportNote({
    required DocumentReference<Map<String, dynamic>> noteRef,
    required String uid,
    required String reason,
  }) async {
    final reportRef = noteRef.collection('reports').doc(uid);
    await reportRef.set({
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Remove the current user's report (optional "Undo report")
  Future<void> unreportNote({
    required DocumentReference<Map<String, dynamic>> noteRef,
    required String uid,
  }) async {
    await noteRef.collection('reports').doc(uid).delete();
  }

  /// Check if the current user has reported a specific note
  Stream<bool> isNoteReportedByUser({
    required DocumentReference<Map<String, dynamic>> noteRef,
    required String uid,
  }) {
    return noteRef
        .collection('reports')
        .doc(uid)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  /// Get user's report details for a specific note
  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserReportForNote({
    required DocumentReference<Map<String, dynamic>> noteRef,
    required String uid,
  }) {
    return noteRef.collection('reports').doc(uid).snapshots();
  }

  /// Admin: stream all report docs across all notes (newest first)
  Stream<QuerySnapshot<Map<String, dynamic>>> streamAllReportsForAdmin({
    int limit = 200,
  }) {
    return FirebaseFirestore.instance
        .collectionGroup('reports')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }
}
