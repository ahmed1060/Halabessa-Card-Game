import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/presentation/widgets/match_table_layout.dart';
import 'package:halabessa/features/game/presentation/widgets/table_seat.dart';
import 'package:halabessa/features/game/presentation/widgets/match_phase_panel.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(390, 844),
    const Size(844, 390), const Size(1024, 768)]) {
    for (final scale in [1.0, 2.0]) {
      for (final direction in TextDirection.values) {
        testWidgets('table regions do not overlap: $size / $scale / $direction', (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          Widget seat(String name) => TableSeat(name: name, detail: '4 cards');
          await tester.pumpWidget(MaterialApp(home: MediaQuery(
            data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
            child: Directionality(textDirection: direction, child: Scaffold(body: MatchTableLayout(
              header: MatchScoreBar(firstLabel: 'Our team', secondLabel: 'Their team',
                firstScore: 12, secondScore: 8, details: 'Round 2 · First to 41',
                roomLabel: 'ABC123', onCopyRoom: () {}),
              partner: seat('Partner'), leftOpponent: seat('Left'), rightOpponent: seat('Right'),
              board: const SizedBox(key: ValueKey('board'), width: 140, height: 100),
              status: MatchPhasePanel(title: 'Cut the deck', message: 'Your turn to cut the deck',
                actionLabel: 'Cut', onAction: () async {}, failureMessage: 'Try again'),
              hand: const SizedBox(key: ValueKey('hand'), height: 140, width: 280),
              controls: IconButton(onPressed: () {}, tooltip: 'Settings', icon: const Icon(Icons.settings)),
            ))),
          )));
          await tester.pump();
          expect(tester.takeException(), isNull);
          final board = tester.getRect(find.byKey(const ValueKey('board')));
          final hand = tester.getRect(find.byKey(const ValueKey('hand')));
          final header = tester.getRect(find.byType(MatchScoreBar));
          expect(board.overlaps(hand), isFalse);
          expect(header.overlaps(hand), isFalse);
          for (final element in find.byType(TableSeat).evaluate()) {
            final seatRect = tester.getRect(find.byWidget(element.widget));
            expect(seatRect.overlaps(hand), isFalse);
            expect(seatRect.overlaps(header), isFalse);
          }
        });
      }
    }
  }
}
