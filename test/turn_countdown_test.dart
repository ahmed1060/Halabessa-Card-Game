import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/presentation/widgets/lantern_controls.dart';
import 'package:halabessa/features/game/presentation/widgets/table_seat.dart';

void main() {
  testWidgets('localized clock labels preserve the server deadline', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LanternTurnBadge(
            active: true,
            title: 'دورك',
            hint: '',
            turnStarted: DateTime.now().subtract(const Duration(seconds: 20)),
            turnSeconds: 15,
            countdownLabel: (s) => '$sث',
            countdownSemantics: (s) => 'متبقي $s ثانية',
          ),
        ),
      ),
    );
    expect(find.text('0ث'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets('server emote expires without a sender cleanup command', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TableSeat(
            name: 'QA',
            detail: '4 cards',
            message: '👑',
            messageExpiresAt: DateTime.now().add(const Duration(seconds: 3)),
          ),
        ),
      ),
    );
    expect(find.text('👑'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('👑'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
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
