import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/providers/age_eligibility_provider.dart';

DateTime birthDateOnly(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

bool validProfileBirthDate(DateTime date, DateTime today) =>
    date.year >= 1900 && isAtLeast13(birthDateOnly(date), today);

DateTime? parseProfileBirthDate(Object? value) {
  if (value == null) return null;
  if (value is! Timestamp) throw StateError('invalid_birth_date');
  return birthDateOnly(value.toDate().toUtc());
}

abstract class BirthDateStore {
  Stream<DateTime?> watch(String uid);
  Future<void> save(String uid, DateTime date);
}

/// Private account field only. Never publishes to discovery or the RTDB mirror.
class FirestoreBirthDateStore implements BirthDateStore {
  FirestoreBirthDateStore(this.firestore);
  final FirebaseFirestore firestore;

  @override
  Stream<DateTime?> watch(String uid) => firestore
      .collection('users')
      .doc(uid)
      .snapshots(includeMetadataChanges: true)
      // An optimistic local write must not unlock onboarding before the
      // server acknowledges it. Metadata changes deliver that acknowledgement.
      .where((snapshot) => !snapshot.metadata.hasPendingWrites)
      .map((snapshot) {
        return parseProfileBirthDate(snapshot.data()?['dateOfBirth']);
      });

  @override
  Future<void> save(String uid, DateTime date) async {
    final value = birthDateOnly(date);
    if (!validProfileBirthDate(value, DateTime.now().toUtc())) {
      throw StateError('invalid_birth_date');
    }
    // Updating one field cannot reset stats, usernames or server-owned fields.
    // A missing profile must finish its normal bootstrap, rather than be replaced.
    await firestore.collection('users').doc(uid).update({
      'dateOfBirth': Timestamp.fromDate(value),
    });
  }
}
