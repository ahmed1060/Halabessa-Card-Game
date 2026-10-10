import 'profile_update.dart';
import 'session_profile_stream.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'dart:math';
import '../../domain/models/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  static const googleWebClientId =
      '54223815037-gg8pie8gu740lhci35i8df8f37mga6i2.apps.googleusercontent.com';
  static const googleIosClientId =
      '54223815037-647c34d72d4dih6mgv9j18btb8867crt.apps.googleusercontent.com';
  final firebase_auth.FirebaseAuth _firebaseAuth;

  FirebaseAuthRepository(this._firebaseAuth);

  @visibleForTesting
  Future<firebase_auth.UserCredential> signInOrLinkCredential(
    firebase_auth.AuthCredential credential,
  ) {
    final current = _firebaseAuth.currentUser;
    // Upgrading a guest must retain their UID, profile, purchases and room.
    // An already-used credential is surfaced, not silently switched to a
    // different account whose profile would hide the guest's progress.
    return current?.isAnonymous == true
        ? current!.linkWithCredential(credential)
        : _firebaseAuth.signInWithCredential(credential);
  }

  @visibleForTesting
  Future<firebase_auth.UserCredential> signInOrLinkPopup(
    firebase_auth.AuthProvider provider,
  ) {
    final current = _firebaseAuth.currentUser;
    return current?.isAnonymous == true
        ? current!.linkWithPopup(provider)
        : _firebaseAuth.signInWithPopup(provider);
  }

  @visibleForTesting
  Future<firebase_auth.UserCredential> signInOrLinkProvider(
    firebase_auth.AuthProvider provider,
  ) {
    final current = _firebaseAuth.currentUser;
    return current?.isAnonymous == true
        ? current!.linkWithProvider(provider)
        : _firebaseAuth.signInWithProvider(provider);
  }

  Future<void> _syncUserToDatabase(
    AppUser user, {
    bool isFullUpdate = false,
  }) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      // Check if user exists to preserve stats, or initialize if new
      final doc = await docRef.get();
      if (!doc.exists) {
        await docRef.set(user.toJson());
      } else {
        if (isFullUpdate) {
          // Full sync (usually from profile edit or after loading full record)
          await docRef.update(user.toJson());
        } else {
          // Targeted sync for Auth flows (preserving game-specific metadata)
          await docRef.update({
            'displayName': user.displayName,
            'email': user.email,
            'avatarUrl': user.avatarUrl,
            // 'username', 'inventory', 'points', etc. are NOT updated here to avoid overwriting with defaults
            'searchName': (user.username ?? user.displayName).toLowerCase(),
          });
        }
      }

      // Legacy Sync: Keep RTDB for presence/lobby lookups
      final rtdbRef = FirebaseDatabase.instance.ref('users').child(user.uid);
      if (isFullUpdate) {
        await rtdbRef.update(user.toJson());
      } else {
        await rtdbRef.update({
          'displayName': user.displayName,
          'email': user.email,
          'avatarUrl': user.avatarUrl,
          'searchName': (user.username ?? user.displayName).toLowerCase(),
        });
      }
    } catch (e) {
      debugPrint("User Sync failed: $e");
    }
  }

  AppUser? _userFromFirebase(firebase_auth.User? user) {
    if (user == null) {
      return null;
    }

    // isAdmin is never set true here, even for the admin's own email: this
    // object gets persisted by _syncUserToDatabase, and firestore.rules now
    // rejects any client write that sets isAdmin to anything but false (see
    // HAL-08). The presentation provider verifies admin with the server
    // independently, without blocking profile publication.
    return AppUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName:
          (user.displayName != null && user.displayName!.trim().isNotEmpty)
          ? user.displayName!
          : 'Player',
      avatarUrl: user.photoURL,
      isAdmin: false,
    );
  }

  @override
  Stream<AppUser?> get authStateChanges {
    return sessionProfileStream<
      firebase_auth.User,
      AppUser
    >(_firebaseAuth.userChanges(), (firebaseUser) {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .snapshots()
          .map((doc) {
            AppUser? user;
            if (doc.exists && doc.data() != null) {
              user = AppUser.fromJson(doc.data()!, firebaseUser.uid);
            }
            user ??= _userFromFirebase(firebaseUser);
            if (user == null) return null;

            // Publish the own profile immediately. Client-writable mirrors
            // must never grant admin access or manufacture server-owned social
            // relationships. Those domains are loaded separately per session.
            return user.copyWith(
              isAdmin: false,
              friends: const [],
              pendingFriendRequests: const [],
              sentFriendRequests: const [],
              friendInvites: const {},
            );
          });
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
    String email,
    String password,
    String displayName,
  ) async {
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
        final userCredential = await signInOrLinkPopup(googleProvider);
        final user = _userFromFirebase(userCredential.user);
        if (user != null) await _syncUserToDatabase(user);
        return user;
      }

      final GoogleSignInAccount? googleUser = await GoogleSignIn(
        clientId: defaultTargetPlatform == TargetPlatform.iOS
            ? googleIosClientId
            : null,
        serverClientId: googleWebClientId,
      ).signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      if (googleAuth.idToken == null) {
        throw firebase_auth.FirebaseAuthException(code: 'google-token-missing');
      }
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await signInOrLinkCredential(credential);
      final user = _userFromFirebase(userCredential.user);
      if (user != null) await _syncUserToDatabase(user);
      return user;
    } catch (e) {
      if (e is firebase_auth.FirebaseAuthException &&
          e.code == 'popup-closed-by-user')
        return null;
      debugPrint("Google Sign In failed: $e");
      rethrow;
    }
  }

  @override
  Future<AppUser?> signInWithFacebook() async {
    try {
      if (kIsWeb) {
        final facebookProvider = firebase_auth.FacebookAuthProvider();
        final userCredential = await signInOrLinkPopup(facebookProvider);
        final user = _userFromFirebase(userCredential.user);
        if (user != null) await _syncUserToDatabase(user);
        return user;
      }

      final LoginResult result = await FacebookAuth.instance.login();
      if (result.status == LoginStatus.success) {
        final credential = firebase_auth.FacebookAuthProvider.credential(
          result.accessToken!.tokenString,
        );
        final userCredential = await signInOrLinkCredential(credential);
        final user = _userFromFirebase(userCredential.user);
        if (user != null) await _syncUserToDatabase(user);
        return user;
      }
      if (result.status != LoginStatus.cancelled) {
        throw firebase_auth.FirebaseAuthException(
          code: 'facebook-login-failed',
        );
      }
      return null;
    } catch (e) {
      if (e is firebase_auth.FirebaseAuthException &&
          e.code == 'popup-closed-by-user')
        return null;
      debugPrint("Facebook Sign In failed: $e");
      rethrow;
    }
  }

  @override
  Future<AppUser?> signInWithApple() async {
    try {
      // FlutterFire owns the Apple nonce and token exchange. The old manual
      // credential path incorrectly treated an authorization code as an access
      // token, which cannot be relied on for Firebase sign-in.
      final provider = firebase_auth.AppleAuthProvider();
      final credential = kIsWeb
          ? await signInOrLinkPopup(provider)
          : await signInOrLinkProvider(provider);
      final user = _userFromFirebase(credential.user);
      if (user != null) await _syncUserToDatabase(user);
      return user;
    } catch (e) {
      if (e is firebase_auth.FirebaseAuthException &&
          (e.code == 'popup-closed-by-user' ||
              e.code == 'web-context-canceled' ||
              e.code == 'canceled')) {
        return null;
      }
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
  Future<void> updateProfile({
    String? displayName,
    String? username,
    String? avatarUrl,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw StateError('unauthenticated');
    final db = FirebaseFirestore.instance;
    final profileRef = db.collection('users').doc(user.uid);
    final requestedUsername = username?.trim();
    final claims = requestedUsername == null
        ? null
        : await user.getIdTokenResult();
    final canRenameWithoutTicket = claims?.claims?['admin'] == true;

    // The reservation and the profile either both commit, or neither does.
    // In particular, never report success after a permission-denied profile write.
    final savedFields = await db.runTransaction<Map<String, dynamic>>((
      transaction,
    ) async {
      final snapshot = await transaction.get(profileRef);
      final current = snapshot.data() ?? _userFromFirebase(user)!.toJson();
      final update = profileUpdate(
        current: current,
        displayName: displayName,
        username: requestedUsername,
        avatarUrl: avatarUrl,
        canRenameWithoutTicket: canRenameWithoutTicket,
      );
      final oldUsername = current['username'] as String?;
      DocumentReference<Map<String, dynamic>>? reservationRef;
      DocumentReference<Map<String, dynamic>>? oldReservationRef;
      bool deleteOld = false;
      if (requestedUsername != null) {
        reservationRef = db
            .collection('usernames')
            .doc(requestedUsername.toLowerCase());
        final reservation = await transaction.get(reservationRef);
        if (reservation.exists && reservation.data()?['uid'] != user.uid) {
          throw StateError('username_taken');
        }
        if (oldUsername != null &&
            oldUsername.isNotEmpty &&
            oldUsername.toLowerCase() != requestedUsername.toLowerCase()) {
          oldReservationRef = db
              .collection('usernames')
              .doc(oldUsername.toLowerCase());
          final oldReservation = await transaction.get(oldReservationRef);
          deleteOld = oldReservation.data()?['uid'] == user.uid;
        }
      }
      // All reads precede writes; Firestore may retry this callback.
      if (deleteOld) transaction.delete(oldReservationRef!);
      if (reservationRef != null)
        transaction.set(reservationRef, {'uid': user.uid});
      if (snapshot.exists) {
        transaction.update(profileRef, update);
      } else {
        transaction.set(profileRef, {...current, ...update});
      }
      return update;
    });

    // Firestore is the canonical profile. Legacy mirrors must not turn a
    // committed username into a false failure or overwrite unrelated fields.
    try {
      if (displayName != null) await user.updateDisplayName(displayName);
      if (avatarUrl != null) await user.updatePhotoURL(avatarUrl);
      await FirebaseDatabase.instance
          .ref('users')
          .child(user.uid)
          .update(savedFields);
    } catch (error) {
      debugPrint('Profile saved; legacy mirror update failed: $error');
    }
  }

  @override
  Future<bool> isUsernameAvailable(
    String username, {
    String? currentUid,
  }) async {
    final doc = await FirebaseFirestore.instance
        .collection('usernames')
        .doc(username.toLowerCase())
        .get();

    if (!doc.exists) return true;

    // Ownership Check: If it's taken, check if it's taken by ME
    final data = doc.data();
    if (data != null && currentUid != null && data['uid'] == currentUid) {
      return true; // It's mine, I can re-claim it
    }

    return false;
  }
}
