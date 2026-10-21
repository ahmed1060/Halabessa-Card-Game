import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/logic/deck.dart';
import 'package:halabessa/features/game/domain/logic/game_engine.dart';
import 'package:halabessa/features/game/domain/models/game_action.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/game/presentation/widgets/deck_action_presentation.dart';

final _time = DateTime.utc(2026, 10, 21, 12);
const _home = Rect.fromLTWH(260, 42, 56, 76);
MatchState snapshot(
  GamePhase phase, {
  int version = 1,
  int shuffled = 0,
  String id = 'deck-test',
  DateTime? started,
}) => MatchState(
  id: id,
  mode: GameMode.classic,
  playerIds: const ['a', 'b', 'c', 'd'],
  dealerIndex: 0,
  currentTurnIndex: 1,
  roundCount: 2,
  phase: phase,
  serverVersion: version,
  roundsSinceLastShuffle: shuffled,
  phaseStartedAt: started ?? _time,
  deckCount: 52,
);

Widget harness(
  MatchState state,
  List<String> sounds, {
  bool reduced = false,
  Object renderer = false,
  Size size = const Size(1000, 430),
  VoidCallback? cut,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(size: size, disableAnimations: reduced),
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: DeckActionPresentation(
          state: state,
          rendererIdentity: renderer,
          home: _home,
          tableSize: size,
          shuffleLabel: 'Shuffling',
          now: () => _time,
          backBuilder: (w, h) => SizedBox(
            width: w,
            height: h,
            child: const ColoredBox(color: Colors.indigo),
          ),
          onFeedback: (id, kind) => sounds.add('$id/${kind.name}'),
          builder: (hidden, overlay) => Stack(
            children: [
              Positioned.fromRect(
                rect: _home,
                child: Opacity(
                  key: const ValueKey('home-deck'),
                  opacity: hidden ? 0 : 1,
                  child: const ColoredBox(color: Colors.blue),
                ),
              ),
              Positioned(
                left: 5,
                bottom: 5,
                child: FilledButton(
                  onPressed: cut ?? () {},
                  child: const Text('Cut'),
                ),
              ),
              if (overlay != null) overlay,
            ],
          ),
        ),
      ),
    ),
  ),
);

void main() {
  void viewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 430);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'accepted shuffle centers one deck, contacts once and restores home',
    (tester) async {
      viewport(tester);
      final cues = <String>[];
      final vote = snapshot(GamePhase.shuffleVoting);
      await tester.pumpWidget(harness(vote, cues));
      expect(find.byKey(const ValueKey('deck-action-art')), findsNothing);
      final shuffled = snapshot(GamePhase.preRoundCut, version: 2);
      await tester.pumpWidget(harness(shuffled, cues));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.getCenter(find.byKey(const ValueKey('deck-action-art'))),
        const Offset(500, 215),
      );
      expect(
        tester.widget<Opacity>(find.byKey(const ValueKey('home-deck'))).opacity,
        0,
      );
      await tester.pumpWidget(harness(shuffled, cues)); // Duplicate delivery.
      await tester.pump(const Duration(milliseconds: 805));
      expect(find.byKey(const ValueKey('deck-action-art')), findsNothing);
      expect(
        tester.widget<Opacity>(find.byKey(const ValueKey('home-deck'))).opacity,
        1,
      );
      expect(cues.map((s) => s.split('/').last), [
        'shuffleMix',
        'shuffleMix',
        'shuffleContact',
      ]);
      await tester.pumpWidget(harness(shuffled, cues));
      await tester.pump(const Duration(seconds: 2));
      expect(cues, hasLength(3));
    },
  );
  testWidgets(
    'cut separates intact packets then transfers upper packet underneath',
    (tester) async {
      viewport(tester);
      final cues = <String>[];
      await tester.pumpWidget(
        harness(snapshot(GamePhase.preRoundCut, shuffled: 1), cues),
      );
      await tester.pumpWidget(
        harness(snapshot(GamePhase.dealingFasha, version: 2), cues),
      );
      await tester.pump(const Duration(milliseconds: 210));
      final upper = tester.getCenter(
        find.byKey(const ValueKey('deck-upper-packet')),
      );
      final lower = tester.getCenter(
        find.byKey(const ValueKey('deck-lower-packet')),
      );
      expect(upper.dx, greaterThan(lower.dx + 20));
      await tester.pump(const Duration(milliseconds: 160));
      final packets = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .where(
            (w) =>
                w.key == const ValueKey('deck-upper-packet') ||
                w.key == const ValueKey('deck-lower-packet'),
          )
          .toList();
      expect(
        packets.first.key,
        const ValueKey('deck-upper-packet'),
      ); // Painted below lower.
      await tester.pump(const Duration(milliseconds: 285));
      expect(cues.map((s) => s.split('/').last), ['cutSeparate', 'cutContact']);
      expect(find.byKey(const ValueKey('deck-action-art')), findsNothing);
    },
  );
  testWidgets(
    'fast cut remains clickable, returns from center then cuts without stale shuffle sound',
    (tester) async {
      viewport(tester);
      final cues = <String>[];
      var commands = 0;
      await tester.pumpWidget(harness(snapshot(GamePhase.shuffleVoting), cues));
      await tester.pumpWidget(
        harness(
          snapshot(GamePhase.preRoundCut, version: 2),
          cues,
          cut: () => commands++,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Cut'));
      expect(commands, 1);
      await tester.pumpWidget(
        harness(snapshot(GamePhase.dealingFasha, version: 3), cues),
      );
      await tester.pump(const Duration(milliseconds: 125));
      await tester.pump(const Duration(milliseconds: 655));
      expect(cues.map((s) => s.split('/').last), [
        'shuffleMix',
        'cutSeparate',
        'cutContact',
      ]);
      expect(find.byKey(const ValueKey('deck-action-art')), findsNothing);
    },
  );
  testWidgets(
    'reduced motion stays home and uses one contact, not mixing cues',
    (tester) async {
      viewport(tester);
      final cues = <String>[];
      await tester.pumpWidget(
        harness(snapshot(GamePhase.shuffleVoting), cues, reduced: true),
      );
      await tester.pumpWidget(
        harness(
          snapshot(GamePhase.preRoundCut, version: 2),
          cues,
          reduced: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 40));
      expect(
        tester.getCenter(find.byKey(const ValueKey('deck-action-art'))),
        _home.center,
      );
      await tester.pump(const Duration(milliseconds: 40));
      expect(cues.map((s) => s.split('/').last), ['shuffleContact']);
      expect(find.text('Shuffling'), findsNothing);
    },
  );
  for (final reason in [
    'resize',
    'renderer',
    'room',
    'background',
    'overtaken',
  ]) {
    testWidgets(
      '$reason cancels active motion and future sounds without replay',
      (tester) async {
        viewport(tester);
        final cues = <String>[];
        await tester.pumpWidget(
          harness(snapshot(GamePhase.shuffleVoting), cues),
        );
        final next = snapshot(GamePhase.preRoundCut, version: 2);
        await tester.pumpWidget(harness(next, cues));
        await tester.pump(const Duration(milliseconds: 100));
        if (reason == 'background') {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump();
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        } else {
          await tester.pumpWidget(
            harness(
              reason == 'room'
                  ? snapshot(GamePhase.preRoundCut, id: 'another')
                  : reason == 'overtaken'
                  ? snapshot(GamePhase.playing, version: 3)
                  : next,
              cues,
              renderer: reason == 'renderer',
              size: reason == 'resize'
                  ? const Size(430, 932)
                  : const Size(1000, 430),
            ),
          );
        }
        await tester.pump(const Duration(seconds: 2));
        expect(cues, isEmpty);
        expect(find.byKey(const ValueKey('deck-action-art')), findsNothing);
      },
    );
  }
  testWidgets('ordinary mount and stale accepted shuffle never replay', (
    tester,
  ) async {
    viewport(tester);
    final cues = <String>[];
    await tester.pumpWidget(harness(snapshot(GamePhase.preRoundCut), cues));
    expect(find.byKey(const ValueKey('deck-action-art')), findsNothing);
    await tester.pumpWidget(
      harness(snapshot(GamePhase.shuffleVoting, version: 2), cues),
    );
    await tester.pumpWidget(
      harness(
        snapshot(
          GamePhase.preRoundCut,
          version: 3,
          started: _time.subtract(const Duration(seconds: 4)),
        ),
        cues,
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(cues, isEmpty);
    expect(find.byKey(const ValueKey('deck-action-art')), findsNothing);
  });
  testWidgets(
    'presentation never changes accepted state values or emits commands',
    (tester) async {
      viewport(tester);
      final cues = <String>[];
      final vote = snapshot(GamePhase.shuffleVoting);
      final cut = snapshot(GamePhase.preRoundCut, version: 2);
      final deal = snapshot(GamePhase.dealingFasha, version: 3);
      final before = [vote.toJson(), cut.toJson(), deal.toJson()];
      for (final state in [vote, cut, deal]) {
        await tester.pumpWidget(harness(state, cues));
        await tester.pump(const Duration(milliseconds: 1300));
      }
      expect([vote.toJson(), cut.toJson(), deal.toJson()], before);
    },
  );
  testWidgets(
    'real cut/deal trace preserves deck order, ownership, scores and deadlines with motion on or off',
    (tester) async {
      viewport(tester);
      final traces = <List<Object>>[];
      for (final motion in [false, true]) {
        final deck = Deck.standard();
        final cues = <String>[];
        var state = snapshot(GamePhase.shuffleVoting);
        final trace = <Object>[];
        if (motion) await tester.pumpWidget(harness(state, cues));
        state = state.copyWith(phase: GamePhase.preRoundCut, serverVersion: 2);
        if (motion) {
          await tester.pumpWidget(harness(state, cues));
          await tester.pump(const Duration(milliseconds: 350));
        }
        state = GameEngine.apply(
          state,
          CutAction('a', 20),
          secretDeck: deck,
        ).newState;
        trace.add(state.toJson());
        trace.add(deck.cards.map((c) => c.firebaseKey).toList());
        if (motion) {
          await tester.pumpWidget(harness(state, cues));
          await tester.pump(const Duration(milliseconds: 125));
          await tester.pump(const Duration(milliseconds: 655));
        }
        state = GameEngine.apply(
          state,
          DealAction('a', isInitial: true),
          secretDeck: deck,
        ).newState;
        trace.add(state.toJson());
        trace.add(deck.cards.map((c) => c.firebaseKey).toList());
        if (motion) await tester.pumpWidget(harness(state, cues));
        traces.add(trace);
      }
      expect(traces[1], traces[0]);
    },
  );
  testWidgets(
    'confirmed rematch shuffles once; a room switch never replays it',
    (tester) async {
      viewport(tester);
      final cues = <String>[];
      final ended = snapshot(GamePhase.rematchVoting);
      final rematch = snapshot(
        GamePhase.preRoundCut,
      ).copyWith(matchSequence: 1, roundCount: 1);
      await tester.pumpWidget(harness(ended, cues));
      await tester.pumpWidget(harness(rematch, cues));
      await tester.pump(const Duration(milliseconds: 1205));
      expect(cues, hasLength(3));
      cues.clear();
      await tester.pumpWidget(
        harness(rematch.copyWith(id: 'another-room'), cues),
      );
      await tester.pump(const Duration(milliseconds: 1205));
      expect(cues, isEmpty);
    },
  );
  testWidgets(
    'delayed cut snapshot settles silently instead of replaying history',
    (tester) async {
      viewport(tester);
      final cues = <String>[];
      await tester.pumpWidget(harness(snapshot(GamePhase.preRoundCut), cues));
      await tester.pumpWidget(
        harness(
          snapshot(
            GamePhase.dealingFasha,
            version: 2,
            started: _time.subtract(const Duration(seconds: 2)),
          ),
          cues,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(cues, isEmpty);
      expect(find.byKey(const ValueKey('deck-action-art')), findsNothing);
    },
  );
}
