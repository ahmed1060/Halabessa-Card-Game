import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as game;
import 'package:halabessa/features/game/presentation/widgets/fanned_hand_widget.dart';
import 'package:halabessa/features/game/presentation/widgets/hand_card_placement.dart';
import 'package:halabessa/features/game/presentation/widgets/special_move_counters.dart';
import 'package:halabessa/features/game/presentation/widgets/table_seat.dart';
import 'package:halabessa/features/game/presentation/widgets/option_b_table.dart';
import 'package:halabessa/features/game/presentation/widgets/table_style.dart';

const cards = [
  game.Card(game.Suit.clubs, game.Rank.six),
  game.Card(game.Suit.diamonds, game.Rank.nine),
  game.Card(game.Suit.clubs, game.Rank.ace),
  game.Card(game.Suit.spades, game.Rank.eight),
];
Finder target(int i) =>
    find.byKey(ValueKey('hand-card-${cards[i].firebaseKey}'));

void main() {
  test(
    'shared placement parks up to three unique owned cards at physical right',
    () {
      for (final available in [270.0, 356.5, 430.0]) {
        for (var n = 0; n <= 3; n++) {
          final ids = cards.take(n).map((c) => c.firebaseKey).toSet();
          final p = HandCardPlacement(
            cards,
            ids,
            HandFanGeometry(available),
            refined: true,
          );
          expect(p.ordered.toSet(), cards.toSet());
          expect(p.ordered.length, 4);
          for (final card in cards) {
            expect(p.offset(card).dx, greaterThanOrEqualTo(0));
            expect(
              p.offset(card).dx + p.fan.width,
              lessThanOrEqualTo(p.extent + .01),
            );
          }
          if (n > 0) {
            expect(
              p.offset(cards.first).dx,
              greaterThan(p.offset(cards.last).dx),
            );
            expect(p.angle(cards.first), 0);
            expect(
              p.offset(cards.first).dx -
                  (p.offset(cards.last).dx + p.fan.width),
              closeTo(p.gap, .001),
              reason: 'the public dock needs a visible gap, not overlapping margin',
            );
          }
          expect(
            cards.first.rank,
            game.Rank.six,
            reason: 'domain order unchanged',
          );
        }
      }
    },
  );

  final played = <game.Card>[], origins = <CardPlayOrigin>[];
  Widget hand({bool turn = false, Set<String> publicIds = const {}}) =>
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 320,
              child: FannedHandWidget(
                cards: cards,
                publicCardIds: publicIds,
                isMyTurn: turn,
                onCardTap: (c, origin) {
                  played.add(c);
                  origins.add(origin);
                },
                onCardReveal: (_, __) {},
                onCardSlam: (_, __) {},
                revealUsesRemaining: 3,
                slamUsesRemaining: 3,
                cardBuilder: (_, w, h) => SizedBox(width: w, height: h),
              ),
            ),
          ),
        ),
      );
  setUp(() {
    played.clear();
    origins.clear();
  });
  Future<void> swipeUp(WidgetTester tester, int i) async {
    final pointer = await tester.startGesture(tester.getCenter(target(i)));
    await pointer.moveBy(const Offset(0, -22));
    await tester.pump(const Duration(milliseconds: 16));
    await pointer.moveBy(const Offset(0, -52));
    await tester.pump(const Duration(milliseconds: 16));
    await pointer.up();
    await tester.pump(const Duration(milliseconds: 160));
  }

  testWidgets(
    'off-turn up stays physically raised with no gold cue; short tap cancels',
    (tester) async {
      await tester.pumpWidget(hand());
      await tester.pumpAndSettle();
      final rest = tester.getCenter(target(1));
      await swipeUp(tester, 1);
      expect(played, isEmpty);
      final raised = tester.getCenter(target(1));
      expect(raised.dy, lessThan(rest.dy - 20));
      expect(
        find.byKey(ValueKey('hand-outline-${cards[1].firebaseKey}')),
        findsNothing,
      );
      expect(
        find.byKey(ValueKey('hand-remaining-${cards[1].firebaseKey}')),
        findsNothing,
      );
      await tester.pumpWidget(hand());
      await tester.pumpAndSettle();
      expect(tester.getCenter(target(1)).dy, closeTo(raised.dy, 1));
      await tester.tap(target(1));
      await tester.pumpAndSettle();
      expect(played, isEmpty);
      expect(tester.getCenter(target(1)).dy, closeTo(rest.dy, 1));
    },
    skip: !cardUiRefinements,
  );

  testWidgets(
    'on-turn swipe uses the visible released position, not the home slot',
    (tester) async {
      await tester.pumpWidget(hand(turn: true));
      await tester.pumpAndSettle();
      final rest = tester.getCenter(target(1));
      await swipeUp(tester, 1);
      expect(played, [cards[1]]);
      expect(origins.single.center.dy, lessThan(rest.dy - 25));
      await tester.pumpAndSettle();
    },
    skip: !cardUiRefinements,
  );

  testWidgets(
    'public card is one interactive card at right and can still be played',
    (tester) async {
      await tester.pumpWidget(hand(turn: true));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        hand(turn: true, publicIds: {cards.first.firebaseKey}),
      );
      await tester.pumpAndSettle();
      expect(target(0), findsOneWidget);
      expect(
        tester.getCenter(target(0)).dx,
        greaterThan(tester.getCenter(target(3)).dx),
      );
      await tester.tap(target(0));
      await tester.pumpAndSettle();
      expect(played, [cards.first]);
    },
    skip: !cardUiRefinements,
  );

  testWidgets(
    'bottom-right move indicators are icon/numbers, not labeled cards/buttons',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SpecialMoveCounters(
              slams: 3,
              reveals: 2,
              slamLabel: 'Slams remaining',
              revealLabel: 'Reveals remaining',
            ),
          ),
        ),
      );
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Slams remaining'), findsNothing);
      expect(find.byType(GestureDetector), findsNothing);
    },
  );

  testWidgets('capture numbers are colored text without number backgrounds', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: TeamCapturePreview(
            captures: const [],
            label: 'Captures',
            ourCount: 16,
            rivalCount: 21,
            faceBuilder: (_, w, h) => SizedBox(width: w, height: h),
            onPressed: () {},
          ),
        ),
      ),
    );
    for (final item in [
      ('history-our-count', TableStyle.mint),
      ('history-rival-count', TableStyle.red),
    ]) {
      final container = tester.widget<Container>(find.byKey(ValueKey(item.$1)));
      expect(container.decoration, isNull);
      expect((container.child as Text).style!.color, item.$2);
    }
  });

  testWidgets(
    'only bot portrait and name have difficulty tips; local has none',
    (tester) async {
      Widget seat(bool own) => MaterialApp(
        home: Center(
          child: TableSeat(
            optionB: true,
            isBot: !own,
            name: own ? 'You' : 'Bot 3',
            detail: 'Difficulty: Hard',
            showTooltip: !own,
          ),
        ),
      );
      await tester.pumpWidget(seat(false));
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      final bounds = tester.getRect(find.byType(TableSeat));
      await mouse.moveTo(bounds.bottomRight - const Offset(3, 3));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Difficulty: Hard'), findsNothing);
      await mouse.moveTo(tester.getCenter(find.text('Bot 3')));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Difficulty: Hard'), findsOneWidget);
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      await tester.pumpWidget(seat(true));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(TableSeat),
          matching: find.byType(Tooltip),
        ),
        findsNothing,
      );
      await mouse.removePointer();
    },
  );
}
