import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/models/match_state.dart';
import '../../domain/models/capture_event.dart';
import '../../domain/logic/online_match_clock.dart';

/// Only the central artwork is held during capture. Hands, legal actions and
/// deadlines always use the accepted state, never this presentation copy.
class CapturePresentation extends StatefulWidget {
  final MatchState state;
  final Widget Function(MatchState) builder;
  final DateTime Function()? now;
  const CapturePresentation({super.key, required this.state,
    required this.builder, this.now});
  @override
  State<CapturePresentation> createState() => _CapturePresentationState();
}

class _CapturePresentationState extends State<CapturePresentation> {
  final _seen = <String>{};
  final _queue = <CaptureEvent>[];
  CaptureEvent? _active;
  Timer? _timer;
  bool _reduced = false;

  void _reset() {
    _timer?.cancel();
    _active = null;
    _queue.clear();
    _seen.clear();
    // Initial/reconnected snapshots are the current table, not a replay.
    _seen.addAll(widget.state.captureEvents.map((event) => event.id));
  }

  @override
  void initState() { super.initState(); _reset(); }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) { _timer?.cancel(); _active = null; _queue.clear(); }
  }
  @override
  void didUpdateWidget(CapturePresentation oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.state, next = widget.state;
    if (old.id != next.id || old.roundCount != next.roundCount ||
        old.matchSequence != next.matchSequence) { _reset(); return; }
    if (next.serverVersion < old.serverVersion) return;
    final now = widget.now?.call() ?? OnlineMatchClock.instance.now();
    for (final event in next.captureEvents) {
      if (!_seen.add(event.id)) continue;
      // Do not replay a long animation backlog after a backgrounded tab.
      if (!_reduced && now.difference(event.createdAt).inMilliseconds < 2000) {
        _queue.add(event);
      }
    }
    _startNext();
  }
  void _startNext() {
    if (_active != null || _queue.isEmpty || _reduced) return;
    _active = _queue.removeAt(0);
    _timer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() { _active = null; _startNext(); });
    });
  }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final event = _active;
    return widget.builder(event == null ? widget.state : widget.state.copyWith(
      phase: GamePhase.capturing, board: event.cards,
      capturingCards: event.cards, capturingTeam: event.team,
      capturingStage: 0,
      // Preserve the original actor's physical seat through a later move.
      cardOwnership: {...widget.state.cardOwnership,
        event.cards.last.firebaseKey: event.playerUid},
    ));
  }
}
