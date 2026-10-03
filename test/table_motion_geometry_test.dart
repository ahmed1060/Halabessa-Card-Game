import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/presentation/widgets/match_table_layout.dart';
import 'package:halabessa/features/game/presentation/widgets/table_motion_geometry.dart';

void main() {
  for (final direction in TextDirection.values) {
    for (final scale in [1.0, 2.0]) {
      for (final size in [const Size(390, 844), const Size(1191, 668)]) {
        testWidgets(
          'physical seat origins remain correct: $direction $scale $size',
          (tester) async {
            await tester.binding.setSurfaceSize(size);
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final previous = GlobalKey();
            final next = GlobalKey();
            final partner = GlobalKey();
            final board = GlobalKey();
            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Directionality(
                    textDirection: direction,
                    child: Scaffold(
                      body: MatchTableLayout(
                        header: const SizedBox(height: 80),
                        partner: SizedBox(key: partner, width: 60, height: 60),
                        leftOpponent: SizedBox(key: previous, height: 80),
                        rightOpponent: SizedBox(key: next, height: 80),
                        board: SizedBox(key: board),
                        collections: const SizedBox(height: 100),
                        status: const SizedBox(height: 20),
                        hand: const SizedBox(height: 100),
                        controls: const SizedBox(height: 48),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            expect(
              tableMotionOffset(previous, board)!.dx,
              lessThan(0),
              reason: 'Relative seat 3 stays physically left, even in RTL',
            );
            expect(
              tableMotionOffset(next, board)!.dx,
              greaterThan(0),
              reason: 'Relative seat 1 stays physically right, even in RTL',
            );
            expect(tableMotionOffset(partner, board)!.dy, lessThan(0));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
  testWidgets('unmounted source has no invented position', (tester) async {
    expect(tableMotionOffset(GlobalKey(), GlobalKey()), isNull);
  });
}
