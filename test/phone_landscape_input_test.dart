import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as cards;
import 'package:halabessa/features/game/presentation/widgets/fanned_hand_widget.dart';
import 'package:halabessa/features/game/presentation/widgets/match_table_layout.dart';
import 'package:halabessa/features/game/presentation/widgets/table_seat.dart';

void main() {
  for (final size in [const Size(844, 390), const Size(932, 430), const Size(740, 320)]) {
    for (final direction in TextDirection.values) {
      testWidgets('phone landscape fits and taps rendered card center $size $direction', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        const card = cards.Card(cards.Suit.hearts, cards.Rank.ace);
        var plays = 0;
        await tester.pumpWidget(MaterialApp(home: Directionality(textDirection: direction,
          child: Scaffold(body: MatchTableLayout(
            header: const MatchScoreBar(firstLabel: 'Our team', secondLabel: 'Rivals',
              firstScore: 2, secondScore: 1, details: 'Round 1', roomLabel: 'Practice', onCopyRoom: null),
            partner: const TableSeat(name: 'Partner', detail: '4 cards'),
            leftOpponent: const TableSeat(name: 'Before', detail: '4 cards'),
            rightOpponent: const TableSeat(name: 'After', detail: '4 cards'),
            board: const SizedBox(width: 230, height: 160),
            collections: const SizedBox(height: 150), status: const Text('Your turn'),
            hand: FannedHandWidget(cards: const [card], isMyTurn: true,
              cardBuilder: (_, width, height) => SizedBox(width: width, height: height,
                child: const ColoredBox(color: Colors.white)),
              onCardTap: (_, __) => plays++),
            controls: const SizedBox(height: 48),
          )))));
        expect(find.byType(SingleChildScrollView), findsNothing);
        final target = find.byKey(const ValueKey('hand-card-hearts_ace'));
        final rect = tester.getRect(target);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(size.height - 48));
        await tester.tapAt(rect.center);
        expect(plays, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
