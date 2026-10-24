// Integration fixture: real gestures -> unchanged local engine -> native visual
// projection. No account, room, server, bot scheduler or real deadline is run.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/logic/game_engine.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as game;
import 'package:halabessa/features/game/domain/models/card_feature_state.dart';
import 'package:halabessa/features/game/domain/models/game_action.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/game/presentation/providers/unity_visual_presentation.dart';
import 'package:halabessa/features/game/presentation/widgets/fanned_hand_widget.dart';
import 'package:halabessa/features/game/presentation/widgets/hand_card_placement.dart';
import 'package:halabessa/features/game/presentation/widgets/option_b_table.dart';
import 'package:halabessa/features/game/presentation/widgets/shown_card_layer.dart';

const local = 'a';
const localCards = [
  game.Card(game.Suit.clubs, game.Rank.six),
  game.Card(game.Suit.hearts, game.Rank.nine),
  game.Card(game.Suit.spades, game.Rank.three),
  game.Card(game.Suit.diamonds, game.Rank.king),
];
Finder cardSlot(int index) =>
    find.byKey(ValueKey('hand-card-${localCards[index].firebaseKey}'));

MatchState seed() {
  const board = [
    game.Card(game.Suit.hearts, game.Rank.two),
    game.Card(game.Suit.diamonds, game.Rank.eight),
    game.Card(game.Suit.spades, game.Rank.four),
    game.Card(game.Suit.hearts, game.Rank.king),
  ];
  final spare = [
    for (final s in game.Suit.values)
      for (final r in game.Rank.values) game.Card(s, r),
  ]..removeWhere((c) => [...localCards, ...board].contains(c));
  return MatchState(
    id: 'OFFLINE_TRACE',
    mode: GameMode.classic,
    playerIds: const ['a', 'b', 'c', 'd'],
    dealerIndex: 0,
    currentTurnIndex: 1,
    phase: GamePhase.playing,
    board: board,
    deckCount: 32,
    handCards: {
      'a': localCards,
      'b': spare.sublist(0, 4),
      'c': spare.sublist(4, 8),
      'd': spare.sublist(8, 12),
    },
  );
}

class TraceFixture {
  MatchState state = seed();
  final wire = <Map<String, dynamic>>[];
  final slaps = <String>[];
  int normalPlays = 0, slamPlays = 0;
  late final renderer = UnityVisualPresentation(
    send: wire.add,
    onContact: (_, __) {},
    onGestureContact: slaps.add,
  );
  TraceFixture() {
    accept();
    renderer.negotiate(1, interactions: true);
  }
  void accept() => renderer.accept(
    state,
    local,
    active: true,
    reduced: false,
    interactions: true,
  );
  void acknowledge() {
    final actions = wire.where((m) => m['type'] == 'VISUAL_ACTION').toList();
    if (actions.isNotEmpty)
      renderer.acknowledge(actions.last['eventId'], actions.last['generation']);
  }

  void play(game.Card card, {bool slam = false}) {
    final before = state;
    final normal = GameEngine.apply(
      before,
      PlayCardAction(local, card),
    ).newState;
    expect(normal.handCards[local], isNot(contains(card)));
    if (slam) {
      slamPlays++;
      state = CardFeatureState(before).acceptedLocalSlam(normal, local, card);
    } else {
      normalPlays++;
      state = normal;
    }
    expect(
      state.copyWith(cardFeatures: normal.cardFeatures).toJson(),
      normal.toJson(),
      reason: 'Delivery metadata must not alter any accepted gameplay field.',
    );
    accept();
  }

  Widget scene() => MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: 360,
              child: FannedHandWidget(
                cards: state.handCards[local]!,
                renderArtwork: false,
                isMyTurn: state.currentTurnIndex == 0,
                onCardTap: (card, _) => play(card),
                onCardSlam: (card, _) => play(card, slam: true),
                onCardReveal: (card, _) {
                  state = CardFeatureState(state).showLocal(local, card);
                  accept();
                },
                onSelectionPose: (card, queued, slam) => renderer
                    .updateHandSelection(card.firebaseKey, queued, slam),
                slamUsesRemaining: CardFeatureState(
                  state,
                ).remaining(local, slam: true),
                revealUsesRemaining: CardFeatureState(state).remaining(local),
                cardBuilder: (_, width, height) =>
                    SizedBox(width: width, height: height),
              ),
            ),
          ),
          Positioned.fill(
            child: ShownCardLayer(
              cards: CardFeatureState(state).visible,
              seats: state.playerIds,
              localUid: local,
              geometry: OptionBGeometry(const Size(800, 600)),
              faceBuilder: (_, w, h) => SizedBox(width: w, height: h),
              backBuilder: (w, h) => SizedBox(width: w, height: h),
            ),
          ),
        ],
      ),
    ),
  );
  Future<void> peersToTurn(WidgetTester tester) async {
    while (state.currentTurnIndex != 0) {
      final uid = state.playerIds[state.currentTurnIndex];
      final candidate = state.handCards[uid]!
          .map((card) => GameEngine.apply(state, PlayCardAction(uid, card)))
          .firstWhere((result) => result.capturedCards.isEmpty);
      state = candidate.newState;
      accept();
      acknowledge();
      await tester.pumpWidget(scene());
      await tester.pump();
    }
  }

  Future<void> close(WidgetTester tester, String label) async {
    if (const bool.fromEnvironment('UNITY_GESTURE_TRACE')) {
      final folder = Directory('build/gesture-traces')
        ..createSync(recursive: true);
      File(
        '${folder.path}/$label.json',
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(wire));
    }
    await tester.pumpWidget(const SizedBox());
    renderer.dispose();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  }
}

Future<void> hold(WidgetTester tester, int index) async {
  final gesture = await tester.startGesture(tester.getCenter(cardSlot(index)));
  await tester.pump(const Duration(milliseconds: 600));
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets(
    'native queued slam cancels during real turn entry without consuming a use',
    (tester) async {
      final f = TraceFixture();
      await tester.pumpWidget(f.scene());
      await tester.pumpAndSettle();
      await hold(tester, 0);
      expect(f.wire.last['type'], 'HAND_SELECTION');
      expect(f.wire.last['queued'], true);
      expect(f.wire.last['slam'], true);
      expect(f.slamPlays, 0);
      await f.peersToTurn(tester);
      await tester.tap(cardSlot(0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(f.normalPlays + f.slamPlays, 0);
      expect(CardFeatureState(f.state).remaining(local, slam: true), 3);
      expect(f.wire.last['queued'], false);
      await tester.tap(cardSlot(1));
      await tester.pumpWidget(f.scene());
      expect(f.normalPlays, 1);
      expect(f.slamPlays, 0);
      await f.close(tester, 'cancel-at-turn-entry');
    },
  );
  testWidgets(
    'native queued slam executes once, consumes only accepted slam and emits one slap',
    (tester) async {
      final f = TraceFixture();
      await tester.pumpWidget(f.scene());
      await tester.pumpAndSettle();
      await hold(tester, 0);
      await f.peersToTurn(tester);
      await tester.pump(const Duration(milliseconds: 301));
      await tester.pumpWidget(f.scene());
      expect(f.slamPlays, 1);
      expect(f.normalPlays, 0);
      expect(CardFeatureState(f.state).remaining(local, slam: true), 2);
      expect(CardFeatureState(f.state).remaining(local), 3);
      final slam = f.wire.lastWhere((m) => m['type'] == 'VISUAL_ACTION');
      expect(slam['deliveryStyle'], 'slam');
      expect(slam['durationMs'], cardUiRefinements ? 500 : 470);
      expect(f.renderer.contact(slam['eventId'], slam['generation']), true);
      expect(f.renderer.contact(slam['eventId'], slam['generation']), false);
      expect(f.slaps, hasLength(1));
      await tester.pump(const Duration(milliseconds: 250));
      expect(f.slamPlays, 1);
      await f.close(tester, 'accepted-queued-slam');
    },
  );
  testWidgets(
    'public show preserves original hand, private queue and ordinary later play',
    (tester) async {
      final f = TraceFixture();
      await tester.pumpWidget(f.scene());
      await tester.pumpAndSettle();
      await tester.tap(cardSlot(0));
      await tester.pumpAndSettle();
      final before = f.state;
      await tester.drag(cardSlot(1), const Offset(0, 70));
      await tester.pumpWidget(f.scene());
      await tester.pumpAndSettle();
      expect(
        f.state.copyWith(cardFeatures: before.cardFeatures).toJson(),
        before.toJson(),
      );
      expect(f.state.handCards[local], contains(localCards[1]));
      expect(CardFeatureState(f.state).visible.single.card, localCards[1]);
      expect(CardFeatureState(f.state).remaining(local), 2);
      expect(CardFeatureState(f.state).remaining(local, slam: true), 3);
      expect(f.normalPlays + f.slamPlays, 0);
      // Showing is Flutter-owned: the native snapshot still contains only actual
      // board cards + local private hand, never a duplicate capture target.
      final snapshot = f.wire.lastWhere((m) => m['type'] == 'SYNC_STATE');
      expect(snapshot['board'], before.board.map((c) => c.toJson()).toList());
      expect(snapshot.containsKey('cardFeatures'), false);
      expect(snapshot['handSelections'], [
        {'cardId': localCards[0].firebaseKey, 'queued': true, 'slam': false},
      ]);
      await f.peersToTurn(tester);
      await tester.pump(const Duration(milliseconds: 301));
      await tester.pumpWidget(f.scene());
      expect(f.normalPlays, 1);
      expect(CardFeatureState(f.state).visible.single.card, localCards[1]);
      // Real peers cannot complete three turns in the same frame. Let the
      // existing 600 ms duplicate-input guard expire before the next cycle.
      await tester.pump(const Duration(milliseconds: 600));
      await f.peersToTurn(tester);
      await tester.tap(cardSlot(1));
      await tester.pumpWidget(f.scene());
      expect(f.normalPlays, 2);
      expect(f.slamPlays, 0);
      expect(CardFeatureState(f.state).visible, isEmpty);
      expect(
        CardFeatureState(f.state).remaining(local),
        2,
        reason: 'A played disclosure is not refunded.',
      );
      await f.close(tester, 'show-then-ordinary-play');
    },
  );
}
