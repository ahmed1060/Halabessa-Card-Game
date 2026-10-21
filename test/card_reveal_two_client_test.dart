import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/data/repositories/command_snapshot_stream.dart';
import 'package:halabessa/features/game/data/repositories/multiplayer_sync_service.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as game;
import 'package:halabessa/features/game/domain/models/card_feature_state.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';

// Two isolated clients exercise the actual recipient parser and revision stream.
// No cloud SDK, account, network listener or database write is initialized.
void main() {
  test(
    'two seated clients retain twelve shows through reordered delivery',
    () async {
      const seats = ['a', 'b', 'c', 'd'];
      final hands = {
        for (var i = 0; i < 4; i++)
          seats[i]: [
            for (final rank in game.Rank.values.take(4))
              game.Card(game.Suit.values[i], rank),
          ],
      };
      final initial = MatchState(
        id: 'ABC12345',
        mode: GameMode.classic,
        protocolVersion: 1,
        serverVersion: 1,
        playerIds: seats,
        phase: GamePhase.playing,
        roundCount: 1,
        matchSequence: 2,
        handInRound: 1,
        dealerIndex: 0,
        currentTurnIndex: 0,
        handCards: hands,
      );
      var revealed = initial;
      for (final uid in seats) {
        for (final card in hands[uid]!.take(3)) {
          revealed = CardFeatureState(revealed).showLocal(uid, card);
        }
      }
      revealed = revealed.copyWith(serverVersion: 13);
      MatchState recipient(MatchState state, String uid) {
        final public = state.toJson()..remove('handCards');
        public['handCounts'] = {
          for (final seat in seats) seat: hands[seat]!.length,
        };
        return MultiplayerSyncService.privateRealtimeSnapshot(
          {
            'recipientUid': uid,
            'version': state.serverVersion,
            'state': public,
            'hand': hands[uid]!.map((c) => c.toJson()).toList(),
          },
          state.id,
          uid,
        );
      }

      final public = StreamController<Map<String, dynamic>?>.broadcast();
      final own = {
        for (final uid in ['a', 'b']) uid: StreamController<MatchState?>(),
      };
      final accepted = {
        for (final uid in ['a', 'b']) uid: StreamController<MatchState>(),
      };
      final received = {
        for (final uid in ['a', 'b']) uid: <MatchState?>[],
      };
      final errors = <Object>[];
      var fetches = 0;
      final subscriptions = [
        for (final uid in ['a', 'b'])
          watchCommandSnapshots(
            notifications: public.stream,
            roomId: initial.id,
            callerUid: uid,
            privateSnapshots: own[uid]!.stream,
            acceptedSnapshots: accepted[uid]!.stream,
            initialSnapshot: recipient(initial, uid),
            fetchSnapshot: () async {
              fetches++;
              return recipient(revealed, uid);
            },
          ).listen(received[uid]!.add, onError: errors.add),
      ];
      addTearDown(() async {
        for (final sub in subscriptions) {
          await sub.cancel();
        }
        for (final stream in [...own.values, ...accepted.values]) {
          await stream.close();
        }
        await public.close();
      });
      await Future<void>.delayed(Duration.zero);
      // The peer's private view wins the race; the actor receives its command reply.
      own['b']!.add(recipient(revealed, 'b'));
      accepted['a']!.add(recipient(revealed, 'a'));
      public.add({'serverVersion': 13, 'playerIds': seats});
      await Future<void>.delayed(Duration.zero);
      // Realtime duplicates and older callbacks cannot undo accepted disclosures.
      for (final uid in ['a', 'b']) {
        own[uid]!.add(recipient(initial, uid));
        own[uid]!.add(recipient(revealed, uid));
        accepted[uid]!.add(recipient(revealed, uid));
      }
      public.add({'serverVersion': 1, 'playerIds': seats});
      await Future<void>.delayed(Duration.zero);
      expect(errors, isEmpty);
      expect(fetches, 0);
      for (final uid in ['a', 'b']) {
        expect(received[uid]!.map((s) => s!.serverVersion), [1, 13]);
        final state = received[uid]!.last!;
        expect(state.handCards.keys, [uid]);
        expect(state.handCards[uid], hands[uid]);
        expect(state.board, isEmpty, reason: 'a public show is not a play');
        expect(state.currentTurnIndex, initial.currentTurnIndex);
        expect(CardFeatureState(state).visible, hasLength(12));
        for (final seat in seats) {
          expect(CardFeatureState(state).remaining(seat), 0);
          expect(CardFeatureState(state).remaining(seat, slam: true), 3);
        }
      }
    },
  );
}
