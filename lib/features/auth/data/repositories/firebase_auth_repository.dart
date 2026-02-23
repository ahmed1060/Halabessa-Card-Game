import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import '../../domain/models/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final firebase_auth.FirebaseAuth _firebaseAuth;

  FirebaseAuthRepository(this._firebaseAuth);

  AppUser? _userFromFirebase(firebase_auth.User? user) {
    if (user == null) {
      return null;
    }
    return AppUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? 'Player',
      avatarUrl: user.photoURL,
    );
  }

  @override
  Stream<AppUser?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map(_userFromFirebase);
  }

  @override
  AppUser? get currentUser {
    return _userFromFirebase(_firebaseAuth.currentUser);
  }

  @override
  Future<AppUser?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _userFromFirebase(credential.user);
    } catch (e) {
      debugPrint("Email Login failed: \$e");
      rethrow;
    }
  }

  @override
  Future<AppUser?> signUpWithEmail(
      String email, String password, String displayName) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(displayName);
      return _userFromFirebase(credential.user);
    } catch (e) {
      debugPrint("Email Sign Up failed: \$e");
      rethrow;
    }
  }

  @override
  Future<AppUser?> signInWithGoogle() async {
    // Basic stub for Google Sign-In. Full implementation requires google_sign_in package
    // and Firebase Options configuration for the platform.
    debugPrint("Google Sign In - To be implemented");
    return null;
  }

  @override
  Future<AppUser?> signInWithFacebook() async {
    // Basic stub for Facebook Sign-In. Requires flutter_facebook_auth package.
    debugPrint("Facebook Sign In - To be implemented");
    return null;
  }

  @override
  Future<AppUser?> signInWithApple() async {
    // Basic stub for Apple Sign-In. Requires sign_in_with_apple package.
    debugPrint("Apple Sign In - To be implemented");
    return null;
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  @override
  Future<void> resetPassword(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }
}
