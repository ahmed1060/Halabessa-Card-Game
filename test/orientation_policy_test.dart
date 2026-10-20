import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/core/providers/orientation_policy_provider.dart';
import 'package:halabessa/core/providers/settings_provider.dart';
import 'package:halabessa/core/widgets/orientation_settings_control.dart';

void main() {
  test('only verified primary admin claims own visibility policy', () {
    final owner = <String, dynamic>{
      'email': orientationOwnerEmail,
      'email_verified': true,
      'admin': true,
    };
    expect(ownsOrientationPolicy(owner), isTrue);
    expect(ownsOrientationPolicy({}), isFalse);
    expect(ownsOrientationPolicy({...owner, 'admin': false}), isFalse);
    expect(ownsOrientationPolicy({...owner, 'email_verified': false}), isFalse);
    expect(
      ownsOrientationPolicy({...owner, 'email': 'delegated@example.com'}),
      isFalse,
    );
    expect(ownsOrientationPolicy({...owner, 'admin': 'true'}), isFalse);
  });
  for (final owner in [false, true]) {
    test('policy writes verify owner before storage, owner=$owner', () async {
      final writes = <bool>[];
      final c = ProviderContainer(
        overrides: [
          orientationSuperAdminProvider.overrideWith((ref) async => owner),
          orientationPolicyStorageWriterProvider.overrideWithValue((
            value,
          ) async {
            writes.add(value);
          }),
        ],
      );
      addTearDown(c.dispose);
      final result = c.read(orientationPolicyWriterProvider)(false);
      if (owner) {
        await result;
        expect(writes, [false]);
      } else {
        await expectLater(result, throwsStateError);
        expect(writes, isEmpty);
      }
    });
    for (final visible in [false, true]) {
      testWidgets('orientation controls owner=$owner visible=$visible', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final writes = <bool>[];
        final c = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            orientationSuperAdminProvider.overrideWith((ref) async => owner),
            orientationControlVisibleProvider.overrideWith(
              (ref) => Stream.value(visible),
            ),
            orientationPolicyStorageWriterProvider.overrideWithValue((
              value,
            ) async {
              writes.add(value);
            }),
          ],
        );
        addTearDown(c.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: c,
            child: const MaterialApp(
              home: Scaffold(
                body: SizedBox(width: 320, child: OrientationSettingsControl()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(SegmentedButton<GameOrientation>),
          owner || visible ? findsOneWidget : findsNothing,
        );
        expect(find.byType(Checkbox), owner ? findsOneWidget : findsNothing);
        if (owner) {
          await tester.tap(find.byType(Checkbox));
          await tester.pumpAndSettle();
          expect(writes, [!visible]);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
