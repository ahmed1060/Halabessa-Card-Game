import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:halabessa/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-end game test', () {
    testWidgets('renders the sign-in screen', (tester) async {
      app.main();
      await tester.pump(const Duration(seconds: 3));

      final emailField = find.byKey(const ValueKey('login_email_field'));
      final passwordField = find.byKey(const ValueKey('login_password_field'));
      final loginBtn = find.byKey(const ValueKey('login_submit_btn'));

      expect(emailField, findsOneWidget);
      expect(passwordField, findsOneWidget);
      expect(loginBtn, findsOneWidget);
    });
  });
}
