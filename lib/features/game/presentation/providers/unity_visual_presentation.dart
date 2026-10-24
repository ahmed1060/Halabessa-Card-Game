import 'dart:async';
import '../../domain/models/card_feature_state.dart';
import '../../domain/models/match_state.dart';
import 'visual_action_queue.dart';
import '../widgets/hand_card_placement.dart';

/// Optional protocol extension. Old Unity builds continue consuming SYNC_STATE.
/// This class observes accepted state; it can emit only visual messages.
class UnityVisualPresentation {
  final void Function(Map<String, dynamic>) send;
  final void Function(String id, bool slam) onContact;
  final void Function(String id)? onGestureContact;
  final DateTime Function() now;
  final void Function()? onRecoverableTimeout;
  late final VisualActionQueue<Map<String, dynamic>> _queue;
  MatchState? _previous, _latest;
  String? _uid;
  String _scope = '';
  String? _contacted;
  bool _capable = false, _active = false, _reduced = false;
  // A missed ACK cancels one visual sequence, not the negotiated renderer or
  // coordinate system. Future accepted actions must still get native motion.
  bool _managedLayout = false;
  bool _interactionsCapable = false, _interactionPreview = false;
  final _selections = <String, Map<String, dynamic>>{};
  final _poses = <String, Map<String, dynamic>>{};
  bool _refinedCapable = false;
  Timer? _captureContact;
  final _seenCaptures = <String>{};
  List<Map<String, dynamic>> anchors = const [];
  bool get capable => _capable;
  bool get refinedCapable => _capable && _refinedCapable;
  bool get interactionsCapable => _capable && _interactionsCapable;
  int get generation => _queue.generation;
  UnityVisualPresentation({
    required this.send,
    required this.onContact,
    this.onGestureContact,
    this.onRecoverableTimeout,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now {
    _queue = VisualActionQueue(
      allowance: const Duration(milliseconds: 350),
      onStart: (action) {
        send({...action.value, 'generation': generation});
        // Starting native flight cancels transient poses. Restore only the
        // still-owned local selection, not an opponent's hand or a play intent.
        if (interactionsCapable) {
          for (final pose in _selections.values) {
            send({'type': 'HAND_SELECTION', 'generation': generation, ...pose});
          }
          for (final pose in _poses.values) {
            send({'type': 'HAND_POSE', 'generation': generation, ...pose});
          }
        }
      },
      onFinish: (_, timedOut) {
        if (timedOut) {
          // Bound the stale sequence, reconcile in the SAME layout space, and
          // leave the negotiated capability intact. A slow/dropped ACK is not
          // proof that Unity is unavailable for the rest of this game.
          resync();
          onRecoverableTimeout?.call();
        } else if (_queue.pendingCount == 0 && _latest != null) {
          send(_snapshot(_latest!));
        }
      },
      onOverflow: resync,
    );
  }

  void negotiate(
    int protocol, {
    bool interactions = false,
    bool refinedHand = false,
  }) {
    if (protocol != 1 || !cardJuiceEnabled) return;
    _capable = true;
    _managedLayout = true;
    _interactionsCapable = interactions;
    _refinedCapable = refinedHand;
    resync();
  }

  void updateHandPose(String cardId, bool peek, double drag, double velocity) {
    if (!refinedCapable ||
        !_active ||
        !(_latest?.handCards[_uid] ?? []).any((c) => c.firebaseKey == cardId))
      return;
    final pose = {
      'cardId': cardId,
      'peek': peek,
      'dragFraction': drag,
      'velocity': velocity,
    };
    _poses[cardId] = pose;
    send({'type': 'HAND_POSE', 'generation': generation, ...pose});
  }

  /// Private renderer state only. Never includes an opponent's selection.
  void updateHandSelection(String cardId, bool queued, bool slam) {
    if (!interactionsCapable ||
        !_active ||
        !(_latest?.handCards[_uid] ?? []).any((c) => c.firebaseKey == cardId)) {
      return;
    }
    final previous = _selections[cardId];
    if (previous?['queued'] == queued && previous?['slam'] == slam) return;
    if (!queued && !slam && previous == null) return;
    final pose = {'cardId': cardId, 'queued': queued, 'slam': slam};
    if (queued || slam) {
      _selections[cardId] = pose;
    } else {
      _selections.remove(cardId);
    }
    send({'type': 'HAND_SELECTION', 'generation': generation, ...pose});
  }

  Map<String, dynamic> _snapshot(MatchState state) => {
    'type': 'SYNC_STATE',
    'instant': _managedLayout,
    if (refinedCapable && cardUiRefinements) 'refinedHand': true,
    if (refinedCapable && cardUiRefinements)
      'publicHandIds': CardFeatureState(state).visible
          .where((c) => _interactionPreview && c.ownerUid == _uid)
          .map((c) => c.card.firebaseKey)
          .toList(),
    if (refinedCapable && cardUiRefinements)
      'handPoses': _poses.values.toList(),
    // The cut reveal belongs to Flutter. Previous-round cards can remain in
    // authoritative state until the deal, but must not leak into this reveal.
    'board': switch (state.phase) {
      GamePhase.waitingForPlayers ||
      GamePhase.preRoundCut ||
      GamePhase.dealingFasha => <Map<String, dynamic>>[],
      _ => state.board.map((c) => c.toJson()).toList(),
    },
    'handCards': (state.handCards[_uid] ?? []).map((c) => c.toJson()).toList(),
    'phase': state.phase.name,
    'turnIndex': state.currentTurnIndex,
    'reducedMotion': _reduced,
    'anchors': anchors,
    if (interactionsCapable) 'handSelections': _selections.values.toList(),
  };

  void updateAnchors(List<Map<String, dynamic>> next, {bool reconcile = true}) {
    final unchanged =
        next.length == anchors.length &&
        List.generate(next.length, (i) => i).every(
          (i) =>
              next[i]['name'] == anchors[i]['name'] &&
              next[i]['x'] == anchors[i]['x'] &&
              next[i]['y'] == anchors[i]['y'] &&
              next[i]['width'] == anchors[i]['width'] &&
              next[i]['height'] == anchors[i]['height'],
        );
    anchors = next;
    if (reconcile &&
        !unchanged &&
        _managedLayout &&
        _active &&
        _queue.active == null &&
        _latest != null) {
      send(_snapshot(_latest!));
    }
  }

  bool reject(String cardId, int generation) {
    if (!_capable ||
        !_active ||
        generation != this.generation ||
        !(_latest?.handCards[_uid] ?? []).any((c) => c.firebaseKey == cardId)) {
      return false;
    }
    send({
      'type': 'INVALID_MOVE',
      'cardId': cardId,
      'generation': generation,
      'reducedMotion': _reduced,
    });
    return true;
  }

  void resync() {
    _captureContact?.cancel();
    _queue.reset();
    _contacted = null;
    send({'type': 'CANCEL_VISUALS', 'generation': generation});
    final state = _latest;
    if (state != null) {
      _previous = state;
      _seenCaptures.clear();
      _seenCaptures.addAll(state.captureEvents.map((c) => c.id));
      send(_snapshot(state));
    }
  }

  void accept(
    MatchState state,
    String? uid, {
    required bool active,
    required bool reduced,
    bool interactions = false,
  }) {
    final scope = '${state.id}:${state.matchSequence}:${state.roundCount}:$uid';
    final old = _previous;
    if (old != null &&
        scope == _scope &&
        state.serverVersion < old.serverVersion) {
      return;
    }
    _latest = state;
    _uid = uid;
    _interactionPreview = interactions;
    if (scope != _scope || !active) _selections.clear();
    if (scope != _scope || !active) _poses.clear();
    _poses.removeWhere(
      (id, _) => !(state.handCards[uid] ?? []).any((c) => c.firebaseKey == id),
    );
    _selections.removeWhere(
      (id, _) => !(state.handCards[uid] ?? []).any((c) => c.firebaseKey == id),
    );
    final lastSlam = CardFeatureState(state).data['lastSlam'];
    final oldSlam = old == null ? null : CardFeatureState(old).data['lastSlam'];
    final gestureId =
        interactionsCapable &&
            _interactionPreview &&
            lastSlam is Map &&
            lastSlam['eventId'] is String &&
            (oldSlam is! Map || oldSlam['eventId'] != lastSlam['eventId'])
        ? lastSlam['eventId'] as String
        : '';
    String slamFor(List<Map<String, dynamic>> cards) =>
        gestureId.isNotEmpty &&
            cards.isNotEmpty &&
            '${cards.last['suit']}_${cards.last['rank']}' == lastSlam['cardId']
        ? gestureId
        : '';
    final reset = scope != _scope || active != _active || reduced != _reduced;
    _scope = scope;
    _active = active;
    _reduced = reduced;
    if (!_capable || !active || reset || old == null) {
      resync();
      return;
    }
    if (state.serverVersion < old.serverVersion) return;
    _previous = state;
    final captures = state.captureEvents
        .where((e) => _seenCaptures.add(e.id))
        .toList();
    if (captures.length > 1 ||
        captures.any(
          (e) => now().difference(e.createdAt).inMilliseconds >= 2000,
        )) {
      resync();
      return; // Catch up, don't invent missed theatrical history.
    }
    if (captures.isNotEmpty) {
      final e = captures.single;
      _add(
        'capture:${e.id}',
        'CardsCollected',
        state,
        cards: e.cards.map((c) => c.toJson()).toList(),
        team: e.team,
        actor: state.playerIds.indexOf(e.playerUid),
        duration: 1400,
        gestureId: slamFor(e.cards.map((c) => c.toJson()).toList()),
      );
      return;
    }
    // Practice/legacy capture phases already include their own authoritative
    // reading hold. Do not add a second full collection wait.
    if (state.phase == GamePhase.capturing) {
      if (old.phase != GamePhase.capturing) {
        _add(
          'capture:${state.board.map((c) => c.firebaseKey).join(',')}',
          'CardSlammed',
          state,
          cards: state.board.map((c) => c.toJson()).toList(),
          team: state.capturingTeam ?? '',
          duration: gestureId.isEmpty
              ? 220
              : cardUiRefinements
              ? 500
              : 470,
          gestureId: slamFor(state.board.map((c) => c.toJson()).toList()),
        );
      }
      return;
    }
    final newBoard = state.board.where((c) => !old.board.contains(c)).toList();
    if (old.phase == GamePhase.playing &&
        state.phase == GamePhase.playing &&
        newBoard.length == 1) {
      final c = newBoard.single;
      _add(
        'play:${c.firebaseKey}',
        'CardPlayed',
        state,
        cards: [c.toJson()],
        actor: state.playerIds.indexOf(
          state.cardOwnership[c.firebaseKey] ?? '',
        ),
        duration: gestureId.isEmpty
            ? 350
            : cardUiRefinements
            ? 500
            : 470,
        gestureId: slamFor([c.toJson()]),
      );
    } else if ((state.handCards[uid]?.length ?? 0) >
        (old.handCards[uid]?.length ?? 0)) {
      _add('deal:${state.handInRound}', 'CardDrawn', state, duration: 600);
    } else if (state.phase == GamePhase.matchOver &&
        old.phase != GamePhase.matchOver) {
      _add('win:${state.serverVersion}', 'RoundWon', state, duration: 350);
    } else if (_queue.active == null) {
      send(_snapshot(state));
    }
  }

  void _add(
    String id,
    String kind,
    MatchState state, {
    List<Map<String, dynamic>> cards = const [],
    String team = '',
    int actor = -1,
    required int duration,
    String gestureId = '',
  }) {
    final base = state.playerIds.indexOf(_uid ?? '');
    final relativeActor = actor < 0
        ? 2
        : (actor - (base < 0 ? 0 : base) + 4) % 4;
    _queue.add(
      VisualAction('$_scope:$id', {
        ..._snapshot(state),
        'type': 'VISUAL_ACTION',
        'protocol': 1,
        'eventId': '$_scope:$id',
        'roomId': state.id,
        'matchSequence': state.matchSequence,
        'round': state.roundCount,
        'stateRevision': state.serverVersion,
        'kind': kind,
        if (gestureId.isNotEmpty) 'gestureEventId': gestureId,
        if (gestureId.isNotEmpty) 'deliveryStyle': 'slam',
        'cards': cards,
        'actor': relativeActor,
        'team': team,
        'ownTeam': base >= 0 ? (base.isEven ? 'teamA' : 'teamB') : 'teamA',
        'durationMs': _reduced ? 0 : duration,
        'reducedMotion': _reduced,
        'contactLeadMs': 30,
        'pauseMs': 50,
        'shakeMs': 120,
        'anchors': anchors,
      }, Duration(milliseconds: _reduced ? 0 : duration)),
    );
  }

  bool acknowledge(String id, int generation) =>
      _queue.complete(id, generation);
  bool contact(String id, int generation) {
    final action = _queue.active;
    if (!_active ||
        action?.id != id ||
        generation != this.generation ||
        _contacted == '$generation:$id') {
      return false;
    }
    _contacted = '$generation:$id';
    final gestureId = action!.value['gestureEventId'];
    final capture =
        action.value['kind'] == 'CardsCollected' ||
        action.value['kind'] == 'CardSlammed';
    if (gestureId is String && onGestureContact != null) {
      onGestureContact!(gestureId);
      if (capture) {
        _captureContact?.cancel();
        _captureContact = Timer(Duration(milliseconds: _reduced ? 0 : 160), () {
          if (generation == this.generation && _active) {
            onContact('$id:celebrate', true);
          }
        });
      }
      return true;
    }
    onContact(id, capture);
    return true;
  }

  void clear() {
    _captureContact?.cancel();
    _selections.clear();
    _poses.clear();
    _queue.reset();
    _previous = null;
    _latest = null;
    _scope = '';
    send({'type': 'CANCEL_VISUALS', 'generation': generation});
  }

  void dispose() {
    _captureContact?.cancel();
    _queue.dispose();
  }
}
