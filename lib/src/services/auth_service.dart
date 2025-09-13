import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:students_reminder/src/services/session_manager.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Stream<User?> authStateChanged() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> register({
    required String firstName,
    required String lastName,
    required String courseGroup,
    required String email,
    required String phone,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;
    await _db.collection('users').doc(uid).set({
      'firstName': firstName,
      'lastName': lastName,
      'courseGroup': courseGroup,
      'email': email,
      'phone': phone,
      'gender': null,
      'bio': null,
      'role': 'student', // Default role for new users
      'createdAt': FieldValue.serverTimestamp(),
    });
    await SessionManager.onLoginSuccess();
    return cred;
  }

  //Login CODE
  Future<UserCredential> login(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await SessionManager.onLoginSuccess();
    return cred;
  }

  //Logout CODE
  Future<void> logout() async {
    try {
      // Clear session first to prevent race conditions
      await SessionManager.clear();
      // Then sign out from Firebase
      await _auth.signOut();
    } catch (e) {
      print('Error during logout: $e');
      // Ensure we still sign out even if session clearing fails
      try {
        await _auth.signOut();
      } catch (signOutError) {
        print('Error signing out: $signOutError');
        rethrow;
      }
    }
  }

  // Password Reset CODE
  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);
}
//   // Password Reset CODE
//   Future<void> sendPasswordReset(String email) =>
//       _auth.sendPasswordResetEmail(email: email);
// }
