import 'package:flutter_test/flutter_test.dart';
// Reuse the deterministic clock already supplied by Flutter's test SDK.
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as game;
import 'package:halabessa/features/game/presentation/providers/unity_visual_presentation.dart';
import 'package:halabessa/features/game/presentation/widgets/hand_card_placement.dart';

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
    'fresh four-card anchors are applied with the deal, not an old two-card snapshot',
    () {
      fakeAsync((_) {
        final sent = <Map<String, dynamic>>[];
        final renderer = UnityVisualPresentation(
          send: sent.add,
          onContact: (_, __) {},
        );
        final initial = state(1);
        renderer.accept(initial, 'a', active: true, reduced: false);
        renderer.negotiate(1);
        final before = sent.length;
        final anchors = [
          for (var i = 0; i < 4; i++)
            {
              'name': 'hand$i',
              'x': .3 + i * .13,
              'y': .85,
              'width': .1,
              'height': .14,
            },
        ];
        renderer.updateAnchors(anchors, reconcile: false);
        expect(
          sent.length,
          before,
          reason: 'pending layout must not reposition the old hand first',
        );
        final next = initial.copyWith(
          serverVersion: 2,
          handCards: {
            'a': [
              ...initial.handCards['a']!,
              const game.Card(game.Suit.hearts, game.Rank.nine),
              const game.Card(game.Suit.spades, game.Rank.king),
              const game.Card(game.Suit.diamonds, game.Rank.ten),
            ],
          },
        );
        renderer.accept(next, 'a', active: true, reduced: false);
        expect(sent.last['kind'], 'CardDrawn');
        expect(sent.last['anchors'], anchors);
        expect(sent.last['handCards'], hasLength(4));
        renderer.dispose();
      });
    },
  );
  test(
    'a missed animation ACK must not permanently disable later Unity effects',
    () {
      fakeAsync((clock) {
        final sent = <Map<String, dynamic>>[];
        final renderer = UnityVisualPresentation(
          send: sent.add,
          onContact: (_, __) {},
          now: () => time,
        );
        renderer.accept(
          state(1),
          'a',
          active: true,
          reduced: false,
          interactions: true,
        );
        renderer.negotiate(1, interactions: true);
        renderer.updateHandSelection('clubs_six', true, true);
        renderer.accept(
          state(2, capture: true),
          'a',
          active: true,
          reduced: false,
          interactions: true,
        );
        final stalled = sent.lastWhere((m) => m['type'] == 'VISUAL_ACTION');
        clock.elapse(const Duration(milliseconds: 1750));
        expect(sent.last['type'], 'SYNC_STATE');
        expect(sent.last['instant'], true);
        expect(
          renderer.capable,
          true,
          reason:
              'one slow/missing ACK must not switch off all remaining spices',
        );
        expect(renderer.interactionsCapable, true);
        expect(
          renderer.acknowledge(stalled['eventId'], stalled['generation']),
          false,
        );
        renderer.accept(
          state(3, play: true, capture: true),
          'a',
          active: true,
          reduced: false,
          interactions: true,
        );
        final next = sent.lastWhere((m) => m['type'] == 'VISUAL_ACTION');
        expect(next['kind'], 'CardPlayed');
        expect(next['generation'], greaterThan(stalled['generation']));
        expect(
          renderer.contact(stalled['eventId'], stalled['generation']),
          false,
        );
        expect(renderer.acknowledge(next['eventId'], next['generation']), true);
        expect(sent.where((m) => m['kind'] == 'CardsCollected'), hasLength(1));
        expect(sent.last['handSelections'], [
          {'cardId': 'clubs_six', 'queued': true, 'slam': true},
        ]);
        renderer.dispose();
      });
    },
  );
  test(
    'private selection survives hover-independent snapshots, cancels, and never reaches legacy builds',
    () {
      fakeAsync((_) {
        final sent = <Map<String, dynamic>>[];
        final renderer = UnityVisualPresentation(
          send: sent.add,
          onContact: (_, __) {},
        );
        renderer.accept(state(1), 'a', active: true, reduced: false);
        renderer.negotiate(1);
        renderer.updateHandSelection('clubs_six', true, true);
        expect(sent.last.containsKey('handSelections'), isFalse);
        renderer.negotiate(1, interactions: true);
        renderer.updateHandSelection('hearts_king', true, true);
        expect(
          sent.last['type'],
          'SYNC_STATE',
          reason: 'opponent selection is not permitted',
        );
        renderer.updateHandSelection('clubs_six', true, true);
        expect(sent.last['type'], 'HAND_SELECTION');
        final count = sent.length;
        renderer.updateHandSelection('clubs_six', true, true);
        expect(sent.length, count);
        renderer.accept(state(2), 'a', active: true, reduced: false);
        expect(sent.last['handSelections'], [
          {'cardId': 'clubs_six', 'queued': true, 'slam': true},
        ]);
        renderer.accept(
          state(3, play: true),
          'a',
          active: true,
          reduced: false,
        );
        expect(
          sent.last['type'],
          'HAND_SELECTION',
          reason: 'opponent flight must not erase private cue',
        );
        expect(sent.last['cardId'], 'clubs_six');
        renderer.updateHandSelection('clubs_six', false, false);
        renderer.resync();
        expect(sent.last['handSelections'], isEmpty);
        renderer.updateHandSelection('clubs_six', true, false);
        renderer.accept(state(4, round: 2), 'a', active: true, reduced: false);
        expect(sent.last['handSelections'], isEmpty);
        renderer.dispose();
      });
    },
  );
  MatchState slamState(int version, {bool capture = false}) =>
      state(version, play: true, capture: capture).copyWith(
        cardFeatures: {
          'scope': '${state(1).matchSequence}:1',
          'lastSlam': {
            'cardId': capture ? 'clubs_six' : 'diamonds_two',
            'eventId': 'slam1',
          },
        },
      );
  test(
    'gesture slam is optional, accepted-state-only, and contacts exactly once',
    () {
      fakeAsync((_) {
        final sent = <Map<String, dynamic>>[], sound = <String>[];
        final renderer = UnityVisualPresentation(
          send: sent.add,
          onContact: (_, __) => sound.add('ordinary'),
          onGestureContact: sound.add,
        );
        renderer.accept(
          state(1),
          'a',
          active: true,
          reduced: false,
          interactions: true,
        );
        renderer.negotiate(1, interactions: true);
        final next = slamState(2);
        renderer.accept(
          next,
          'a',
          active: true,
          reduced: false,
          interactions: true,
        );
        final action = sent.last;
        expect(action['kind'], 'CardPlayed');
        expect(action['deliveryStyle'], 'slam');
        expect(action['durationMs'], cardUiRefinements ? 500 : 470);
        expect(
          renderer.contact(action['eventId'], renderer.generation),
          isTrue,
        );
        expect(
          renderer.contact(action['eventId'], renderer.generation),
          isFalse,
        );
        expect(sound, ['slam1']);
        renderer.acknowledge(action['eventId'], renderer.generation);
        renderer.accept(
          next.copyWith(serverVersion: 3),
          'a',
          active: true,
          reduced: false,
          interactions: true,
        );
        expect(sent.where((m) => m['deliveryStyle'] == 'slam'), hasLength(1));
        renderer.dispose();
      });
    },
  );
  test('old Unity capability cannot enable gesture delivery', () {
    fakeAsync((_) {
      final sent = <Map<String, dynamic>>[];
      final renderer = UnityVisualPresentation(
        send: sent.add,
        onContact: (_, __) {},
      );
      renderer.accept(state(1), 'a', active: true, reduced: false);
      renderer.negotiate(1);
      renderer.accept(
        slamState(2),
        'a',
        active: true,
        reduced: false,
        interactions: true,
      );
      expect(sent.last['deliveryStyle'], isNull);
      expect(sent.last['durationMs'], 350);
      renderer.dispose();
    });
  });
  test(
    'slam capture celebration is distinct and cancelled by renderer resync',
    () {
      fakeAsync((clock) {
        final sent = <Map<String, dynamic>>[], contacts = <String>[];
        final renderer = UnityVisualPresentation(
          send: sent.add,
          onContact: (id, _) => contacts.add(id),
          onGestureContact: contacts.add,
          now: () => time,
        );
        renderer.accept(
          state(1),
          'a',
          active: true,
          reduced: false,
          interactions: true,
        );
        renderer.negotiate(1, interactions: true);
        renderer.accept(
          slamState(2, capture: true),
          'a',
          active: true,
          reduced: false,
          interactions: true,
        );
        expect(sent.last['kind'], 'CardsCollected');
        expect(sent.last['deliveryStyle'], 'slam');
        renderer.contact(sent.last['eventId'], renderer.generation);
        expect(contacts, ['slam1']);
        clock.elapse(const Duration(milliseconds: 159));
        expect(contacts, ['slam1']);
        renderer.resync();
        clock.elapse(const Duration(milliseconds: 20));
        expect(contacts, [
          'slam1',
        ], reason: 'resync cancels delayed celebration audio');
        renderer.dispose();
      });
    },
  );
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
        expect(
          renderer.capable,
          isTrue,
          reason: 'watchdog skips stale work, not the rest of the session',
        );
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
