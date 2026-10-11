import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as game;
import 'package:halabessa/features/game/presentation/widgets/local_card_play_layer.dart';
import 'package:halabessa/features/game/presentation/widgets/fanned_hand_widget.dart';
import 'package:halabessa/features/game/presentation/widgets/board_cards_widget.dart';
import 'package:halabessa/features/game/presentation/widgets/board_card_motion.dart';
import 'package:halabessa/features/game/presentation/widgets/match_table_layout.dart';

const cards = [
  game.Card(game.Suit.clubs, game.Rank.six),
  game.Card(game.Suit.diamonds, game.Rank.nine),
  game.Card(game.Suit.clubs, game.Rank.ace),
  game.Card(game.Suit.spades, game.Rank.eight),
];

class Harness extends StatefulWidget {
  final TextDirection direction;
  final bool landscape, reducedMotion;
  final double scale;
  final bool enabled;
  const Harness({
    super.key,
    this.direction = TextDirection.ltr,
    this.landscape = false,
    this.reducedMotion = false,
    this.scale = 1,
    this.enabled = true,
  });
  @override
  State<Harness> createState() => HarnessState();
}

class HarnessState extends State<Harness> {
  final boardKey = GlobalKey();
  final requests = <Completer<bool>>[];
  List<game.Card> hand = [...cards], board = [];
  String identity = 'room:round:hand:uid';
  void commit() => setState(() {
    hand = cards.skip(1).toList();
    board = [cards.first];
  });
  void changeRoom() => setState(() => identity = 'another-room');
  @override
  Widget build(BuildContext context) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: widget.reducedMotion),
      child: Directionality(
        textDirection: widget.direction,
        child: Scaffold(
          body: LocalCardPlayLayer(
            identity: identity,
            enabled: widget.enabled,
            hand: hand,
            boardCount: board.length,
            boardKey: boardKey,
            isLandscape: widget.landscape,
            submit: (_, __) {
              final request = Completer<bool>();
              requests.add(request);
              return request.future;
            },
            cardBuilder: (card, width, height) => SizedBox(
              key: ValueKey('preview-${card.firebaseKey}'),
              width: width,
              height: height,
              child: const ColoredBox(color: Colors.white),
            ),
            builder: (hidden, presented, play) => Stack(
              children: [
                Positioned(
                  left: 140,
                  top: 60,
                  width: 200,
                  height: 170,
                  child: Transform.scale(
                    scale: widget.scale,
                    child: SizedBox(
                      key: boardKey,
                      child: BoardCardsWidget(
                        cards: board,
                        cardBuilder: (card, width, height) =>
                            SizedBox(width: width, height: height),
                        alreadyPresented: presented,
                        isLandscape: widget.landscape,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 70,
                  bottom: 30,
                  width: 390,
                  child: Transform.scale(
                    scale: widget.scale,
                    child: FannedHandWidget(
                      cards: hand,
                      isMyTurn: true,
                      interactionEnabled: hidden == null,
                      hiddenCard: hidden,
                      onCardTap: play,
                      cardBuilder: (card, width, height) => SizedBox(
                        key: ValueKey('art-${card.firebaseKey}'),
                        width: width,
                        height: height,
                        child: const ColoredBox(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Finder target(int index) =>
    find.byKey(ValueKey('hand-card-${cards[index].firebaseKey}'));
Finder preview() => find.byKey(ValueKey('preview-${cards.first.firebaseKey}'));

void main() {
  testWidgets(
    'offline path retains authoritative arrival instead of masking the hand',
    (tester) async {
      final key = GlobalKey<HarnessState>();
      await tester.pumpWidget(Harness(key: key, enabled: false));
      await tester.pumpAndSettle();
      await tester.tap(target(0));
      await tester.pump();
      expect(preview(), findsNothing);
      expect(key.currentState!.requests, hasLength(1));
      key.currentState!.commit();
      key.currentState!.requests.single.complete(true);
      await tester.pump();
      final arrival = tester.widget<BoardCardMotion>(
        find.byKey(ValueKey('board-${cards.first.firebaseKey}')),
      );
      expect(arrival.alreadyArrived, isFalse);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'tap starts flight before a slow reply without mutating match data',
    (tester) async {
      final key = GlobalKey<HarnessState>();
      await tester.pumpWidget(Harness(key: key));
      await tester.pumpAndSettle();
      final handPosition = tester.getCenter(target(0));
      await tester.tap(target(0));
      await tester.pump();
      expect(preview(), findsOneWidget);
      final start = tester.getCenter(preview());
      expect((start - handPosition).distance, lessThan(1));
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.getCenter(preview()).dy, lessThan(start.dy));
      await tester.pump(const Duration(milliseconds: 150));
      final settled = tester.getCenter(preview());
      expect(settled, tester.getCenter(find.byKey(key.currentState!.boardKey)));
      expect(key.currentState!.hand, cards);
      expect(key.currentState!.board, isEmpty);
      expect(key.currentState!.requests.single.isCompleted, isFalse);
      await tester.tap(target(1));
      await tester.drag(target(2), const Offset(0, -70));
      expect(key.currentState!.requests, hasLength(1));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.getCenter(preview()), settled);
      key.currentState!.requests.single.complete(true);
      await tester.pump();
      expect(preview(), findsOneWidget); // Await the actual private view.
      key.currentState!.commit();
      await tester.pump();
      expect(preview(), findsNothing);
      final motion = tester.widget<BoardCardMotion>(
        find.byKey(ValueKey('board-${cards.first.firebaseKey}')),
      );
      expect(motion.alreadyArrived, isTrue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rejection reverses artwork and restores the same hand', (
    tester,
  ) async {
    final key = GlobalKey<HarnessState>();
    await tester.pumpWidget(Harness(key: key));
    await tester.pumpAndSettle();
    await tester.tap(target(0));
    await tester.pumpAndSettle();
    final destination = tester.getCenter(preview());
    key.currentState!.requests.single.complete(false);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(tester.getCenter(preview()).dy, greaterThan(destination.dy));
    await tester.pumpAndSettle();
    expect(preview(), findsNothing);
    expect(key.currentState!.hand, cards);
    expect(key.currentState!.board, isEmpty);
    await tester.tap(target(0));
    expect(key.currentState!.requests, hasLength(2));
    final retry = key.currentState!.requests.last;
    await tester.pumpWidget(const SizedBox());
    retry.complete(false);
  });

  testWidgets(
    'private view before lost reply never restores a committed card',
    (tester) async {
      final key = GlobalKey<HarnessState>();
      await tester.pumpWidget(Harness(key: key));
      await tester.pumpAndSettle();
      await tester.tap(target(0));
      await tester.pump();
      final request = key.currentState!.requests.single;
      key.currentState!.commit();
      await tester.pump();
      expect(preview(), findsNothing);
      request.complete(false);
      await tester.pumpAndSettle();
      expect(target(0), findsNothing);
      expect(key.currentState!.board, [cards.first]);
      expect(tester.takeException(), isNull);
    },
  );

  for (final accept in [true, false]) {
    testWidgets('room change ignores late result $accept', (tester) async {
      final key = GlobalKey<HarnessState>();
      await tester.pumpWidget(Harness(key: key));
      await tester.pumpAndSettle();
      await tester.tap(target(0));
      await tester.pump();
      final request = key.currentState!.requests.single;
      key.currentState!.changeRoom();
      await tester.pump();
      request.complete(accept);
      await tester.pumpAndSettle();
      expect(preview(), findsNothing);
      expect(key.currentState!.hand, cards);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('disposed flight ignores late acknowledgement', (tester) async {
    final key = GlobalKey<HarnessState>();
    await tester.pumpWidget(Harness(key: key));
    await tester.pumpAndSettle();
    await tester.tap(target(0));
    await tester.pump();
    final request = key.currentState!.requests.single;
    await tester.pumpWidget(const SizedBox());
    request.complete(false);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  for (final direction in TextDirection.values) {
    for (final landscape in [false, true]) {
      testWidgets(
        'scaled flight matches actual board geometry $direction $landscape',
        (tester) async {
          final key = GlobalKey<HarnessState>();
          await tester.pumpWidget(
            Harness(
              key: key,
              scale: .75,
              direction: direction,
              landscape: landscape,
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(target(0));
          await tester.pumpAndSettle();
          final rect = tester.getRect(preview());
          expect(rect.width, closeTo((landscape ? 72 : 64) * .75, 1));
          expect(
            rect.center,
            tester.getCenter(find.byKey(key.currentState!.boardKey)),
          );
          key.currentState!.requests.single.complete(true);
          key.currentState!.commit();
          await tester.pumpAndSettle();
          expect(
            tester
                .getRect(
                  find.byKey(ValueKey('board-${cards.first.firebaseKey}')),
                )
                .center,
            rect.center,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'reduced motion renders immediately and rejection restores directly',
    (tester) async {
      final key = GlobalKey<HarnessState>();
      await tester.pumpWidget(Harness(key: key, reducedMotion: true));
      await tester.pump();
      await tester.tap(target(0));
      await tester.pump();
      expect(
        tester.getCenter(preview()),
        tester.getCenter(find.byKey(key.currentState!.boardKey)),
      );
      key.currentState!.requests.single.complete(false);
      await tester.pumpAndSettle();
      expect(preview(), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(390, 844),
    const Size(932, 430),
    const Size(740, 320),
  ]) {
    for (final direction in TextDirection.values) {
      testWidgets(
        'real table layout starts local play without overflow $size $direction',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final boardKey = GlobalKey();
          final response = Completer<bool>();
          var submissions = 0;
          await tester.pumpWidget(
            MaterialApp(
              home: Directionality(
                textDirection: direction,
                child: Scaffold(
                  body: LocalCardPlayLayer(
                    identity: 'room',
                    hand: cards,
                    boardCount: 3,
                    boardKey: boardKey,
                    isLandscape: size.width > size.height,
                    submit: (_, __) {
                      submissions++;
                      return response.future;
                    },
                    cardBuilder: (_, width, height) =>
                        SizedBox(width: width, height: height),
                    builder: (hidden, _, play) => MatchTableLayout(
                      header: const SizedBox(height: 72),
                      partner: const SizedBox(height: 80),
                      leftOpponent: const SizedBox(height: 80),
                      rightOpponent: const SizedBox(height: 80),
                      collections: const SizedBox(height: 110),
                      status: const Text('Your turn'),
                      controls: const SizedBox(height: 48),
                      board: SizedBox(key: boardKey, width: 200, height: 140),
                      hand: FannedHandWidget(
                        cards: cards,
                        isMyTurn: true,
                        interactionEnabled: hidden == null,
                        hiddenCard: hidden,
                        onCardTap: play,
                        cardBuilder: (_, width, height) =>
                            SizedBox(width: width, height: height),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(target(0));
          await tester.pumpAndSettle();
          expect(submissions, 1);
          expect(tester.takeException(), isNull);
          response.complete(false);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
