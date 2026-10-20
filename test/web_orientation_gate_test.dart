import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/core/providers/settings_provider.dart';
import 'package:halabessa/core/widgets/web_orientation_gate.dart';

void main() {
  test(
    'mismatch detection supports both choices and empty startup dimensions',
    () {
      expect(
        orientationMismatch(GameOrientation.landscape, const Size(430, 932)),
        isTrue,
      );
      expect(
        orientationMismatch(GameOrientation.landscape, const Size(932, 430)),
        isFalse,
      );
      expect(
        orientationMismatch(GameOrientation.portrait, const Size(430, 932)),
        isFalse,
      );
      expect(
        orientationMismatch(GameOrientation.portrait, const Size(932, 430)),
        isTrue,
      );
      expect(
        orientationMismatch(GameOrientation.landscape, Size.zero),
        isFalse,
      );
    },
  );
  testWidgets(
    'wrong orientation blocks clicks and escape, rotation restores same app',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          mobileWebOrientationGateProvider.overrideWithValue(true),
        ],
      );
      addTearDown(c.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 932);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var clicks = 0;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            builder: (context, child) => WebOrientationGate(child: child!),
            home: Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => clicks++,
                  child: const Text('Behind gate'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('web-orientation-blocker')),
        findsOneWidget,
      );
      expect(
        DefaultTextStyle.of(
          tester.element(find.text('rotate_landscape_title')),
        ).style.decoration,
        isNot(TextDecoration.underline),
      );
      expect(
        tester
            .widget<ModalBarrier>(
              find.byKey(const ValueKey('web-orientation-barrier')),
            )
            .dismissible,
        isFalse,
      );
      await tester.tapAt(tester.getCenter(find.text('Behind gate')));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(clicks, 0);
      expect(
        find.byKey(const ValueKey('web-orientation-blocker')),
        findsOneWidget,
      );
      tester.view.physicalSize = const Size(932, 430);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('web-orientation-blocker')),
        findsNothing,
      );
      await tester.tap(find.text('Behind gate'));
      expect(clicks, 1);
      await c
          .read(settingsProvider.notifier)
          .setGameOrientation(GameOrientation.portrait);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('web-orientation-blocker')),
        findsOneWidget,
      );
      tester.view.physicalSize = const Size(430, 932);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('web-orientation-blocker')),
        findsNothing,
      );
      expect(clicks, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'desktop/native bypass and keyboard insets do not fake rotation',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          mobileWebOrientationGateProvider.overrideWithValue(false),
        ],
      );
      addTearDown(c.dispose);
      Widget app(
        ProviderContainer container, {
        Size size = const Size(430, 932),
      }) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              viewInsets: const EdgeInsets.only(bottom: 300),
            ),
            child: const WebOrientationGate(child: Text('Content')),
          ),
        ),
      );
      await tester.pumpWidget(app(c));
      expect(
        find.byKey(const ValueKey('web-orientation-blocker')),
        findsNothing,
      );
      c.updateOverrides([
        sharedPreferencesProvider.overrideWithValue(prefs),
        mobileWebOrientationGateProvider.overrideWithValue(true),
      ]);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('web-orientation-blocker')),
        findsOneWidget,
        reason: 'keyboard must not make a portrait phone look landscape',
      );
      await tester.pumpWidget(app(c, size: const Size(932, 430)));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('web-orientation-blocker')),
        findsNothing,
        reason: 'keyboard insets must not block a landscape phone',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
