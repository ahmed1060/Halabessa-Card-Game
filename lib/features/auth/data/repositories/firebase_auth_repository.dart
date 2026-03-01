import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'dart:math';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../domain/models/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final firebase_auth.FirebaseAuth _firebaseAuth;

  FirebaseAuthRepository(this._firebaseAuth);

  Future<void> _syncUserToDatabase(AppUser user) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      
      // Check if user exists to preserve stats, or initialize if new
      final doc = await docRef.get();
      if (!doc.exists) {
        await docRef.set(user.toJson());
      } else {
          // Only update basic profile info, preserving scores/stats
        await docRef.update({
          'displayName': user.displayName,
          'email': user.email,
          'avatarUrl': user.avatarUrl,
          'inventory': user.inventory,
          // 'isAdmin' is preserved in Firestore
        });
      }

      // Legacy Sync: Keep RTDB for presence/lobby lookups if needed, 
      // but only the bare minimum.
      final rtdbRef = FirebaseDatabase.instance.ref('users').child(user.uid);
      await rtdbRef.update({
        'displayName': user.displayName,
        'email': user.email,
        'avatarUrl': user.avatarUrl,
        'inventory': user.inventory,
        // 'isAdmin' is preserved
      });
    } catch (e) {
      debugPrint("User Sync failed: $e");
    }
  }

  AppUser? _userFromFirebase(firebase_auth.User? user) {
    if (user == null) {
      return null;
    }
    return AppUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: (user.displayName != null && user.displayName!.trim().isNotEmpty) ? user.displayName! : 'Player',
      avatarUrl: user.photoURL,
      isAdmin: user.email == 'ahmed.hossam1060@gmail.com',
    );
  }

  @override
  Stream<AppUser?> get authStateChanges {
    return _firebaseAuth.userChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .get();
            
        if (doc.exists && doc.data() != null) {
          return AppUser.fromJson(doc.data()!, firebaseUser.uid);
        }
      } catch (e) {
        debugPrint("Error fetching Firestore user: $e");
      }
      
      return _userFromFirebase(firebaseUser);
    });
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
      final user = _userFromFirebase(credential.user);
      if (user != null) await _syncUserToDatabase(user);
      return user;
    } on firebase_auth.FirebaseAuthException catch (e) {
      debugPrint("Email Login failed: ${e.code}");
      
      // If Firebase returns generic "invalid-credential" (common with email enumeration protection),
      // we manually check Firestore to give the specific message the user wants.
      if (e.code == 'invalid-credential') {
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();
              
          if (snapshot.docs.isEmpty) {
            // No user found with this email in our database
            throw firebase_auth.FirebaseAuthException(
              code: 'user-not-found',
              message: 'This email is not registered.',
            );
          } else {
            // User exists, so the password must be wrong
            throw firebase_auth.FirebaseAuthException(
              code: 'wrong-password',
              message: 'Incorrect password.',
            );
          }
        } catch (checkError) {
          if (checkError is firebase_auth.FirebaseAuthException) rethrow;
          // If Firestore check fails, fall back to the original error
          rethrow;
        }
      }
      rethrow;
    } catch (e) {
      debugPrint("Email Login failed: $e");
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
      
      // Assign Random Default Avatar
      final random = Random();
      final avatarIndex = random.nextInt(6) + 1;
      final defaultAvatar = 'assets/images/avatars/avatar$avatarIndex.png';
      
      await credential.user?.updateDisplayName(displayName);
      await credential.user?.updatePhotoURL(defaultAvatar);
      
      // Reload to ensure we have the photoURL
      await credential.user?.reload();
      
      final user = _userFromFirebase(_firebaseAuth.currentUser);
      if (user != null) await _syncUserToDatabase(user);
      return user;
    } catch (e) {
      debugPrint("Email Sign Up failed: $e");
      rethrow;
    }
  }

  @override
  Future<AppUser?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final googleProvider = firebase_auth.GoogleAuthProvider();
        final userCredential = await _firebaseAuth.signInWithPopup(googleProvider);
        final user = _userFromFirebase(userCredential.user);
        if (user != null) await _syncUserToDatabase(user);
        return user;
      }

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final user = _userFromFirebase(userCredential.user);
      if (user != null) await _syncUserToDatabase(user);
      return user;
    } catch (e) {
      debugPrint("Google Sign In failed: $e");
      rethrow;
    }
  }

  @override
  Future<AppUser?> signInWithFacebook() async {
    try {
      if (kIsWeb) {
        final facebookProvider = firebase_auth.FacebookAuthProvider();
        final userCredential = await _firebaseAuth.signInWithPopup(facebookProvider);
        final user = _userFromFirebase(userCredential.user);
        if (user != null) await _syncUserToDatabase(user);
        return user;
      }

      final LoginResult result = await FacebookAuth.instance.login();
      if (result.status == LoginStatus.success) {
        final credential = firebase_auth.FacebookAuthProvider.credential(result.accessToken!.tokenString);
        final userCredential = await _firebaseAuth.signInWithCredential(credential);
        final user = _userFromFirebase(userCredential.user);
        if (user != null) await _syncUserToDatabase(user);
        return user;
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
      
      // Assign Random Default Avatar if not set
      if (credential.user?.photoURL == null) {
        final random = Random();
        final avatarIndex = random.nextInt(6) + 1;
        final defaultAvatar = 'assets/images/avatars/avatar$avatarIndex.png';
        await credential.user?.updatePhotoURL(defaultAvatar);
      }

      if (displayName != null && displayName.trim().isNotEmpty) {
        await credential.user?.updateDisplayName(displayName.trim());
      }
      
      // Reload to ensure we have the updated info
      await credential.user?.reload();
      
      // Re-fetch the current user instance from Firebase after reload
      final updatedUser = _firebaseAuth.currentUser;
      final user = _userFromFirebase(updatedUser);
      if (user != null) await _syncUserToDatabase(user);
      return user;
    } catch (e) {
      debugPrint("Anonymous Sign In failed: $e");
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

  @override
  Future<void> updatePassword(String newPassword) async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await user.updatePassword(newPassword);
    }
  }

  @override
  Future<void> updateProfile({String? displayName, String? avatarUrl}) async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      if (displayName != null) await user.updateDisplayName(displayName);
      if (avatarUrl != null) await user.updatePhotoURL(avatarUrl);
      
      // Reload to get updated info
      await user.reload();
      final updatedUser = _firebaseAuth.currentUser;
      final appUser = _userFromFirebase(updatedUser);
      
      if (appUser != null) {
        // Fetch full record from firestore to preserve other fields
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          final fullUser = AppUser.fromJson(doc.data()!, user.uid);
          final mergedUser = fullUser.copyWith(
            displayName: displayName ?? fullUser.displayName,
            avatarUrl: avatarUrl ?? fullUser.avatarUrl,
          );
          await _syncUserToDatabase(mergedUser);
        } else {
          await _syncUserToDatabase(appUser);
        }
      }
    }
  }
}
