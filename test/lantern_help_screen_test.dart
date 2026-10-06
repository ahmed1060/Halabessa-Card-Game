import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/core/widgets/lantern_help_screen.dart';

void main() {
  testWidgets(
    'help example is interactive and team guide has no capture action',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: LanternHelpScreen()));
      final action = find.byKey(const ValueKey('help-capture-example'));
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('example-collected')), findsOneWidget);
      final teamTab = find.text('ui_team_play');
      await tester.ensureVisible(teamTab);
      await tester.pumpAndSettle();
      await tester.tap(teamTab);
      await tester.pumpAndSettle();
      expect(
        DefaultTabController.of(tester.element(find.byType(TabBar))).index,
        2,
      );
      expect(action.hitTestable(), findsNothing);
      expect(find.text('help_team'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
