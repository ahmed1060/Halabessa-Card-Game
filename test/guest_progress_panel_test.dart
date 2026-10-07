import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:halabessa/features/auth/presentation/widgets/guest_progress_panel.dart';

void main() {
  testWidgets(
    'Apple action is available only when supplied and observes pending guard',
    (tester) async {
      final pending = Completer<bool>();
      var apple = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuestProgressPanel(
              onGoogle: () => pending.future,
              onFacebook: () async => false,
              onApple: () async {
                apple++;
                return false;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('guest-link-Google')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('guest-link-Apple')));
      expect(apple, 0);
      pending.complete(false);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('guest-link-Apple')));
      await tester.pumpAndSettle();
      expect(apple, 1);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuestProgressPanel(
              onGoogle: () async => false,
              onFacebook: () async => false,
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('guest-link-Apple')), findsNothing);
    },
  );
  testWidgets('guest linking cannot submit a second provider while pending', (
    tester,
  ) async {
    final pending = Completer<bool>();
    var google = 0, facebook = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GuestProgressPanel(
            onGoogle: () {
              google++;
              return pending.future;
            },
            onFacebook: () async {
              facebook++;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('guest-link-Google')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('guest-link-Facebook')));
    expect(google, 1);
    expect(facebook, 0);
    pending.complete(false);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('guest-link-Google')))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('used credentials remain an error with retry, never success', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GuestProgressPanel(
            onGoogle: () async =>
                throw FirebaseAuthException(code: 'credential-already-in-use'),
            onFacebook: () async => false,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('guest-link-Google')));
    await tester.pumpAndSettle();
    expect(find.text('auth_guest_credential_used'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('guest-link-Google')))
          .onPressed,
      isNotNull,
    );
  });
}
