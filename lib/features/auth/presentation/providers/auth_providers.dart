import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/firebase_auth_repository.dart';

// 1. Provides the FirebaseAuth instance
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

// 2. Provides the AuthRepository implementation
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository(ref.watch(firebaseAuthProvider));
});

// 3. Streams the User Authentication State
final authStateChangesProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// 4. Provides the current logged in user directly if available
final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authStateChangesProvider).value;
});
