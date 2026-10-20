import 'package:flutter_test/flutter_test.dart';
// Reuse the deterministic clock already supplied by Flutter's test SDK.
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/game/presentation/providers/unity_visual_presentation.dart';

final time = DateTime.utc(2026, 10, 14);
MatchState state(
  int version, {
  bool play = false,
  bool capture = false,
  int round = 1,
}) => MatchState.fromJson({
  'id': 'TEST1234',
  'protocolVersion': 1,
  'serverVersion': version,
  'playerIds': ['a', 'b', 'c', 'd'],
  'phase': 'playing',
  'roundCount': round,
  'handCards': {
    'a': [
      {'rank': 'six', 'suit': 'clubs'},
    ],
    'b': [
      {'rank': 'king', 'suit': 'hearts'},
    ],
  },
  'board': play
      ? [
          {'rank': 'two', 'suit': 'diamonds'},
        ]
      : [],
  'cardOwnership': {'diamonds_two': 'b'},
  'captureEvents': capture
      ? [
          {
            'id': 'cap1',
            'team': 'teamA',
            'playerUid': 'a',
            'createdAt': time.toIso8601String(),
            'cards': [
              {'rank': 'six', 'suit': 'hearts'},
              {'rank': 'six', 'suit': 'clubs'},
            ],
          },
        ]
      : [],
});
void main() {
  test(
    'invalid-return and anchor updates are cosmetic, private and generation fenced',
    () {
      fakeAsync((_) {
        final sent = <Map<String, dynamic>>[];
        final renderer = UnityVisualPresentation(
          send: sent.add,
          onContact: (_, __) {},
        );
        renderer.accept(state(1), 'a', active: true, reduced: false);
        renderer.negotiate(1);
        final generation = renderer.generation;
        renderer.updateAnchors([
          {'name': 'deck', 'x': .2, 'y': .3},
        ]);
        expect(sent.last['anchors'], [
          {'name': 'deck', 'x': .2, 'y': .3},
        ]);
        final count = sent.length;
        renderer.updateAnchors([
          {'name': 'deck', 'x': .2, 'y': .3, 'width': .1, 'height': .15},
        ]);
        expect(
          sent.length,
          count + 1,
          reason: 'size-only resize updates native hit geometry',
        );
        renderer.updateAnchors([
          {'name': 'deck', 'x': .2, 'y': .3, 'width': .1, 'height': .15},
        ]);
        expect(
          sent.length,
          count + 1,
          reason: 'identical size does not restart layout',
        );
        expect(renderer.reject('clubs_six', generation - 1), isFalse);
        expect(renderer.reject('hearts_king', generation), isFalse);
        expect(renderer.reject('clubs_six', generation), isTrue);
        expect(sent.last['type'], 'INVALID_MOVE');
        renderer.accept(state(1), 'a', active: false, reduced: false);
        expect(renderer.reject('clubs_six', generation), isFalse);
        renderer.dispose();
      });
    },
  );
  test('legacy renderer gets snapshots and only the local private hand', () {
    fakeAsync((_) {
      final sent = <Map<String, dynamic>>[];
      final renderer = UnityVisualPresentation(
        send: sent.add,
        onContact: (_, __) {},
        now: () => time,
      );
      renderer.accept(state(1), 'a', active: true, reduced: false);
      expect(renderer.capable, isFalse);
      expect(sent.last['type'], 'SYNC_STATE');
      expect(sent.last['handCards'], [
        {'suit': 'clubs', 'rank': 'six'},
      ]);
      expect(sent.last.containsKey('playerHands'), isFalse);
      renderer.dispose();
    });
  });
  test('capture waits for visual ACK, never sends a play/advance command', () {
    fakeAsync((_) {
      final sent = <Map<String, dynamic>>[], contacts = <String>[];
      final renderer = UnityVisualPresentation(
        send: sent.add,
        onContact: (id, _) => contacts.add(id),
        now: () => time,
      );
      renderer.accept(state(1), 'a', active: true, reduced: false);
      renderer.negotiate(1);
      renderer.accept(
        state(2, capture: true),
        'a',
        active: true,
        reduced: false,
      );
      final action = sent.last;
      expect(action['type'], 'VISUAL_ACTION');
      expect(action['kind'], 'CardsCollected');
      expect(action['durationMs'], 1400);
      final id = action['eventId'] as String,
          generation = action['generation'] as int;
      expect(renderer.contact(id, generation - 1), isFalse);
      expect(renderer.contact(id, generation), isTrue);
      expect(renderer.contact(id, generation), isFalse);
      expect(contacts, [id]);
      expect(renderer.acknowledge('unknown', generation), isFalse);
      expect(renderer.acknowledge(id, generation), isTrue);
      expect(renderer.acknowledge(id, generation), isFalse);
      renderer.accept(
        state(3, capture: true),
        'a',
        active: true,
        reduced: false,
      );
      expect(sent.where((m) => m['kind'] == 'CardsCollected'), hasLength(1));
      expect(
        sent.any((m) => m['type'] == 'playCard' || m['type'] == 'advance'),
        isFalse,
      );
      renderer.dispose();
    });
  });
  test(
    'timeout, reconnect and old round ACKs cannot stall play or replay captures',
    () {
      fakeAsync((clock) {
        final sent = <Map<String, dynamic>>[];
        final renderer = UnityVisualPresentation(
          send: sent.add,
          onContact: (_, __) {},
          now: () => time,
        );
        renderer.accept(state(1), 'a', active: true, reduced: false);
        renderer.negotiate(1);
        renderer.accept(
          state(2, capture: true),
          'a',
          active: true,
          reduced: false,
        );
        final action = sent.last;
        clock.elapse(const Duration(milliseconds: 1750));
        expect(renderer.capable, isFalse);
        expect(sent.last['type'], 'SYNC_STATE');
        expect(
          sent.last['instant'],
          isTrue,
          reason: 'watchdog fallback must keep negotiated screen-space layout',
        );
        renderer.updateAnchors([
          {'name': 'hand', 'x': .7, 'y': .9, 'width': .18, 'height': .14},
        ]);
        expect(sent.last['anchors'], [
          {'name': 'hand', 'x': .7, 'y': .9, 'width': .18, 'height': .14},
        ]);
        expect(sent.last['instant'], isTrue);
        expect(
          renderer.acknowledge(action['eventId'], action['generation']),
          isFalse,
        );
        renderer.negotiate(1);
        renderer.accept(
          state(3, capture: true),
          'a',
          active: true,
          reduced: false,
        );
        expect(sent.where((m) => m['kind'] == 'CardsCollected'), hasLength(1));
        renderer.accept(state(1, round: 2), 'a', active: true, reduced: false);
        expect(sent.last['type'], 'SYNC_STATE');
        renderer.dispose();
      });
    },
  );
  test('cut reveal never duplicates previous-round native table artwork', () {
    fakeAsync((_) {
      final sent = <Map<String, dynamic>>[];
      final renderer = UnityVisualPresentation(
        send: sent.add,
        onContact: (_, __) {},
      );
      renderer.negotiate(1);
      for (final phase in [GamePhase.preRoundCut, GamePhase.dealingFasha]) {
        final original = state(1, play: true).copyWith(phase: phase);
        renderer.accept(original, 'a', active: true, reduced: false);
        expect(sent.last['board'], isEmpty);
        expect(original.board, hasLength(1), reason: 'domain is not mutated');
      }
      renderer.dispose();
    });
  });
  test(
    'normal plays are ordered and renderer switches skip stale visual work',
    () {
      fakeAsync((_) {
        final sent = <Map<String, dynamic>>[];
        final renderer = UnityVisualPresentation(
          send: sent.add,
          onContact: (_, __) {},
          now: () => time,
        );
        renderer.accept(state(1), 'a', active: true, reduced: false);
        renderer.negotiate(1);
        renderer.accept(
          state(2, play: true),
          'a',
          active: true,
          reduced: false,
        );
        expect(sent.last['kind'], 'CardPlayed');
        expect(sent.last['actor'], 1);
        final action = sent.last;
        renderer.accept(
          state(2, play: true),
          'a',
          active: false,
          reduced: false,
        );
        expect(
          renderer.contact(action['eventId'], action['generation']),
          isFalse,
        );
        renderer.accept(state(2, play: true), 'a', active: true, reduced: true);
        expect(sent.last['type'], 'SYNC_STATE');
        renderer.dispose();
      });
    },
  );
}
