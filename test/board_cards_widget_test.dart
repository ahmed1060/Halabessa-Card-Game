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

  testWidgets('a new play arrives while settled cards glide into the new fan', (tester) async {
    await tester.pumpWidget(scene(const [first]));
    await tester.pumpAndSettle();
    final firstBefore = tester.getRect(find.byKey(firstKey)).center;
    await tester.pumpWidget(scene(const [first, second]));
    final firstAtStart = tester.getRect(find.byKey(firstKey)).center;
    final secondAtStart = tester.getRect(find.byKey(secondKey)).center;
    expect(firstAtStart.dx, closeTo(firstBefore.dx, 1));
    await tester.pump(const Duration(milliseconds: 120));
    final firstMidway = tester.getRect(find.byKey(firstKey)).center;
    await tester.pumpAndSettle();
    final firstAtEnd = tester.getRect(find.byKey(firstKey)).center;
    final secondAtEnd = tester.getRect(find.byKey(secondKey)).center;
    expect(firstMidway.dx, lessThan(firstAtStart.dx));
    expect(firstMidway.dx, greaterThan(firstAtEnd.dx));
    expect((firstAtStart - firstAtEnd).distance, closeTo(64 * 0.225, 1));
    expect((secondAtStart - secondAtEnd).distance, closeTo(100, 1));
    expect(secondAtStart.dx, greaterThan(secondAtEnd.dx));
  });

  testWidgets('reduced motion settles the fan immediately', (tester) async {
    await tester.pumpWidget(scene(const [first], reduceMotion: true));
    await tester.pumpWidget(scene(const [first, second], reduceMotion: true));
    final firstAtStart = tester.getRect(find.byKey(firstKey)).center;
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.getRect(find.byKey(firstKey)).center, firstAtStart);
    expect(tester.widget<AnimatedSlide>(
      find.byKey(const ValueKey('board-position-hearts_two'))).duration,
      Duration.zero);
  });

  testWidgets('capture has a distinct merge and teamward flight', (tester) async {
    await tester.pumpWidget(scene(const [first, second], capture: true));
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 0.84);
    await tester.pumpAndSettle();
    await tester.pumpWidget(scene(const [first, second], capture: true, stage: 1));
    expect(tester.widget<AnimatedSlide>(
      find.byKey(const ValueKey('capture-flight'))).offset,
        const Offset(0, 1.3));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0.12);
  });
}
