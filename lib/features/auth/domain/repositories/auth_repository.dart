import '../models/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> get authStateChanges;
  AppUser? get currentUser;
  
  Future<AppUser?> signInWithEmail(String email, String password);
  Future<AppUser?> signUpWithEmail(String email, String password, String displayName);
  Future<AppUser?> signInWithGoogle();
  Future<AppUser?> signInWithFacebook();
  Future<AppUser?> signInWithApple();
  Future<AppUser?> signInAnonymously({String? displayName});
  
  Future<void> signOut();
  Future<void> resetPassword(String email);
  Future<void> sendEmailVerification();
  Future<void> updateEmail(String newEmail);
  Future<void> updatePassword(String newPassword);
  Future<void> updateProfile({String? displayName, String? avatarUrl});
}
