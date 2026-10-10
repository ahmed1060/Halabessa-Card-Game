import 'dart:async';
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
  Widget hand(bool myTurn, FutureOr<void> Function(game.Card, Offset) onTap, {
    List<game.Card> values = cards, double width = 390, bool enabled = true,
    TextDirection direction = TextDirection.ltr,
  }) => MaterialApp(home: Scaffold(body: Directionality(textDirection: direction,
    child: Align(alignment: Alignment.bottomCenter,
      child: SizedBox(width: width, child: FannedHandWidget(
        cards: values, isMyTurn: myTurn, onCardTap: onTap, interactionEnabled: enabled,
        cardBuilder: (card, width, height) => SizedBox(
          key: ValueKey('visual-${card.firebaseKey}'),
          width: width, height: height),
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

  testWidgets('pending feedback and tap guard last for the actual request', (tester) async {
    final request = Completer<void>();
    final played = <game.Card>[];
    await tester.pumpWidget(hand(true, (value, _) {
      played.add(value);
      return request.future;
    }));
    await tester.tap(card(1));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(ValueKey('hand-pending-${cards[1].firebaseKey}')), findsOneWidget);
    await tester.tap(card(2));
    await tester.drag(card(3), const Offset(0, -70));
    expect(played, [cards[1]]);
    request.complete();
    await tester.pump();
    expect(find.byKey(ValueKey('hand-pending-${cards[1].firebaseKey}')), findsNothing);
    await tester.tap(card(2));
    expect(played, [cards[1], cards[2]]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('completing a move after leaving the screen is safe', (tester) async {
    final request = Completer<void>();
    await tester.pumpWidget(hand(true, (_, __) => request.future));
    await tester.tap(card(0));
    await tester.pumpWidget(const SizedBox.shrink());
    request.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejected request clears pending feedback and allows retry', (tester) async {
    final request = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(hand(true, (_, __) {
      calls++;
      return calls == 1 ? request.future : Future<void>.value();
    }));
    await tester.tap(card(0));
    await tester.pump(const Duration(seconds: 1));
    request.completeError(StateError('request rejected'));
    await tester.pump();
    expect(tester.takeException(), isA<StateError>());
    expect(find.byKey(ValueKey('hand-pending-${cards[0].firebaseKey}')), findsNothing);
    await tester.tap(card(0));
    await tester.pump();
    expect(calls, 2);
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

  testWidgets('dealt cards enter the hand in a short sequence', (tester) async {
    await tester.pumpWidget(hand(true, (_, __) {}));
    final first = find.byKey(ValueKey('visual-${cards.first.firebaseKey}'));
    final last = find.byKey(ValueKey('visual-${cards.last.firebaseKey}'));
    final firstStart = tester.getRect(first).center;
    final lastStart = tester.getRect(last).center;
    expect(firstStart.dx, closeTo(lastStart.dx, 1));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getRect(first).center.dy, greaterThan(firstStart.dy));
    expect(tester.getRect(last).center.dy, lastStart.dy);
    await tester.pumpAndSettle();
    final firstSettled = tester.getRect(first).center;
    final lastSettled = tester.getRect(last).center;
    expect(firstSettled.dy - firstStart.dy, greaterThan(80));
    expect(lastSettled.dy, greaterThan(lastStart.dy));
    expect(lastSettled.dx - firstSettled.dx, greaterThan(100));
  });

  testWidgets('reduced motion deals directly into the final hand', (tester) async {
    final first = find.byKey(ValueKey('visual-${cards.first.firebaseKey}'));
    await tester.pumpWidget(MaterialApp(home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Scaffold(body: SizedBox(width: 390, child: FannedHandWidget(
        cards: cards, isMyTurn: true, onCardTap: (_, __) {},
        cardBuilder: (card, width, height) => SizedBox(
          key: ValueKey('visual-${card.firebaseKey}'),
          width: width, height: height),
      ))),
    )));
    final start = tester.getRect(first).center;
    await tester.pumpAndSettle();
    expect(tester.getRect(first).center, start);
    expect(tester.widget<Opacity>(find.descendant(
      of: find.byKey(ValueKey('hand-visual-${cards.first.firebaseKey}')),
      matching: find.byType(Opacity),
    )).opacity, 1);
  });

  testWidgets('remaining cards glide into place after a play', (tester) async {
    await tester.pumpWidget(hand(true, (_, __) {}));
    await tester.pumpAndSettle();
    final before = tester.getRect(card(1)).center;
    await tester.pumpWidget(hand(true, (_, __) {},
      values: [cards[0], cards[1], cards[3]]));
    final atStart = tester.getRect(card(1)).center;
    await tester.pump(const Duration(milliseconds: 90));
    final midway = tester.getRect(card(1)).center;
    await tester.pumpAndSettle();
    final settled = tester.getRect(card(1)).center;
    expect(atStart.dx, closeTo(before.dx, 1));
    expect(midway.dx, greaterThan(atStart.dx));
    expect(midway.dx, lessThan(settled.dx));
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
