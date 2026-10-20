import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/models/card.dart' as game_card;
import 'card_widget.dart';
import 'dart:math' as math;
import '../providers/visual_action_queue.dart';
import 'option_b_table.dart';

/// Physical (not directional) geometry of the artwork at the moment of a tap.
class CardPlayOrigin {
  final Rect bounds;
  final double angle;
  const CardPlayOrigin(this.bounds, this.angle);
  Offset get center => bounds.center;
}

/// Shared by the authoritative pile and its local, provisional top card.
Offset boardCardOffset(int index, int count, double width) {
  if (count > 4) return Offset.zero;
  if (count < 4) return Offset((index - (count - 1) / 2) * width * .45, 0);
  const positions = [
    Offset(-.48, .13),
    Offset(0, -.36),
    Offset(.46, .05),
    Offset(.12, .54),
  ];
  return positions[index.clamp(0, 3)] * width;
}

double boardCardAngle(int index, int count) => count > 4
    ? 0
    : count < 4
    ? (index - (count - 1) / 2) * .08
    : [-.12, -.02, .12, .02][index.clamp(0, 3)];
Offset boardTopCardOffset(int count, double width) =>
    boardCardOffset(count - 1, count, width);
double boardTopCardAngle(int count) => boardCardAngle(count - 1, count);

typedef PresentCard = Future<void> Function(game_card.Card, CardPlayOrigin);

/// Immediate artwork feedback, never an optimistic MatchState. Hand membership,
/// turn, captures and scores are still supplied exclusively by the controller.
class LocalCardPlayLayer extends StatefulWidget {
  final String identity;
  final List<game_card.Card> hand;
  final int boardCount;
  final GlobalKey boardKey;
  final bool isLandscape;
  final bool enabled;
  final Future<bool> Function(game_card.Card, CardPlayOrigin) submit;
  final Widget Function(game_card.Card?, Set<String>, PresentCard) builder;
  final Widget Function(game_card.Card, double, double)? cardBuilder;
  final String pendingLabel;
  final void Function(game_card.Card)? onContact;
  final VoidCallback? onRejected;

  const LocalCardPlayLayer({
    super.key,
    required this.identity,
    required this.hand,
    required this.boardCount,
    required this.boardKey,
    required this.submit,
    required this.builder,
    this.isLandscape = false,
    this.enabled = true,
    this.cardBuilder,
    this.pendingLabel = 'Sending move',
    this.onContact,
    this.onRejected,
  });

  @override
  State<LocalCardPlayLayer> createState() => _LocalCardPlayLayerState();
}

class _LocalCardPlayLayerState extends State<LocalCardPlayLayer> {
  final _layerKey = GlobalKey();
  final Set<String> _presented = {};
  _PendingPlay? _pending;

  @override
  void didUpdateWidget(LocalCardPlayLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) {
      _pending = null;
      _presented.clear();
    } else if (_pending != null && !widget.hand.contains(_pending!.card)) {
      // A private realtime snapshot may beat the HTTP acknowledgement. Do not
      // undo an already committed move if that acknowledgement is later lost.
      _pending = null;
    }
  }

  Future<void> _play(game_card.Card card, CardPlayOrigin origin) async {
    if (_pending != null || !widget.hand.contains(card)) return;
    if (!widget.enabled) {
      await widget.submit(card, origin);
      return;
    }
    final board = widget.boardKey.currentContext?.findRenderObject();
    final layer = _layerKey.currentContext?.findRenderObject();
    if (board is! RenderBox || layer is! RenderBox || !board.hasSize) {
      // Presentation geometry must never suppress a valid input.
      await widget.submit(card, origin);
      return;
    }
    final width = OptionBGeometry.tableCardSize.width;
    final height = OptionBGeometry.tableCardSize.height;
    final target = Rect.fromCenter(
      center:
          board.size.center(Offset.zero) +
          boardTopCardOffset(widget.boardCount + 1, width),
      width: width,
      height: height,
    );
    // Convert both corners, so browser scaling and the table's parent transforms
    // use the same coordinate space as the overlay (including RTL).
    final pending = _PendingPlay(
      card,
      Rect.fromPoints(
        layer.globalToLocal(origin.bounds.topLeft),
        layer.globalToLocal(origin.bounds.bottomRight),
      ),
      Rect.fromPoints(
        layer.globalToLocal(board.localToGlobal(target.topLeft)),
        layer.globalToLocal(board.localToGlobal(target.bottomRight)),
      ),
      origin.angle,
      boardTopCardAngle(widget.boardCount + 1),
    );
    final identity = widget.identity;
    setState(() {
      _pending = pending;
      _presented.add(card.firebaseKey);
    });
    var accepted = false;
    try {
      accepted = await widget.submit(card, origin);
    } catch (_) {
      // The controller owns the user-facing error. Restore artwork on failure.
    }
    if (!mounted || widget.identity != identity || _pending != pending) return;
    if (!accepted) {
      widget.onRejected?.call();
      setState(() => pending.returning = true);
      await pending.returned.future;
    }
    // On success, wait for the authoritative hand update rather than briefly
    // restoring the old card while a confirmed snapshot is being delivered.
  }

  void _restore(_PendingPlay pending) {
    if (mounted && _pending == pending) {
      setState(() {
        _pending = null;
        _presented.remove(pending.card.firebaseKey);
      });
    }
    if (!pending.returned.isCompleted) pending.returned.complete();
  }

  @override
  Widget build(BuildContext context) => Stack(
    key: _layerKey,
    fit: StackFit.passthrough,
    clipBehavior: Clip.none,
    children: [
      widget.builder(_pending?.card, Set.unmodifiable(_presented), _play),
      if (_pending case final pending?)
        Positioned.fill(
          child: IgnorePointer(
            child: _CardFlight(
              key: ObjectKey(pending),
              play: pending,
              pendingLabel: widget.pendingLabel,
              cardBuilder: widget.cardBuilder,
              onReturned: () => _restore(pending),
              onContact: () => widget.onContact?.call(pending.card),
            ),
          ),
        ),
    ],
  );
}

class _PendingPlay {
  final game_card.Card card;
  final Rect from, to;
  final double fromAngle, toAngle;
  bool returning = false;
  final returned = Completer<void>();
  _PendingPlay(this.card, this.from, this.to, this.fromAngle, this.toAngle);
}

class _CardFlight extends StatefulWidget {
  final _PendingPlay play;
  final String pendingLabel;
  final Widget Function(game_card.Card, double, double)? cardBuilder;
  final VoidCallback onReturned;
  final VoidCallback? onContact;
  const _CardFlight({
    super.key,
    required this.play,
    required this.pendingLabel,
    required this.onReturned,
    this.cardBuilder,
    this.onContact,
  });
  @override
  State<_CardFlight> createState() => _CardFlightState();
}

class _CardFlightState extends State<_CardFlight>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: cardJuiceEnabled ? 250 : 180),
  );
  bool _started = false, _returnStarted = false;
  Timer? _contact;
  double _returnFrom = 1;
  double _returnControllerFrom = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
        _contact = Timer(const Duration(milliseconds: 190), () {
          if (mounted && !widget.play.returning) widget.onContact?.call();
        });
      }
    }
  }

  @override
  void didUpdateWidget(_CardFlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.play.returning && !_returnStarted) {
      _returnStarted = true;
      _contact?.cancel();
      _returnFrom = Curves.easeOutCubic.transform(_controller.value);
      _returnControllerFrom = _controller.value;
      if (MediaQuery.disableAnimationsOf(context)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onReturned();
        });
      } else {
        _controller
            .animateTo(0, duration: _controller.reverseDuration)
            .whenCompleteOrCancel(() {
              if (mounted) widget.onReturned();
            });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _contact?.cancel();
    if (!widget.play.returned.isCompleted) widget.play.returned.complete();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final progress = widget.play.returning && cardJuiceEnabled
          ? _returnFrom *
                (1 -
                    Curves.easeOutBack.transform(
                      1 -
                          (_controller.value /
                                  (_returnControllerFrom == 0
                                      ? 1
                                      : _returnControllerFrom))
                              .clamp(0, 1),
                    ))
          : Curves.easeOutCubic.transform(_controller.value);
      final play = widget.play;
      final rect = Rect.lerp(play.from, play.to, progress)!.shift(
        Offset(
          0,
          cardJuiceEnabled && !widget.play.returning
              ? -math.sin(math.pi * _controller.value) * 16
              : 0,
        ),
      );
      final angle =
          play.fromAngle +
          (play.toAngle - play.fromAngle) * progress +
          (cardJuiceEnabled && !widget.play.returning
              ? math.sin(math.pi * _controller.value) * .07
              : 0);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fromRect(
            rect: rect,
            child: Transform.rotate(
              angle: angle,
              child: Semantics(
                label: widget.pendingLabel,
                child: Stack(
                  children: [
                    widget.cardBuilder?.call(
                          play.card,
                          rect.width,
                          rect.height,
                        ) ??
                        CardWidget(
                          card: play.card,
                          width: rect.width,
                          height: rect.height,
                        ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
