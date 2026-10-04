import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/presentation/widgets/lantern_controls.dart';

void main() {
  testWidgets('local turn shows remaining deadline and clamps expired turns', (
    tester,
  ) async {
    final started = DateTime.now().subtract(const Duration(seconds: 5));
    Widget badge(DateTime time) => MaterialApp(
      home: Scaffold(
        body: LanternTurnBadge(
          active: true,
          title: 'Your turn',
          hint: '',
          turnStarted: time,
          turnSeconds: 15,
        ),
      ),
    );
    await tester.pumpWidget(badge(started));
    expect(find.text('10s'), findsOneWidget);
    await tester.pumpWidget(
      badge(DateTime.now().subtract(const Duration(seconds: 20))),
    );
    expect(find.text('0s'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
