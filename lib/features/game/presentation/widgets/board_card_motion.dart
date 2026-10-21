import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import '../providers/visual_action_queue.dart';

/// One-shot travel for a card arriving on the board. The card's identity is
/// supplied as the widget key, so unrelated table rebuilds do not replay it.
class BoardCardMotion extends StatefulWidget {
  final Offset origin;
  final Widget child;
  final Duration delay;
  final Duration travelDuration;
  final double initialOpacity;
  final bool alreadyArrived;
  final VoidCallback? onContact;
  final bool gestureSlam;

  const BoardCardMotion({
    super.key,
    required this.origin,
    this.delay = Duration.zero,
    this.travelDuration = const Duration(milliseconds: 320),
    this.initialOpacity = 0.75,
    this.alreadyArrived = false,
    required this.child,
    this.onContact,
    this.gestureSlam = false,
  });

  @override
  State<BoardCardMotion> createState() => _BoardCardMotionState();
}

class _BoardCardMotionState extends State<BoardCardMotion>
    with SingleTickerProviderStateMixin {
  bool get _slam => widget.gestureSlam && cardJuiceEnabled;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration:
        (_slam ? const Duration(milliseconds: 470) : widget.travelDuration) +
        widget.delay,
  );
  Timer? _contact;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.alreadyArrived || MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      if (!widget.alreadyArrived && !_started) {
        _started = true;
        _contact = Timer(Duration.zero, () {
          if (mounted) widget.onContact?.call();
        });
      }
    } else if (!_started) {
      _started = true;
      _controller.forward();
      if (widget.onContact != null) {
        _contact = Timer(
          (_slam ? const Duration(milliseconds: 300) : widget.travelDuration) +
              widget.delay -
              const Duration(milliseconds: 30),
          () {
            if (mounted) widget.onContact?.call();
          },
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _contact?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      if (_slam) {
        final ms =
            _controller.value * (470 + widget.delay.inMilliseconds) -
            widget.delay.inMilliseconds;
        final flight = ((ms - 100) / 200).clamp(0.0, 1.0);
        final eased = Curves.easeInCubic.transform(flight);
        final windup = (ms / 100).clamp(0.0, 1.0);
        final settle = ((ms - 350) / 120).clamp(0.0, 1.0);
        final punch = math.sin(math.pi * settle) * .06;
        return Transform.translate(
          offset:
              widget.origin * (1 - eased) +
              Offset(
                math.sin(settle * math.pi * 6) * 1.5 * (1 - settle),
                -14 * windup * (1 - eased),
              ),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .001)
              ..rotateX(-.15 * math.sin(math.pi * flight))
              ..scaleByDouble(
                1 + .2 * windup * (1 - eased) + punch,
                1 + .2 * windup * (1 - eased) - punch,
                1,
                1,
              ),
            child: child,
          ),
        );
      }
      final travelMs = widget.travelDuration.inMilliseconds;
      final elapsed =
          _controller.value * (travelMs + widget.delay.inMilliseconds);
      final travel = ((elapsed - widget.delay.inMilliseconds) / travelMs)
          .clamp(0.0, 1.0)
          .toDouble();
      final progress = Curves.easeOutCubic.transform(travel);
      return Transform.translate(
        offset:
            widget.origin * (1 - progress) +
            Offset(0, cardJuiceEnabled ? -math.sin(math.pi * travel) * 12 : 0),
        child: Transform.scale(
          scale:
              0.84 +
              0.16 * progress +
              (cardJuiceEnabled
                  ? math.sin(math.pi * ((travel - .75) / .25).clamp(0, 1)) *
                        .025
                  : 0),
          child: Opacity(
            opacity:
                widget.initialOpacity + (1 - widget.initialOpacity) * progress,
            child: child,
          ),
        ),
      );
    },
  );
}
