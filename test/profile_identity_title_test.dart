import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/auth/presentation/widgets/profile_identity_title.dart';

void main() {
  for (final direction in TextDirection.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('long identity fits $direction at $scale', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Directionality(
                textDirection: direction,
                child: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: const SizedBox(
                    width: 280,
                    child: ProfileIdentityTitle(
                      name: 'CodexServerUIQA_20261004 اسم لاعب طويل جدا',
                      badge: 'Admin',
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Admin'), findsOneWidget);
      });
    }
  }
}
