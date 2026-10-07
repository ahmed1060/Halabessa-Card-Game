import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/core/providers/age_eligibility_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halabessa/core/providers/settings_provider.dart';
import 'package:halabessa/core/widgets/age_eligibility_screen.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    for (final direction in TextDirection.values) {
      testWidgets(
        'blocked gate has no sign-in or resubmission controls $size $direction',
        (tester) async {
          SharedPreferences.setMockInitialValues({
            AgeEligibilityNotifier.key: 'blocked',
          });
          final preferences = await SharedPreferences.getInstance();
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(preferences),
              ],
              child: MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: const TextScaler.linear(2),
                  ),
                  child: Directionality(
                    textDirection: direction,
                    child: const AgeEligibilityScreen(),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(FilledButton), findsNothing);
          expect(find.byType(OutlinedButton), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  test(
    'concurrent submissions cannot overwrite the first age decision',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final notifier = AgeEligibilityNotifier(preferences);
      await Future.wait([
        notifier.submit(DateTime(2014), today: DateTime(2026, 10, 7)),
        notifier.submit(DateTime(2000), today: DateTime(2026, 10, 7)),
      ]);
      expect(notifier.state, AgeEligibility.blocked);
      expect(preferences.getString(AgeEligibilityNotifier.key), 'blocked');
      notifier.dispose();
    },
  );
  test('age boundary is 13 inclusive, not just the birth year', () {
    final today = DateTime(2026, 10, 7);
    expect(isAtLeast13(DateTime(2013, 10, 7), today), isTrue);
    expect(isAtLeast13(DateTime(2013, 10, 8), today), isFalse);
    expect(isAtLeast13(DateTime(2014), today), isFalse);
    expect(isAtLeast13(DateTime(2027), today), isFalse);
    expect(isAtLeast13(DateTime(2012, 2, 29), DateTime(2025, 2, 28)), isFalse);
    expect(isAtLeast13(DateTime(2012, 2, 29), DateTime(2025, 3, 1)), isTrue);
  });
  test(
    'only eligibility persists; a blocked result cannot be changed by resubmission',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final notifier = AgeEligibilityNotifier(preferences);
      await notifier.submit(DateTime(2014), today: DateTime(2026, 10, 7));
      expect(notifier.state, AgeEligibility.blocked);
      await notifier.submit(DateTime(2000));
      expect(notifier.state, AgeEligibility.blocked);
      expect(preferences.getKeys(), {AgeEligibilityNotifier.key});
      expect(preferences.getString(AgeEligibilityNotifier.key), 'blocked');
      expect(AgeEligibilityNotifier(preferences).state, AgeEligibility.blocked);
      notifier.dispose();
    },
  );
}
