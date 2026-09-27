import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as game;
import 'package:halabessa/features/game/presentation/widgets/fanned_hand_widget.dart';

void main() {
  const cards = [
    game.Card(game.Suit.hearts, game.Rank.two),
    game.Card(game.Suit.clubs, game.Rank.five),
    game.Card(game.Suit.spades, game.Rank.eight),
    game.Card(game.Suit.diamonds, game.Rank.king),
  ];
  Widget hand(bool myTurn, void Function(game.Card, Offset) onTap, {
    List<game.Card> values = cards, double width = 390, bool enabled = true,
    TextDirection direction = TextDirection.ltr,
  }) => MaterialApp(home: Scaffold(body: Directionality(textDirection: direction,
    child: Align(alignment: Alignment.bottomCenter,
      child: SizedBox(width: width, child: FannedHandWidget(
        cards: values, isMyTurn: myTurn, onCardTap: onTap, interactionEnabled: enabled,
        cardBuilder: (_, width, height) => SizedBox(width: width, height: height),
      )),
    ),
  )));
  Finder card(int index) => find.byKey(ValueKey('hand-card-${cards[index].firebaseKey}'));

  testWidgets('simple and repeated taps play the tapped card only once', (tester) async {
    final played = <game.Card>[];
    await tester.pumpWidget(hand(true, (value, _) => played.add(value)));
    await tester.tap(card(1));
    await tester.pump();
    await tester.tap(card(1));
    expect(played, [cards[1]]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('horizontal swipes do not play, deliberate upward swipes do', (tester) async {
    final played = <game.Card>[];
    await tester.pumpWidget(hand(true, (value, _) => played.add(value)));
    await tester.drag(card(1), const Offset(50, 0));
    expect(played, isEmpty);
    await tester.drag(card(2), const Offset(0, -70));
    expect(played, [cards[2]]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('queued selection survives reordering by card identity', (tester) async {
    final played = <game.Card>[];
    void play(game.Card value, Offset _) => played.add(value);
    await tester.pumpWidget(hand(false, play));
    await tester.tap(card(2));
    await tester.pump();
    expect(played, isEmpty);
    await tester.pumpWidget(hand(true, play, values: cards.reversed.toList()));
    await tester.pump(const Duration(milliseconds: 350));
    expect(played, [cards[2]]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('removed queued card never becomes a different play', (tester) async {
    final played = <game.Card>[];
    void play(game.Card value, Offset _) => played.add(value);
    await tester.pumpWidget(hand(false, play));
    await tester.tap(card(1));
    await tester.pumpWidget(hand(true, play, values: [cards[0], cards[2], cards[3]]));
    await tester.pump(const Duration(milliseconds: 350));
    expect(played, isEmpty);
  });

  testWidgets('manual play cancels a pending automatic play', (tester) async {
    final played = <game.Card>[];
    void play(game.Card value, Offset _) => played.add(value);
    await tester.pumpWidget(hand(false, play));
    await tester.tap(card(1));
    await tester.pumpWidget(hand(true, play));
    await tester.tap(card(2));
    await tester.pump(const Duration(milliseconds: 350));
    expect(played, [cards[2]]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('phase-disabled hand cannot submit', (tester) async {
    final played = <game.Card>[];
    await tester.pumpWidget(hand(true, (value, _) => played.add(value), enabled: false));
    await tester.tap(card(0));
    await tester.drag(card(0), const Offset(0, -70));
    expect(played, isEmpty);
  });

  testWidgets('keyboard focus and Enter play a card', (tester) async {
    final played = <game.Card>[];
    await tester.pumpWidget(hand(true, (value, _) => played.add(value)));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(played, [cards[0]]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final width in [280.0, 320.0, 390.0, 800.0]) {
    for (final direction in TextDirection.values) {
      testWidgets('cards remain inside hand at $width / $direction', (tester) async {
        await tester.pumpWidget(hand(true, (_, __) {}, width: width, direction: direction));
        final bounds = tester.getRect(find.byType(FannedHandWidget));
        for (var index = 0; index < cards.length; index++) {
          final rect = tester.getRect(card(index));
          expect(rect.bottom, lessThanOrEqualTo(bounds.bottom));
          expect(rect.top, greaterThanOrEqualTo(bounds.top));
          expect(rect.left, greaterThanOrEqualTo(bounds.left));
          expect(rect.right, lessThanOrEqualTo(bounds.right));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('queued timer is cancelled on dispose', (tester) async {
    final played = <game.Card>[];
    void play(game.Card value, Offset _) => played.add(value);
    await tester.pumpWidget(hand(false, play));
    await tester.tap(card(1));
    await tester.pumpWidget(hand(true, play));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(played, isEmpty);
  });
}
