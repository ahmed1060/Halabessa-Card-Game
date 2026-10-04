import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:halabessa/features/auth/data/repositories/firebase_auth_repository.dart';

class TestCredential extends Fake implements UserCredential {}
class TestUser extends Fake implements User {
  @override final bool isAnonymous;
  TestUser(this.isAnonymous);
  int linked = 0;
  bool conflict = false;
  final result = TestCredential();
  @override Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    linked++;
    if (conflict) throw FirebaseAuthException(code: 'credential-already-in-use');
    return result;
  }
  @override Future<UserCredential> linkWithPopup(AuthProvider provider) async {
    linked++; return result;
  }
}
class TestAuth extends Fake implements FirebaseAuth {
  @override final User? currentUser;
  TestAuth(this.currentUser);
  int signedIn = 0;
  final result = TestCredential();
  @override Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    signedIn++; return result;
  }
  @override Future<UserCredential> signInWithPopup(AuthProvider provider) async {
    signedIn++; return result;
  }
}
void main() {
  test('guest upgrades link both credential and popup without account replacement', () async {
    final guest = TestUser(true); final auth = TestAuth(guest);
    final repo = FirebaseAuthRepository(auth);
    expect(await repo.signInOrLinkCredential(GoogleAuthProvider.credential(idToken: 'test')), same(guest.result));
    expect(await repo.signInOrLinkPopup(FacebookAuthProvider()), same(guest.result));
    expect(guest.linked, 2); expect(auth.signedIn, 0);
  });
  test('credential conflict does not silently sign out or replace guest progress', () async {
    final guest = TestUser(true)..conflict = true;
    final auth = TestAuth(guest); final repo = FirebaseAuthRepository(auth);
    await expectLater(repo.signInOrLinkCredential(GoogleAuthProvider.credential(idToken: 'test')),
      throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', 'credential-already-in-use')));
    expect(auth.signedIn, 0); expect(auth.currentUser, same(guest));
  });
  test('non-guests and signed-out users use sign-in rather than linking', () async {
    for (final user in [null, TestUser(false)]) {
      final auth = TestAuth(user); final repo = FirebaseAuthRepository(auth);
      await repo.signInOrLinkCredential(GoogleAuthProvider.credential(idToken: 'test'));
      await repo.signInOrLinkPopup(FacebookAuthProvider());
      expect(auth.signedIn, 2);
    }
  });
  test('native Google client IDs agree with committed provider configuration', () {
    final config = jsonDecode(File('android/app/google-services.json').readAsStringSync()) as Map;
    final clients = config['client'][0]['oauth_client'] as List;
    expect(clients.any((c) => c['client_type'] == 3 && c['client_id'] == FirebaseAuthRepository.googleWebClientId), isTrue);
    final plist = File('ios/Runner/GoogleService-Info.plist').readAsStringSync();
    final callback = RegExp(r'<key>REVERSED_CLIENT_ID</key>\s*<string>([^<]+)</string>').firstMatch(plist)!.group(1)!;
    expect(File('ios/Runner/Info.plist').readAsStringSync(), contains('<string>$callback</string>'));
    expect(plist, contains(FirebaseAuthRepository.googleIosClientId));
  });
}
