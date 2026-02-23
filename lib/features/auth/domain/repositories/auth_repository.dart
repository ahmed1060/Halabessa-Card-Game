import '../models/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> get authStateChanges;
  AppUser? get currentUser;
  
  Future<AppUser?> signInWithEmail(String email, String password);
  Future<AppUser?> signUpWithEmail(String email, String password, String displayName);
  Future<AppUser?> signInWithGoogle();
  Future<AppUser?> signInWithFacebook();
  Future<AppUser?> signInWithApple();
  
  Future<void> signOut();
  Future<void> resetPassword(String email);
}
