import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/presentation/widgets/turn_deadline_ring.dart';
import 'package:halabessa/features/game/presentation/widgets/table_seat.dart';

void main() {
  testWidgets(
    'liquid ring stays closed while thickness drains, then vanishes',
    (tester) async {
      for (final fraction in [1.0, .5, .2, 0.0]) {
        final painter = LiquidDeadlineRingPainter(
          true,
          fraction,
          Colors.amber,
          Colors.green,
        );
        expect(painter.thickness, 5 * fraction);
        await tester.runAsync(() async {
          final recorder = ui.PictureRecorder();
          painter.paint(Canvas(recorder), const Size(80, 80));
          final picture = recorder.endRecording();
          final image = await picture.toImage(80, 80);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          if (fraction == 0) {
            for (var i = 3; i < bytes.lengthInBytes; i += 4) {
              expect(bytes.getUint8(i), 0);
            }
          } else {
            final radius = 39 - painter.thickness / 2;
            for (var degrees = 0; degrees < 360; degrees++) {
              final angle = degrees * math.pi / 180;
              final x = (40 + radius * math.cos(angle)).floor();
              final y = (40 + radius * math.sin(angle)).floor();
              expect(
                bytes.getUint8((y * 80 + x) * 4 + 3),
                greaterThan(20),
                reason: 'No cut at $degrees degrees, remaining=$fraction',
              );
            }
          }
          image.dispose();
          picture.dispose();
        });
      }
    },
  );

  for (final reduced in [false, true]) {
    testWidgets('liquid clock retains real deadline, reduced motion=$reduced', (
      tester,
    ) async {
      final start = DateTime.utc(2026, 10, 20);
      final clock = ValueNotifier(start);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: SizedBox(
              width: 80,
              height: 80,
              child: TurnDeadlineRing(
                liquid: true,
                active: true,
                started: start,
                duration: const Duration(seconds: 10),
                now: () => clock.value,
                clockChanges: clock,
                foreground: Colors.amber,
                background: Colors.green,
              ),
            ),
          ),
        ),
      );
      LiquidDeadlineRingPainter painter() =>
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('liquid-deadline-ring')),
                  )
                  .painter!
              as LiquidDeadlineRingPainter;
      expect(painter().thickness, 5);
      clock.value = start.add(const Duration(seconds: 5));
      await tester.pump();
      expect(painter().remaining, .5);
      expect(painter().thickness, 2.5);
      clock.value = start.add(const Duration(seconds: 11));
      await tester.pump();
      expect(painter().thickness, 0);
      // A calibrated clock correction may restore the visual remainder,
      // but must not create a fresh ten-second countdown.
      clock.value = start.add(const Duration(seconds: 8));
      await tester.pump();
      expect(painter().remaining, closeTo(.2, .001));
      await tester.pumpWidget(const SizedBox());
      clock.dispose();
      expect(tester.takeException(), isNull);
    });
  }
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
