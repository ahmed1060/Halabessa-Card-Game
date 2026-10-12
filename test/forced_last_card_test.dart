import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/core/services/multimedia_service.dart';
import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as game;
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/game/domain/providers/game_providers.dart';

class _QuietAudio extends ChangeNotifier implements MultimediaService {
  @override
  Future<void> playSfx(String assetPath) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const ace = game.Card(game.Suit.hearts, game.Rank.ace);
  const two = game.Card(game.Suit.clubs, game.Rank.two);
  const three = game.Card(game.Suit.clubs, game.Rank.three);
  final initial = MatchState(
    id: 'OFFLINE_LAST_CARD',
    mode: GameMode.classic,
    playerIds: ['human', 'bot_1', 'bot_2', 'bot_3'],
    dealerIndex: 0,
    currentTurnIndex: 0,
    phase: GamePhase.playing,
    turnStartTime: DateTime.utc(2026, 10, 11),
    handCards: const {
      'human': [ace],
      'bot_1': [two, three],
      'bot_2': [two, three],
      'bot_3': [two, three],
    },
  );

  ProviderContainer setup(MatchState state) {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        multimediaServiceProvider.overrideWith((ref) => _QuietAudio()),
        currentUserProvider.overrideWithValue(null),
      ],
    );
    final notifier = container.read(matchStateProvider.notifier);
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    notifier.state = state;
    notifier.bindToMatch(state.id);
    return container;
  }

  testWidgets(
    'Training forces the active last card without a tap, not another hand',
    (tester) async {
      final container = setup(initial);
      await tester.pump(const Duration(milliseconds: 599));
      expect(container.read(matchStateProvider)!.board, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      final played = container.read(matchStateProvider)!;
      expect(played.handCards['human'], isEmpty);
      expect(played.board, [ace]);
      expect(played.currentTurnIndex, 1);
      expect(played.board, hasLength(1));
      expect(played.handCards['bot_1'], [two, three]);
      container.dispose();
      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets('manual last-card play cancels the delayed forced move', (
    tester,
  ) async {
    final container = setup(initial.copyWith(
      playerIds: ['human', 'next', 'third', 'fourth'],
      timerDurationSeconds: 0,
      handCards: const {'human': [ace], 'next': [two, three],
        'third': [two, three], 'fourth': [two, three]},
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await container.read(matchStateProvider.notifier).playCard('human', ace);
    await tester.pump(const Duration(milliseconds: 600));
    expect(container.read(matchStateProvider)!.board, [ace]);
    expect(container.read(matchStateProvider)!.currentTurnIndex, 1);
    container.dispose();
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets(
    'Training capture completes in 600 ms and records one collection',
    (tester) async {
      final container = setup(
        initial.copyWith(
          handCards: const {
            'human': [ace, two],
            'bot_1': [two, three],
            'bot_2': [two, three],
            'bot_3': [two, three],
          },
          board: const [game.Card(game.Suit.diamonds, game.Rank.ace)],
        ),
      );
      final play = container
          .read(matchStateProvider.notifier)
          .playCard('human', ace);
      await tester.pump();
      expect(container.read(matchStateProvider)!.phase, GamePhase.capturing);
      await tester.pump(const Duration(milliseconds: 300));
      expect(container.read(matchStateProvider)!.capturingStage, 1);
      await tester.pump(const Duration(milliseconds: 300));
      expect(await play, true);
      expect(container.read(matchStateProvider)!.phase, GamePhase.playing);
      expect(
        container.read(matchStateProvider)!.harvestStacks['teamA'],
        hasLength(1),
      );
      container.dispose();
      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets(
    'leaving Training before the forced move cannot play into a new room',
    (tester) async {
      final container = setup(initial);
      await tester.pump(const Duration(milliseconds: 100));
      final notifier = container.read(matchStateProvider.notifier);
      await notifier.leaveMatch(notifyServer: false);
      await tester.pump(const Duration(milliseconds: 600));
      expect(container.read(matchStateProvider), isNull);
      container.dispose();
    },
  );
}
