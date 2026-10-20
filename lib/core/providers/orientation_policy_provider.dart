import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import 'native_play_provider.dart';

// Matches the existing primary-admin identity and the server-side policy rule.
const orientationOwnerEmail = 'ahmed.hossam1060@gmail.com';

bool ownsOrientationPolicy(Map<String, dynamic> claims) =>
    claims['admin'] == true &&
    claims['email_verified'] == true &&
    claims['email'] == orientationOwnerEmail;

final orientationSuperAdminProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  if (ref.watch(offlineSessionProvider) ||
      ref.watch(sessionUidProvider) == null) {
    return false;
  }
  final user = ref.read(firebaseAuthProvider).currentUser;
  if (user == null) return false;
  final token = await user.getIdTokenResult();
  return ownsOrientationPolicy(token.claims ?? const {});
});

final orientationControlVisibleProvider = StreamProvider.autoDispose<bool>((
  ref,
) {
  if (ref.watch(offlineSessionProvider) ||
      ref.watch(sessionUidProvider) == null) {
    return Stream.value(true);
  }
  return FirebaseFirestore.instance
      .collection('settings')
      .doc('orientation')
      .snapshots()
      .map((snapshot) => snapshot.data()?['showPlayerControl'] != false);
});

// Kept separate so permission tests can assert that unauthorized writes never
// reach storage. Firestore rules independently enforce the same restriction.
final orientationPolicyStorageWriterProvider =
    Provider<Future<void> Function(bool)>(
      (ref) =>
          (visible) => FirebaseFirestore.instance
              .collection('settings')
              .doc('orientation')
              .set({'showPlayerControl': visible}),
    );

final orientationPolicyWriterProvider = Provider<Future<void> Function(bool)>(
  (ref) => (visible) async {
    if (!await ref.read(orientationSuperAdminProvider.future)) {
      throw StateError('superadmin_required');
    }
    await ref.read(orientationPolicyStorageWriterProvider)(visible);
  },
);
