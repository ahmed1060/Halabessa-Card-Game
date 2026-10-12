import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/game/domain/logic/pending_server_intent.dart';

void main() {
  final state = MatchState(
    id: 'ABC12345',
    mode: GameMode.classic,
    playerIds: ['a', 'b', 'c', 'd'],
    dealerIndex: 0,
    currentTurnIndex: 1,
    protocolVersion: 1,
    serverVersion: 4,
    recentCommandIds: ['accepted'],
  );
  test(
    'exact newer receipt confirms once; unrelated revisions never unlock',
    () async {
      final ticket = PendingServerIntent(state.id, 'accepted', 3);
      expect(
        ticket.confirm(state.copyWith(recentCommandIds: ['cosmetic'])),
        false,
      );
      expect(ticket.confirm(state.copyWith(id: 'XYZ12345')), false);
      expect(ticket.confirm(state.copyWith(serverVersion: 3)), false);
      expect(ticket.confirm(state.copyWith(protocolVersion: 0)), false);
      expect(ticket.confirmed, false);
      expect(ticket.confirm(state), true);
      expect(await ticket.confirmation, true);
      expect(ticket.confirm(state.copyWith(serverVersion: 5)), false);
    },
  );
  test(
    'receipt and management fields survive model and Firebase round trips',
    () {
      final data = state.copyWith(serverProgressManaged: true).toJson();
      expect(MatchState.fromJson(data).recentCommandIds, ['accepted']);
      data['recentCommandIds'] = {'0': 'accepted'};
      expect(MatchState.fromJson(data).recentCommandIds, ['accepted']);
      expect(MatchState.fromJson(data).serverProgressManaged, true);
      data.remove('recentCommandIds');
      data.remove('serverProgressManaged');
      expect(MatchState.fromJson(data).recentCommandIds, isEmpty);
      expect(MatchState.fromJson(data).serverProgressManaged, false);
    },
  );
}
