import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/presentation/widgets/turn_deadline_ring.dart';
import 'package:halabessa/features/game/presentation/widgets/table_seat.dart';

void main() {
  testWidgets(
    'clock recalibration restarts an expired ring without extending its deadline',
    (tester) async {
      final start = DateTime.utc(2026, 10, 12);
      final clock = ValueNotifier(start.add(const Duration(seconds: 1)));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TurnDeadlineRing(
              active: true,
              started: start,
              duration: const Duration(milliseconds: 450),
              foreground: Colors.yellow,
              background: Colors.green,
              now: () => clock.value,
              clockChanges: clock,
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        0,
      );
      clock.value = start.add(const Duration(milliseconds: 225));
      await tester.pump();
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        .5,
      );
      clock.value = start.add(const Duration(milliseconds: 600));
      await tester.pump();
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        0,
      );
      await tester.pumpWidget(const SizedBox());
      clock.dispose();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'bot ring decreases within a second, clamps at zero, no reset on rebuild',
    (tester) async {
      final started = DateTime.utc(2026, 10, 12);
      var now = started;
      DateTime clock() => now;
      Widget ring() => MaterialApp(
        home: Scaffold(
          body: TurnDeadlineRing(
            active: true,
            started: started,
            duration: const Duration(milliseconds: 450),
            foreground: Colors.yellow,
            background: Colors.green,
            now: clock,
          ),
        ),
      );
      double value() => tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value!;
      await tester.pumpWidget(ring());
      expect(value(), 1);
      now = started.add(const Duration(milliseconds: 225));
      await tester.pump(const Duration(milliseconds: 225));
      expect(value(), closeTo(.5, .01));
      await tester.pumpWidget(ring());
      expect(value(), closeTo(.5, .01));
      now = started.add(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 675));
      expect(value(), 0);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'bot duration works when human timer is disabled; leaving turn clears ring',
    (tester) async {
      Widget seat(bool active) => MaterialApp(
        home: Scaffold(
          body: TableSeat(
            name: 'Bot',
            detail: 'Playing',
            isBot: true,
            active: active,
            turnSeconds: 0,
            turnStarted: DateTime.now().subtract(const Duration(seconds: 1)),
            turnDuration: const Duration(milliseconds: 450),
          ),
        ),
      );
      await tester.pumpWidget(seat(true));
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        0,
      );
      await tester.pumpWidget(seat(false));
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        0,
      );
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'reduced motion updates deadline without a continuous animation',
    (tester) async {
      final started = DateTime.utc(2026, 10, 12);
      var now = started;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: TurnDeadlineRing(
                active: true,
                started: started,
                duration: const Duration(milliseconds: 600),
                foreground: Colors.yellow,
                background: Colors.green,
                now: () => now,
              ),
            ),
          ),
        ),
      );
      now = started.add(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        closeTo(.5, .01),
      );
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
