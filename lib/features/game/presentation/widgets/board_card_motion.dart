import 'package:flutter/material.dart';

/// One-shot travel for a card arriving on the board. The card's identity is
/// supplied as the widget key, so unrelated table rebuilds do not replay it.
class BoardCardMotion extends StatefulWidget {
  final Offset origin;
  final Widget child;
  final Duration delay;
  final Duration travelDuration;
  final double initialOpacity;

  const BoardCardMotion({super.key, required this.origin,
    this.delay = Duration.zero,
    this.travelDuration = const Duration(milliseconds: 320),
    this.initialOpacity = 0.75,
    required this.child});

  @override
  State<BoardCardMotion> createState() => _BoardCardMotionState();
}

class _BoardCardMotionState extends State<BoardCardMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.travelDuration + widget.delay,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (_controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      final travelMs = widget.travelDuration.inMilliseconds;
      final elapsed = _controller.value *
          (travelMs + widget.delay.inMilliseconds);
      final travel = ((elapsed - widget.delay.inMilliseconds) / travelMs)
          .clamp(0.0, 1.0).toDouble();
      final progress = Curves.easeOutCubic.transform(travel);
      return Transform.translate(
        offset: widget.origin * (1 - progress),
        child: Transform.scale(
          scale: 0.84 + 0.16 * progress,
          child: Opacity(
            opacity: widget.initialOpacity +
                (1 - widget.initialOpacity) * progress,
            child: child,
          ),
        ),
      );
    },
  );
}
