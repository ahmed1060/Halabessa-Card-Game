import 'dart:convert';
import 'card.dart' as game;
import 'match_state.dart';

class ShownCard {
  final String ownerUid, eventId;
  final game.Card card;
  const ShownCard(this.ownerUid, this.eventId, this.card);
}

/// Presentation metadata: no move/score/capture calculation lives here.
class CardFeatureState {
  final MatchState state;
  CardFeatureState(this.state);
  String get scope => '${state.matchSequence}:${state.roundCount}';
  Map<String, dynamic> get data => state.cardFeatures['scope'] == scope
      ? state.cardFeatures
      : {'scope': scope, 'players': <String, dynamic>{}};
  Map _usage(String uid) =>
      (data['players'] is Map ? data['players'][uid] : null) is Map
      ? data['players'][uid] as Map
      : const {};
  int remaining(String uid, {bool slam = false}) {
    final count = _usage(uid)[slam ? 'slams' : 'shows'];
    return (3 - (count is num ? count.toInt() : 0)).clamp(0, 3);
  }

  Iterable<Map> _items(dynamic value) =>
      (value is Map
              ? value.values
              : value is List
              ? value
              : const [])
          .whereType<Map>();
  List<ShownCard> get visible {
    if (state.phase != GamePhase.playing && state.phase != GamePhase.capturing) {
      return const [];
    }
    final result = <ShownCard>[];
    for (final uid in state.playerIds) {
      for (final item in _items(_usage(uid)['shown']).take(3)) {
        if (item['hand'] != state.handInRound ||
            item['card'] is! Map ||
            item['eventId'] is! String) {
          continue;
        }
        if (!game.Suit.values.any((s) => s.name == item['card']['suit']) ||
            !game.Rank.values.any((r) => r.name == item['card']['rank'])) {
          continue;
        }
        final card = game.Card.fromJson(
          Map<String, dynamic>.from(item['card']),
        );
        if (state.handCards.containsKey(uid) &&
            !state.handCards[uid]!.contains(card)) {
          continue;
        }
        result.add(ShownCard(uid, item['eventId'] as String, card));
      }
    }
    return result;
  }

  Map<String, dynamic> _copy() =>
      jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
  Map<String, dynamic> _own(Map<String, dynamic> next, String uid) {
    final players = next['players'] as Map<String, dynamic>;
    return players.putIfAbsent(
          uid,
          () => <String, dynamic>{'shows': 0, 'slams': 0, 'shown': []},
        )
        as Map<String, dynamic>;
  }

  void _assertOwned(String uid, game.Card card) {
    if (!state.playerIds.contains(uid) ||
        state.roomClosed ||
        state.phase != GamePhase.playing ||
        !(state.handCards[uid]?.contains(card) ?? false)) {
      throw StateError('card_not_owned');
    }
  }

  MatchState showLocal(String uid, game.Card card) {
    _assertOwned(uid, card);
    if (visible.any((item) => item.ownerUid == uid && item.card == card)) {
      return state;
    }
    if (remaining(uid) == 0) throw StateError('reveal_limit_reached');
    final next = _copy(), own = _own(next, uid);
    final count = own['shows'] = (own['shows'] as num).toInt() + 1;
    final list = own['shown'];
    own['shown'] = [
      if (list is List) ...list,
      if (list is Map) ...list.values,
      {
        'card': card.toJson(),
        'hand': state.handInRound,
        'eventId': '$scope:$uid:show:$count',
      },
    ];
    return state.copyWith(cardFeatures: next);
  }

  MatchState acceptedLocalSlam(
    MatchState accepted,
    String uid,
    game.Card card,
  ) {
    _assertOwned(uid, card);
    if (remaining(uid, slam: true) == 0) throw StateError('slam_limit_reached');
    final next = _copy(), own = _own(next, uid);
    final count = own['slams'] = (own['slams'] as num).toInt() + 1;
    next['lastSlam'] = {
      'cardId': card.firebaseKey,
      'ownerUid': uid,
      'eventId': '$scope:$uid:slam:$count',
    };
    return accepted.copyWith(cardFeatures: next);
  }

  bool wasGestureSlam(game.Card card) =>
      data['lastSlam'] is Map && data['lastSlam']['cardId'] == card.firebaseKey;
}
