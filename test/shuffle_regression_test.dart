import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/core/services/multimedia_service.dart';
import 'package:halabessa/features/game/domain/logic/deck.dart';
import 'package:halabessa/features/game/domain/logic/game_engine.dart';
import 'package:halabessa/features/game/domain/models/capture.dart';
import 'package:halabessa/features/game/domain/models/game_action.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/game/domain/providers/game_providers.dart';

class SilentAudio extends ChangeNotifier implements MultimediaService {
  @override
  Future<void> playSfx(String path) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  final cards = Deck.standard().cards;
  MatchState room() => MatchState(
    id: 'OFFLINE_VOTE_TEST',
    mode: GameMode.classic,
    playerIds: const ['human', 'bot_2', 'bot_3', 'bot_4'],
    dealerIndex: 0,
    currentTurnIndex: 1,
    phase: GamePhase.shuffleVoting,
    roundCount: 3,
    timerDurationSeconds: 0,
    phaseStartedAt: DateTime.now(),
    shuffleVotes: const {'human': false},
    harvestStacks: {
      'teamA': [
        Capture(
          leadingCard: cards.first,
          capturedCards: cards.skip(1).toList(),
        ),
      ],
      'teamB': [],
    },
  );

  testWidgets('No starts exactly one round with 52 cards; bots cannot skip it', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        multimediaServiceProvider.overrideWith((ref) => SilentAudio()),
      ],
    );
    final notifier = container.read(matchStateProvider.notifier);
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    notifier.state = room();
    final snapshots = <MatchState>[];
    final listener = container.listen(matchStateProvider, (_, next) {
      if (next != null) snapshots.add(next);
    });
    notifier.bindToMatch(room().id);
    for (var tick = 0; tick < 12; tick++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(snapshots.any((s) => s.roundCount == 4 && s.deckCount == 52), true);
    expect(snapshots.every((s) => s.roundCount <= 4), true);
    expect(snapshots.any((s) => s.roundCount == 4 && s.deckCount == 0), false);
    expect(container.read(matchStateProvider)!.dealerIndex, 1);
    expect(await notifier.voteShuffle('bot_2', false), false);
    expect(container.read(matchStateProvider)!.roundCount, 4);
    listener.close();
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    notifier.state = container
        .read(matchStateProvider)!
        .copyWith(phase: GamePhase.matchOver);
    for (var tick = 0; tick < 10; tick++) {
      await tester.pump(const Duration(seconds: 1));
    }
    container.dispose();
  });
  test(
    'vote engine rejects bots, duplicate votes, wrong phases and late humans',
    () {
      final state = room();
      for (final id in ['bot_2', 'human', 'stranger']) {
        expect(
          GameEngine.apply(state, VoteAction(id, true)).newState,
          same(state),
        );
      }
      final closed = state.copyWith(
        phase: GamePhase.preRoundCut,
        shuffleVotes: {},
      );
      expect(
        GameEngine.apply(closed, VoteAction('human', true)).newState,
        same(closed),
      );
      final expired = state.copyWith(
        shuffleVotes: {},
        phaseStartedAt: DateTime.now().subtract(const Duration(seconds: 10)),
      );
      expect(
        GameEngine.apply(expired, VoteAction('human', true)).newState,
        same(expired),
      );
    },
  );
  testWidgets('expired rematch records missing human No and preserves results', (
    tester,
  ) async {
    final container = ProviderContainer();
    final notifier = container.read(matchStateProvider.notifier);
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    notifier.state = room().copyWith(
      phase: GamePhase.rematchVoting,
      playerIds: ['human', 'other', 'bot_3', 'bot_4'],
      teamAScore: 41,
      teamBScore: 20,
      phaseStartedAt: DateTime.now().subtract(const Duration(seconds: 10)),
      rematchVotes: {'human': true},
    );
    notifier.bindToMatch(room().id);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    final result = container.read(matchStateProvider)!;
    expect(result.phase, GamePhase.matchOver);
    expect(result.rematchVotes, {'human': true, 'other': false});
    expect(result.teamAScore, 41);
    expect(await notifier.voteRematch('other', true), false);
    await tester.pump(const Duration(milliseconds: 200));
    container.dispose();
  });
  test(
    'invalid restored deck cannot increment the round or clear state',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(matchStateProvider.notifier);
      final invalid = room().copyWith(
        harvestStacks: {'teamA': [], 'teamB': []},
      );
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      notifier.state = invalid;
      await notifier.startNewRound();
      expect(container.read(matchStateProvider), same(invalid));
    },
  );
}
