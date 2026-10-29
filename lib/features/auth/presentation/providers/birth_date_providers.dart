import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/native_play_provider.dart';
import '../../data/repositories/birth_date_store.dart';
import 'auth_providers.dart';

final birthDateStoreProvider = Provider<BirthDateStore>(
  (ref) => FirestoreBirthDateStore(FirebaseFirestore.instance),
);

final profileBirthDateProvider = StreamProvider.autoDispose<DateTime?>((ref) {
  if (ref.watch(offlineSessionProvider)) return Stream.value(null);
  final uid = ref.watch(sessionUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(birthDateStoreProvider).watch(uid);
});

final saveProfileBirthDateProvider = Provider<Future<void> Function(DateTime)>(
  (ref) => (date) async {
    final uid = ref.read(sessionUidProvider);
    if (ref.read(offlineSessionProvider) || uid == null) {
      throw StateError('unauthenticated');
    }
    await ref.read(birthDateStoreProvider).save(uid, date);
    if (ref.read(sessionUidProvider) != uid) {
      throw StateError('unauthenticated');
    }
  },
);
