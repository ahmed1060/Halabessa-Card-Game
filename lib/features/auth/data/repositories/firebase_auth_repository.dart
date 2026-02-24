import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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
      displayName: (user.displayName != null && user.displayName!.trim().isNotEmpty) ? user.displayName! : 'Player',
      avatarUrl: user.photoURL,
    );
  }

  @override
  Stream<AppUser?> get authStateChanges {
    return _firebaseAuth.userChanges().map(_userFromFirebase);
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
    try {
       final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
       if (googleUser == null) return null;

       final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
       final credential = firebase_auth.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
       );

       final userCredential = await _firebaseAuth.signInWithCredential(credential);
       return _userFromFirebase(userCredential.user);
    } catch (e) {
       debugPrint("Google Sign In failed: $e");
       rethrow;
    }
  }

  @override
  Future<AppUser?> signInWithFacebook() async {
    try {
       final LoginResult result = await FacebookAuth.instance.login();
       if (result.status == LoginStatus.success) {
          final credential = firebase_auth.FacebookAuthProvider.credential(result.accessToken!.tokenString);
          final userCredential = await _firebaseAuth.signInWithCredential(credential);
          return _userFromFirebase(userCredential.user);
       }
       return null;
    } catch (e) {
       debugPrint("Facebook Sign In failed: $e");
       rethrow;
    }
  }

  @override
  Future<AppUser?> signInWithApple() async {
    try {
       final credential = await SignInWithApple.getAppleIDCredential(
          scopes: [
             AppleIDAuthorizationScopes.email,
             AppleIDAuthorizationScopes.fullName,
          ],
       );
       
       final oAuthCredential = firebase_auth.OAuthProvider('apple.com').credential(
          idToken: credential.identityToken,
          accessToken: credential.authorizationCode,
       );
       
       final userCredential = await _firebaseAuth.signInWithCredential(oAuthCredential);
       return _userFromFirebase(userCredential.user);
    } catch (e) {
       debugPrint("Apple Sign In failed: $e");
       rethrow;
    }
  }

  @override
  Future<AppUser?> signInAnonymously({String? displayName}) async {
    try {
      final credential = await _firebaseAuth.signInAnonymously();
      if (displayName != null && displayName.trim().isNotEmpty) {
        await credential.user?.updateDisplayName(displayName.trim());
        // We need to reload the user to get the updated display name in the returned AppUser
        await credential.user?.reload();
        // Force token refresh to trigger authStateChanges listener with new data
        await credential.user?.getIdToken(true);
      }
      // Re-fetch the current user instance from Firebase after reload to ensure we have the latest payload
      final updatedUser = _firebaseAuth.currentUser;
      return _userFromFirebase(updatedUser);
    } catch (e) {
      debugPrint("Anonymous Sign In failed: \$e");
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  @override
  Future<void> resetPassword(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  @override
  Future<void> updateEmail(String newEmail) async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await user.verifyBeforeUpdateEmail(newEmail);
    }
  }
}
