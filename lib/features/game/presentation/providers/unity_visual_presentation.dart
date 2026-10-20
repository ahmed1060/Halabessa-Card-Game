import '../../domain/models/match_state.dart';
import 'visual_action_queue.dart';

/// Optional protocol extension. Old Unity builds continue consuming SYNC_STATE.
/// This class observes accepted state; it can emit only visual messages.
class UnityVisualPresentation {
  final void Function(Map<String, dynamic>) send;
  final void Function(String id, bool slam) onContact;
  final DateTime Function() now;
  late final VisualActionQueue<Map<String, dynamic>> _queue;
  MatchState? _previous, _latest;
  String? _uid;
  String _scope = '';
  String? _contacted;
  bool _capable = false, _active = false, _reduced = false;
  // An animation watchdog may disable pacing, never the negotiated coordinate
  // system. Otherwise the still-visible native hand jumps to legacy world units.
  bool _managedLayout = false;
  final _seenCaptures = <String>{};
  List<Map<String, dynamic>> anchors = const [];
  bool get capable => _capable;
  int get generation => _queue.generation;
  UnityVisualPresentation({
    required this.send,
    required this.onContact,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now {
    _queue = VisualActionQueue(
      allowance: const Duration(milliseconds: 350),
      onStart: (action) => send({...action.value, 'generation': generation}),
      onFinish: (_, timedOut) {
        if (timedOut) {
          // Never wait indefinitely for a rebuilt/crashed renderer. Cancel all
          // outstanding artwork and use snapshots in the SAME layout space.
          _capable = false;
          resync();
        } else if (_queue.pendingCount == 0 && _latest != null) {
          send(_snapshot(_latest!));
        }
      },
      onOverflow: resync,
    );
  }

  void negotiate(int protocol) {
    if (protocol != 1 || !cardJuiceEnabled) return;
    _capable = true;
    _managedLayout = true;
    resync();
  }

  Map<String, dynamic> _snapshot(MatchState state) => {
    'type': 'SYNC_STATE',
    'instant': _managedLayout,
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
  };

  void updateAnchors(List<Map<String, dynamic>> next) {
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
    if (!unchanged &&
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
          duration: 220,
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
        duration: 350,
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
    onContact(
      id,
      action!.value['kind'] == 'CardsCollected' ||
          action.value['kind'] == 'CardSlammed',
    );
    return true;
  }

  void clear() {
    _queue.reset();
    _previous = null;
    _latest = null;
    _scope = '';
    send({'type': 'CANCEL_VISUALS', 'generation': generation});
  }

  void dispose() {
    _queue.dispose();
  }
}
