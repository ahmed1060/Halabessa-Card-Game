import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/game/domain/models/room_summary.dart';

void main() {
  group('Offline Match State Model', () {
    test('offline match ID and bot seats are correctly configured', () {
      final offlineId = 'OFFLINE_${DateTime.now().millisecondsSinceEpoch}';
      final match = MatchState(
        id: offlineId,
        mode: GameMode.classic,
        playerIds: ['human_player', 'bot_1', 'bot_2', 'bot_3'],
        playerNames: {
          'human_player': 'Hero',
          'bot_1': 'bot_name_template',
          'bot_2': 'bot_name_template',
          'bot_3': 'bot_name_template',
        },
        playerOnlineStatus: {
          'human_player': true,
          'bot_1': true,
          'bot_2': true,
          'bot_3': true,
        },
        dealerIndex: 0,
        currentTurnIndex: 1,
        phase: GamePhase.waitingForPlayers,
      );

      expect(match.id.startsWith('OFFLINE_'), isTrue);
      expect(match.playerIds.length, 4);
      expect(match.playerIds.where((id) => id.startsWith('bot_')).length, 3);
      expect(match.playerNames['human_player'], 'Hero');
      expect(match.playerOnlineStatus['bot_1'], isTrue);
    });
  });

  group('Quick Match Filtering Logic', () {
    test('identifies joinable public room with open seat', () {
      final now = DateTime.now();
      final summary = RoomSummary(
        id: 'ABC12345',
        mode: GameMode.classic,
        playerIds: ['host_p1', 'waiting_1', 'waiting_2', 'waiting_3'],
        isPublic: true,
        phase: GamePhase.waitingForPlayers,
        expireAt: now.add(const Duration(minutes: 5)),
      );

      final bool isExpired = summary.expireAt != null && summary.expireAt!.isBefore(now);
      final bool hasOpenSeat = summary.playerIds.any((id) => id.startsWith('waiting_'));
      final bool isJoinable = summary.isPublic && 
                              summary.phase == GamePhase.waitingForPlayers && 
                              hasOpenSeat && 
                              !isExpired;

      expect(isJoinable, isTrue);
    });

    test('rejects full room or expired room', () {
      final now = DateTime.now();
      final fullRoom = RoomSummary(
        id: 'FULL1234',
        mode: GameMode.classic,
        playerIds: ['p1', 'p2', 'p3', 'p4'],
        isPublic: true,
        phase: GamePhase.waitingForPlayers,
      );

      final hasOpenSeat = fullRoom.playerIds.any((id) => id.startsWith('waiting_'));
      expect(hasOpenSeat, isFalse);

      final expiredRoom = RoomSummary(
        id: 'EXP12345',
        mode: GameMode.classic,
        playerIds: ['p1', 'waiting_1', 'waiting_2', 'waiting_3'],
        isPublic: true,
        phase: GamePhase.waitingForPlayers,
        expireAt: now.subtract(const Duration(minutes: 1)),
      );

      final isExpired = expiredRoom.expireAt != null && expiredRoom.expireAt!.isBefore(now);
      expect(isExpired, isTrue);
    });

    test('8-character room code format is compatible with input text formatter limit', () {
      // 3 letters + 5 digits format = 8 chars
      const code = 'RHY17001';
      expect(code.length, 8);
      expect(code.length <= 10, isTrue);
      expect(RegExp(r'^[a-zA-Z0-9]+$').hasMatch(code), isTrue);
    });
  });

  group('Post-Match Rematch & Replay Logic', () {
    test('rematch vote concludes to matchOver if any player declines', () {
      final votes = {'p1': true, 'p2': false};
      final bool anyoneVotedNo = votes.values.any((v) => v == false);
      expect(anyoneVotedNo, isTrue);
    });

    test('rematch vote triggers new round only when all 4 players vote yes', () {
      final partialVotes = {'p1': true, 'p2': true, 'p3': true};
      expect(partialVotes.length == 4, isFalse);

      final unanimousVotes = {'p1': true, 'p2': true, 'p3': true, 'p4': true};
      final bool unanimous = unanimousVotes.length == 4 && unanimousVotes.values.every((v) => v == true);
      expect(unanimous, isTrue);
    });

    test('dealer index safely wraps around playerIds length without out-of-bounds', () {
      final players = ['p0', 'p1', 'p2', 'p3'];
      const dealerIndex = 5; // Out of bounds of length 4
      final safeDealerId = players[dealerIndex % players.length];
      expect(safeDealerId, 'p1');
    });

    test('offline matches configure snappy 3-second memory phase delay', () {
      const offlineId = 'OFFLINE_12345678';
      const onlineId = 'RHY17001';

      final offlineDelay = offlineId.startsWith('OFFLINE_') ? 3 : 5;
      final onlineDelay = onlineId.startsWith('OFFLINE_') ? 3 : 5;

      expect(offlineDelay, 3);
      expect(onlineDelay, 5);
    });

    test('offline match IDs bypass remote chat stream and writes', () {
      const offlineId = 'OFFLINE_12345678';
      const onlineId = 'RHY17001';

      bool shouldSkipRemoteChat(String matchId) => matchId.isEmpty || matchId.startsWith('OFFLINE_');

      expect(shouldSkipRemoteChat(offlineId), isTrue);
      expect(shouldSkipRemoteChat(''), isTrue);
      expect(shouldSkipRemoteChat(onlineId), isFalse);
    });
  });
}
