import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as game_card;
import 'package:halabessa/features/game/presentation/widgets/board_cards_widget.dart';

void main() {
  const first = game_card.Card(game_card.Suit.hearts, game_card.Rank.two);
  const second = game_card.Card(game_card.Suit.clubs, game_card.Rank.king);
  const firstKey = ValueKey('card-hearts_two');
  const secondKey = ValueKey('card-clubs_king');

  Widget scene(List<game_card.Card> cards, {bool capture = false,
      int stage = 0, bool reduceMotion = false}) => MaterialApp(home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(body: Center(child: SizedBox(width: 230, height: 200,
      child: BoardCardsWidget(
        cards: cards, isCapturing: capture, capturingStage: stage,
        captureToBottom: true,
        arrivalOffsets: const {
          'hearts_two': Offset(0, 100),
          'clubs_king': Offset(100, 0),
        },
        cardBuilder: (card, width, height) => SizedBox(
          key: ValueKey('card-${card.firebaseKey}'),
          width: width, height: height,
        ),
      ),
    ))),
  ));

  testWidgets('a new play moves in without replaying settled cards', (tester) async {
    await tester.pumpWidget(scene(const [first]));
    await tester.pumpAndSettle();
    await tester.pumpWidget(scene(const [first, second]));
    final firstAtStart = tester.getTopLeft(find.byKey(firstKey));
    final secondAtStart = tester.getTopLeft(find.byKey(secondKey));
    await tester.pumpAndSettle();
    final firstAtEnd = tester.getTopLeft(find.byKey(firstKey));
    final secondAtEnd = tester.getTopLeft(find.byKey(secondKey));
    expect(firstAtStart, firstAtEnd);
    expect(secondAtStart.dx - secondAtEnd.dx, closeTo(100, 1));
    expect(secondAtStart.dy, closeTo(secondAtEnd.dy, 1));
  });

  testWidgets('capture has a distinct merge and teamward flight', (tester) async {
    await tester.pumpWidget(scene(const [first, second], capture: true));
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 0.84);
    await tester.pumpAndSettle();
    await tester.pumpWidget(scene(const [first, second], capture: true, stage: 1));
    expect(tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
        const Offset(0, 1.3));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0.12);
  });
}
