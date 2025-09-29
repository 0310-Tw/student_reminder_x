import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
      print('🔃 Starting logout process...');

      // Clear session first to prevent race conditions
      await SessionManager.clear();
      print('✅ Session cleared');

      // Small delay to let any active listeners settle
      await Future.delayed(Duration(milliseconds: 100));

      // Then sign out from Firebase
      await _auth.signOut();
      print('✅ Firebase sign out completed');
    } catch (e) {
      print('❌ Error during logout: $e');

      // If it's a permission error during logout, just continue with sign out
      if (e.toString().contains('permission-denied')) {
        print(
          '🔄 Permission denied during logout (expected), continuing with sign out...',
        );
      }

      // Ensure we still sign out even if session clearing fails
      try {
        await _auth.signOut();
        print('✅ Firebase sign out completed (fallback)');
      } catch (signOutError) {
        print('❌ Error signing out: $signOutError');
        // Don't rethrow permission errors during logout as they're expected
        if (!signOutError.toString().contains('permission-denied')) {
          rethrow;
        }
      }
    }
  }

  // Password Reset CODE
  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  // Google Sign-In CODE
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      // If user cancels the sign-in flow
      if (googleUser == null) {
        throw Exception('Google Sign-In was cancelled');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google user credential
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      // Check if this is a new user and create a Firestore document
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        final user = userCredential.user!;
        await _db.collection('users').doc(user.uid).set({
          'firstName': user.displayName?.split(' ').first ?? '',
          'lastName': user.displayName!.split(' ').length > 1
              ? user.displayName!.split(' ').sublist(1).join(' ')
              : '',
          'courseGroup': '', // Will need to be set later
          'email': user.email ?? '',
          'phone': '', // Will need to be set later
          'gender': null,
          'bio': null,
          'role': 'student', // Default role for new users
          'createdAt': FieldValue.serverTimestamp(),
          'signInMethod': 'google',
        });
      }

      await SessionManager.onLoginSuccess();
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception('Firebase Auth Error: ${e.message}');
    } catch (e) {
      throw Exception('Google Sign-In Error: $e');
    }
  }

  // Google Sign-In for Registration - returns user info without creating account
  Future<Map<String, String?>> getGoogleUserInfo() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      // If user cancels the sign-in flow
      if (googleUser == null) {
        throw Exception('Google Sign-In was cancelled');
      }

      // Return the user information for form pre-filling
      return {
        'firstName': googleUser.displayName?.split(' ').first ?? '',
        'lastName': googleUser.displayName!.split(' ').length > 1
            ? googleUser.displayName!.split(' ').sublist(1).join(' ')
            : '',
        'email': googleUser.email,
      };
    } catch (e) {
      throw Exception('Google Sign-In Error: $e');
    }
  }

  // Register with Google - complete registration with additional info
  Future<UserCredential> registerWithGoogle({
    required String firstName,
    required String lastName,
    required String courseGroup,
    required String phone,
  }) async {
    try {
      // Get the currently signed-in Google user
      final GoogleSignInAccount? googleUser = GoogleSignIn().currentUser;

      if (googleUser == null) {
        throw Exception('No Google user found. Please sign in first.');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google user credential
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      // Create/update the Firestore document with complete user info
      final user = userCredential.user!;
      await _db.collection('users').doc(user.uid).set({
        'firstName': firstName,
        'lastName': lastName,
        'courseGroup': courseGroup,
        'email': user.email ?? '',
        'phone': phone,
        'gender': null,
        'bio': null,
        'role': 'student',
        'createdAt': FieldValue.serverTimestamp(),
        'signInMethod': 'google',
      });

      await SessionManager.onLoginSuccess();
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception('Firebase Auth Error: ${e.message}');
    } catch (e) {
      throw Exception('Google Registration Error: $e');
    }
  }
}

//   // Password Reset CODE
//   Future<void> sendPasswordReset(String email) =>
//       _auth.sendPasswordResetEmail(email: email);
// }
