import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/game/domain/logic/server_progress_coordinator.dart';

void main() {
  final now = DateTime.utc(2026, 10, 10);
  final state = MatchState(
    id: 'ABC12345',
    mode: GameMode.classic,
    playerIds: ['alice', 'bob', 'bot_1', 'charlie'],
    protocolVersion: 1,
    serverVersion: 3,
    dealerIndex: 0,
    currentTurnIndex: 0,
  );
  test(
    'one primary request, bounded fallback if no accepted revision arrives',
    () {
      final schedulers = {
        for (final uid in ['alice', 'bob', 'charlie'])
          uid: ServerProgressCoordinator(),
      };
      bool due(String uid, int ms) => schedulers[uid]!.shouldRequest(
        state: state,
        uid: uid,
        now: now.add(Duration(milliseconds: ms)),
        due: true,
      );
      expect(due('alice', 0), true);
      expect(due('bob', 0), false);
      expect(due('charlie', 0), false);
      expect(due('bob', 1499), false);
      expect(due('bob', 1500), true);
      expect(due('charlie', 2999), false);
      expect(due('charlie', 3000), true);
    },
  );
  test('known disconnected primary is bypassed without waiting', () {
    expect(
      ServerProgressCoordinator().shouldRequest(
        state: state,
        uid: 'bob',
        now: now,
        due: true,
        presence: {'bob': true, 'charlie': true},
      ),
      true,
    );
  });
  test(
    'new revision resets fallback and waiting/nonparticipant seats never request',
    () {
      final coordinator = ServerProgressCoordinator();
      expect(
        coordinator.shouldRequest(
          state: state,
          uid: 'bob',
          now: now,
          due: true,
        ),
        false,
      );
      expect(
        coordinator.shouldRequest(
          state: state.copyWith(serverVersion: 4),
          uid: 'bob',
          now: now.add(const Duration(seconds: 2)),
          due: true,
        ),
        false,
      );
      expect(
        coordinator.shouldRequest(
          state: state,
          uid: 'stranger',
          now: now,
          due: true,
        ),
        false,
      );
      expect(
        coordinator.shouldRequest(
          state: state,
          uid: 'bot_1',
          now: now,
          due: true,
        ),
        false,
      );
      expect(
        coordinator.shouldRequest(
          state: state,
          uid: 'alice',
          now: now,
          due: false,
        ),
        false,
      );
    },
  );
}
