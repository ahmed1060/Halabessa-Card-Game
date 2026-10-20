import 'package:flutter/material.dart';
import '../../domain/models/match_state.dart';
import '../../domain/models/capture_event.dart';
import '../../domain/logic/online_match_clock.dart';
import '../../domain/logic/match_presentation_timing.dart';
import '../providers/visual_action_queue.dart';

/// Only the central artwork is held during capture. Hands, legal actions and
/// deadlines always use the accepted state, never this presentation copy.
class CapturePresentation extends StatefulWidget {
  final MatchState state;
  final Widget Function(MatchState) builder;
  final DateTime Function()? now;
  final void Function(CaptureEvent)? onReducedContact;
  const CapturePresentation({
    super.key,
    required this.state,
    required this.builder,
    this.now,
    this.onReducedContact,
  });
  @override
  State<CapturePresentation> createState() => _CapturePresentationState();
}

class _CapturePresentationState extends State<CapturePresentation> {
  final _seen = <String>{};
  Object? _active;
  late final _actions = VisualActionQueue<Object>(
    onStart: (action) => _active = action.value,
    onFinish: (_, __) {
      if (mounted) setState(() => _active = null);
    },
    onOverflow: () => _active = null,
  );
  bool _reduced = false;

  void _reset() {
    _actions.reset();
    _active = null;
    _seen.clear();
    // Initial/reconnected snapshots are the current table, not a replay.
    _seen.addAll(widget.state.captureEvents.map((event) => event.id));
  }

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _actions.reset();
      _active = null;
    }
  }

  @override
  void didUpdateWidget(CapturePresentation oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.state, next = widget.state;
    if (old.id != next.id ||
        old.roundCount != next.roundCount ||
        old.matchSequence != next.matchSequence) {
      _reset();
      return;
    }
    if (next.serverVersion < old.serverVersion) return;
    final now = widget.now?.call() ?? OnlineMatchClock.instance.now();
    var newCapture = false;
    for (final event in next.captureEvents) {
      if (!_seen.add(event.id)) continue;
      newCapture = true;
      if (_reduced && now.difference(event.createdAt).inMilliseconds < 2000) {
        widget.onReducedContact?.call(event);
      }
      // Do not replay a long animation backlog after a backgrounded tab.
      if (!_reduced && now.difference(event.createdAt).inMilliseconds < 2000) {
        // Keep the capture window at its existing length, not after an older
        // ordinary settle. Only cosmetic table reflow is fast-forwarded.
        if (_active is MatchState) {
          _actions.reset();
          _active = null;
        }
        _actions.add(VisualAction(event.id, event, captureTotalDuration));
      }
    }
    if (!newCapture &&
        !_reduced &&
        cardJuiceEnabled &&
        next.phase == GamePhase.playing &&
        old.phase == GamePhase.playing) {
      final arrived = next.board.where((c) => !old.board.contains(c)).toList();
      if (arrived.length == 1) {
        _actions.add(
          VisualAction(
            'play:${next.handInRound}:${arrived.single.firebaseKey}',
            next,
            const Duration(milliseconds: 350),
          ),
        );
      }
    } else if (_active is MatchState && next.phase != GamePhase.playing) {
      _actions.reset();
      _active = null;
    }
  }

  @override
  void dispose() {
    _actions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    if (active is MatchState) {
      // Only public table artwork is staged. Real legality, hand membership,
      // scores and deadlines remain those of widget.state.
      return widget.builder(widget.state.copyWith(board: active.board));
    }
    final event = active is CaptureEvent ? active : null;
    return widget.builder(
      event == null
          ? widget.state
          : widget.state.copyWith(
              phase: GamePhase.capturing,
              board: event.cards,
              capturingCards: event.cards,
              capturingTeam: event.team,
              capturingStage: 0,
              // Preserve the original actor's physical seat through a later move.
              cardOwnership: {
                ...widget.state.cardOwnership,
                event.cards.last.firebaseKey: event.playerUid,
              },
            ),
    );
  }
}
