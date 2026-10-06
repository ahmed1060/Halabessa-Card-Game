import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/core/widgets/lantern_navigation_dock.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('dock stays below content and navigates once: $direction', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/profile': (_) =>
                const Scaffold(body: Text('Profile destination')),
          },
          home: Directionality(
            textDirection: direction,
            child: Scaffold(
              body: const Center(child: Text('Visible page')),
              bottomNavigationBar: const LanternNavigationDock(
                selected: LanternDestination.home,
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(LanternNavigationDock)).height,
        lessThan(100),
      );
      expect(
        tester.getRect(find.text('Visible page')).bottom,
        lessThan(tester.getRect(find.byType(LanternNavigationDock)).top),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('dock-profile'))).height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.byKey(const ValueKey('dock-profile')));
      await tester.pumpAndSettle();
      expect(find.text('Profile destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
