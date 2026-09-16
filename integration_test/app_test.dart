import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:halabessa/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-end game test', () {
    testWidgets('login and verify main menu loads', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Wait for login screen and find elements
      final emailField = find.byKey(const ValueKey('login_email_field'));
      final passwordField = find.byKey(const ValueKey('login_password_field'));
      final loginBtn = find.byKey(const ValueKey('login_submit_btn'));

      // If the email field doesn't exist, we might already be logged in (cached session),
      // or we are still loading. Let's wait a bit and check.
      bool isLoginPage = false;
      try {
        expect(emailField, findsOneWidget);
        isLoginPage = true;
      } catch (_) {
        // Not on login page, might be in the lobby
      }

      if (isLoginPage) {
        // Enter credentials
        await tester.enterText(emailField, 'test@example.com');
        await tester.pumpAndSettle();
        
        await tester.enterText(passwordField, 'password123');
        await tester.pumpAndSettle();

        // Tap Login
        await tester.tap(loginBtn);
        await tester.pumpAndSettle();
      }

      // Verify we are not on the login screen anymore (e.g., in Lobby)
      // We expect the 'Play Now' button or some lobby element to be present.
      // Wait for loading to finish.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      final playNowBtn = find.byKey(const ValueKey('play_now_btn'));
      expect(playNowBtn, findsOneWidget, reason: 'Failed to reach the main menu/lobby after login.');
    });
  });
}
