import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/models/match_state.dart';
import 'team_capture_stack.dart';
import 'table_style.dart';

enum DeckFeedback { cutSeparate, cutContact, shuffleMix, shuffleContact }

enum _DeckAction { cut, shuffle, returnForCut }

/// Observes accepted state only. It cannot vote, cut, deal or advance a clock.
/// Flutter owns this one deck in both card renderers; no native copy is sent.
class DeckActionPresentation extends StatefulWidget {
  final MatchState state;
  final Object rendererIdentity;
  final Rect home;
  final Size tableSize;
  final String shuffleLabel;
  final Widget Function(double, double) backBuilder;
  final Widget Function(bool hideHome, Widget? overlay) builder;
  final void Function(String id, DeckFeedback feedback)? onFeedback;
  final bool allowFreshFirstShuffle;
  final DateTime Function()? now;
  const DeckActionPresentation({
    super.key,
    required this.state,
    required this.rendererIdentity,
    required this.home,
    required this.tableSize,
    required this.backBuilder,
    required this.builder,
    required this.shuffleLabel,
    this.onFeedback,
    this.allowFreshFirstShuffle = false,
    this.now,
  });
  @override
  State<DeckActionPresentation> createState() => _DeckActionPresentationState();
}

class _DeckActionPresentationState extends State<DeckActionPresentation>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static final _firstShuffles =
      <String>{}; // Bounded session-only replay guard.
  final _seen = <String>{};
  final _sounds = <Timer>[];
  late final _motion = AnimationController(vsync: this)
    ..addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      if (_action == _DeckAction.returnForCut) {
        _start(_DeckAction.cut, _event);
      } else if (mounted) {
        setState(() => _action = null);
      }
    });
  _DeckAction? _action;
  String _event = '';
  bool _reduced = false, _initialized = false;
  Offset _returnFrom = Offset.zero;
  double _returnScale = 1;
  String _scope(MatchState s) => '${s.id}:${s.matchSequence}';
  String _id(MatchState s, String kind) =>
      '${_scope(s)}:${s.roundCount}:$kind:${s.phaseStartedAt?.toIso8601String() ?? s.serverVersion}';
  DateTime get _now => widget.now?.call() ?? DateTime.now();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (_initialized && reduced != _reduced) _cancel();
    _reduced = reduced;
    if (_initialized) return;
    _initialized = true;
    final state = widget.state;
    final age = state.phaseStartedAt == null
        ? 1200
        : _now.difference(state.phaseStartedAt!).inMilliseconds;
    // A genuinely fresh first deck may already be accepted before the first
    // route frame. Catch up to its age, never replay its domain sound. Ordinary
    // mounts/reconnects are silent; later rounds require an observed transition.
    if (widget.allowFreshFirstShuffle &&
        state.roundCount == 1 &&
        state.phase == GamePhase.preRoundCut &&
        state.roundsSinceLastShuffle == 0 &&
        age >= 0 &&
        age < 1200 &&
        _firstShuffles.add(_id(state, 'shuffle'))) {
      while (_firstShuffles.length > 64) {
        _firstShuffles.remove(_firstShuffles.first);
      }
      _start(
        _DeckAction.shuffle,
        _id(state, 'shuffle'),
        silent: true,
        age: age,
      );
    }
  }

  @override
  void didUpdateWidget(DeckActionPresentation oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.state, next = widget.state;
    if (_scope(old) != _scope(next)) {
      _cancel();
      _seen.clear();
      // A confirmed rematch is a new action, not a reconnect replay.
      if (old.id == next.id &&
          (old.phase == GamePhase.rematchVoting ||
              old.phase == GamePhase.matchOver) &&
          next.matchSequence > old.matchSequence &&
          next.roundCount == 1 &&
          next.phase == GamePhase.preRoundCut &&
          next.roundsSinceLastShuffle == 0 &&
          next.phaseStartedAt != null) {
        final age = _now.difference(next.phaseStartedAt!).inMilliseconds;
        if (age >= 0 && age < 1200) {
          final id = _id(next, 'shuffle');
          _seen.add(id);
          _firstShuffles.add(id);
          while (_firstShuffles.length > 64) {
            _firstShuffles.remove(_firstShuffles.first);
          }
          _start(_DeckAction.shuffle, id, age: age);
        }
      }
      return;
    }
    if (oldWidget.rendererIdentity != widget.rendererIdentity ||
        oldWidget.tableSize != widget.tableSize ||
        oldWidget.home != widget.home) {
      _cancel();
      return; // Resize/reconnect settles; it does not replay history.
    }
    if (next.serverVersion < old.serverVersion || next.roomClosed) {
      _cancel();
      return;
    }
    if (next.phase == GamePhase.preRoundCut &&
        next.roundsSinceLastShuffle == 0 &&
        (old.phase != next.phase || old.roundCount != next.roundCount)) {
      final age = next.phaseStartedAt == null
          ? 0
          : _now.difference(next.phaseStartedAt!).inMilliseconds;
      if (age < 0 || age >= 1200) {
        _cancel();
        return;
      }
      final id = _id(next, 'shuffle');
      if (next.roundCount == 1) {
        _firstShuffles.add(id);
        while (_firstShuffles.length > 64) {
          _firstShuffles.remove(_firstShuffles.first);
        }
      }
      if (_seen.add(id)) _start(_DeckAction.shuffle, id, age: age);
    } else if (old.phase == GamePhase.preRoundCut &&
        next.phase == GamePhase.dealingFasha &&
        old.roundCount == next.roundCount) {
      final age = next.phaseStartedAt == null
          ? 0
          : _now.difference(next.phaseStartedAt!).inMilliseconds;
      if (age < 0 || age >= 650) {
        _cancel();
        return;
      }
      final id = _id(next, 'cut');
      if (!_seen.add(id)) return;
      if (_action == _DeckAction.shuffle && !_reduced) {
        final pose = _shufflePose();
        _returnFrom = pose.$1;
        _returnScale = pose.$2;
        _start(_DeckAction.returnForCut, id);
      } else {
        _start(_DeckAction.cut, id, age: age);
      }
    } else if (next.phase != GamePhase.preRoundCut &&
        next.phase != GamePhase.dealingFasha) {
      _cancel();
    }
    while (_seen.length > 64) {
      _seen.remove(_seen.first);
    }
  }

  void _cancel() {
    for (final timer in _sounds) {
      timer.cancel();
    }
    _sounds.clear();
    _motion.stop();
    _action = null;
  }

  void _cue(int at, String suffix, DeckFeedback kind, int age) {
    if (at < age) return;
    final id = '$_event:$suffix';
    _sounds.add(
      Timer(Duration(milliseconds: at - age), () {
        if (mounted && _action != null) widget.onFeedback?.call(id, kind);
      }),
    );
  }

  void _start(
    _DeckAction action,
    String id, {
    bool silent = false,
    int age = 0,
  }) {
    _cancel();
    _action = action;
    _event = id;
    final duration = _reduced
        ? 80
        : switch (action) {
            _DeckAction.cut => 650,
            _DeckAction.shuffle => 1200,
            _DeckAction.returnForCut => 120,
          };
    _motion.duration = Duration(milliseconds: duration);
    if (!silent && action != _DeckAction.returnForCut) {
      if (_reduced) {
        _cue(
          0,
          'settle',
          action == _DeckAction.cut
              ? DeckFeedback.cutContact
              : DeckFeedback.shuffleContact,
          0,
        );
      } else if (action == _DeckAction.cut) {
        _cue(50, 'separate', DeckFeedback.cutSeparate, age);
        _cue(540, 'contact', DeckFeedback.cutContact, age);
      } else {
        _cue(190, 'mix1', DeckFeedback.shuffleMix, age);
        _cue(520, 'mix2', DeckFeedback.shuffleMix, age);
        _cue(1090, 'contact', DeckFeedback.shuffleContact, age);
      }
    }
    _motion.forward(from: _reduced ? 0 : (age / duration).clamp(0, 1));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mounted) {
      setState(_cancel);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancel();
    _motion.dispose();
    super.dispose();
  }

  (Offset, double) _shufflePose() {
    final ms = _motion.value * 1200;
    final outbound = Curves.easeOutCubic.transform((ms / 220).clamp(0, 1));
    final homeward = Curves.easeInOutCubic.transform(
      ((ms - 880) / 240).clamp(0, 1),
    );
    final amount = outbound * (1 - homeward);
    return (
      Offset.lerp(
        widget.home.center,
        widget.tableSize.center(Offset.zero),
        amount,
      )!,
      1 + amount,
    );
  }

  Widget _packet(
    String key,
    Offset position,
    double angle,
    int count, {
    double flex = 0,
  }) => Transform.translate(
    offset: position,
    child: Transform.rotate(
      angle: angle,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(1 + flex, 1 - flex, 1),
        child: DecoratedBox(
          key: ValueKey(key),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(2, 3),
              ),
            ],
          ),
          child: FaceDownStack(
            count: count,
            backBuilder: widget.backBuilder,
            width: widget.home.width - 10,
            height: widget.home.height - 10,
          ),
        ),
      ),
    ),
  );
  Widget _overlay() {
    final action = _action!;
    final t = _motion.value;
    var center = widget.home.center, scale = 1.0;
    var upper = Offset.zero, lower = Offset.zero, tilt = 0.0;
    var upperOnTop = true;
    var flex = 0.0;
    if (!_reduced && action == _DeckAction.shuffle) {
      final pose = _shufflePose();
      center = pose.$1;
      scale = pose.$2;
      final mix = ((t * 1200 - 220) / 660).clamp(0.0, 1.0);
      final wave = math.sin(mix * math.pi * 4);
      final spread = math.sin(math.pi * mix);
      upper = Offset(wave * 22, -spread * 9);
      lower = Offset(-wave * 22, spread * 9);
      tilt = wave * .13;
      upperOnTop = wave >= 0;
      flex = math.sin(math.pi * ((t * 1200 - 1120) / 80).clamp(0, 1)) * .025;
    } else if (!_reduced && action == _DeckAction.returnForCut) {
      final p = Curves.easeOutCubic.transform(t);
      center = Offset.lerp(_returnFrom, widget.home.center, p)!;
      scale = _returnScale + (1 - _returnScale) * p;
    } else if (!_reduced) {
      final ms = t * 650;
      final lift = Curves.easeOutCubic.transform((ms / 80).clamp(0, 1));
      final separate = Curves.easeOutCubic.transform(
        ((ms - 80) / 140).clamp(0, 1),
      );
      final transfer = Curves.easeInOutCubic.transform(
        ((ms - 220) / 220).clamp(0, 1),
      );
      final align = Curves.easeOutBack.transform(
        ((ms - 440) / 130).clamp(0, 1),
      );
      upper = Offset(
        28 * separate * (1 - align),
        -8 * lift * (1 - transfer) + 9 * transfer * (1 - align),
      );
      lower = Offset(-8 * separate * (1 - align), -3 * transfer * (1 - align));
      upperOnTop = transfer < .5;
      tilt = .08 * separate * (1 - align);
      flex = math.sin(math.pi * ((ms - 570) / 80).clamp(0, 1)) * .035;
    }
    final top = _packet('deck-upper-packet', upper, tilt, 20, flex: flex);
    final bottom = _packet(
      'deck-lower-packet',
      lower,
      -tilt * .5,
      32,
      flex: flex,
    );
    return Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fromRect(
                rect: Rect.fromCenter(
                  center: center,
                  width: widget.home.width,
                  height: widget.home.height,
                ),
                child: Opacity(
                  opacity: _reduced ? .75 + .25 * t : 1,
                  child: Transform.scale(
                    key: const ValueKey('deck-action-art'),
                    scale: scale,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: upperOnTop ? [bottom, top] : [top, bottom],
                    ),
                  ),
                ),
              ),
              if (action == _DeckAction.shuffle && !_reduced)
                Positioned(
                  left: center.dx - 95,
                  top: center.dy + widget.home.height * scale / 2 + 12,
                  width: 190,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: TableStyle.ink,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: TableStyle.brass),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        widget.shuffleLabel,
                        textAlign: TextAlign.center,
                        style: TableStyle.detail.copyWith(
                          color: TableStyle.ivory,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    builder: (_, __) =>
        widget.builder(_action != null, _action == null ? null : _overlay()),
  );
}
