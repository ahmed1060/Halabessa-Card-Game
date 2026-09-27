import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/core/services/multimedia_service.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/game/domain/providers/game_providers.dart';

class _AudioEvents extends ChangeNotifier implements MultimediaService {
  void playbackChanged() => notifyListeners();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('audio playback events cannot reset the active match controller', () async {
    final audio = _AudioEvents();
    final container = ProviderContainer(overrides: [
      multimediaServiceProvider.overrideWith((ref) => audio),
    ]);
    addTearDown(container.dispose);
    final match = MatchState(
      id: 'LIFECYCLE_TEST', mode: GameMode.classic,
      playerIds: const ['human', 'bot_1', 'bot_2', 'bot_3'],
      dealerIndex: 0, currentTurnIndex: 1, phase: GamePhase.playing,
    );

    // Control reproduces the original dependency graph, proving that the
    // audio notification itself is sufficient to lose a populated match.
    final legacy = StateNotifierProvider<MatchStateNotifier, MatchState?>((ref) {
      ref.watch(multimediaServiceProvider);
      return MatchStateNotifier(ref);
    });
    final originalLegacy = container.read(legacy.notifier);
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    originalLegacy.state = match;
    final active = container.read(matchStateProvider.notifier);
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    active.state = match;
    active.lastBoundMatchId = match.id;

    audio.playbackChanged();
    await container.pump();
    expect(container.read(legacy), isNull);
    expect(identical(container.read(legacy.notifier), originalLegacy), isFalse);

    // Music start, SFX start, SFX completion, mute, and subsequent effects
    // must preserve both state and controller, not briefly show a loader.
    final observed = <MatchState?>[];
    final listener = container.listen(matchStateProvider, (_, next) => observed.add(next));
    addTearDown(listener.close);
    for (var event = 0; event < 12; event++) {
      audio.playbackChanged();
      await container.pump();
      expect(container.read(matchStateProvider.notifier), same(active));
      expect(container.read(matchStateProvider), same(match));
      expect(active.lastBoundMatchId, match.id);
    }
    expect(observed, isEmpty);
  });
}
