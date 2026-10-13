import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/presentation/widgets/lantern_controls.dart';
import 'package:halabessa/features/game/presentation/widgets/table_seat.dart';

void main() {
  testWidgets(
    'expired server deadline hides the clock and confirmation message',
    (tester) async {
      final start = DateTime.utc(2026, 10, 12);
      await tester.pumpWidget(
        MaterialApp(
          home: TurnCountdown(
            started: start,
            seconds: 0,
            duration: const Duration(milliseconds: 450),
            now: () => start.add(const Duration(milliseconds: 451)),
            hideWhenExpired: true,
          ),
        ),
      );
      expect(find.text('Confirming…'), findsNothing);
      expect(find.byIcon(Icons.timer_outlined), findsNothing);
      expect(find.text('0s'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('forced last-card countdown works in a timer-free room', (
    tester,
  ) async {
    final started = DateTime.utc(2026, 10, 12);
    var now = started;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TurnCountdown(
            started: started,
            seconds: 0,
            duration: const Duration(milliseconds: 600),
            now: () => now,
          ),
        ),
      ),
    );
    expect(find.text('1s'), findsOneWidget);
    now = started.add(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('0s'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
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
