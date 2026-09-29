import 'package:flutter/material.dart';

/// One-shot travel for a card arriving on the board. The card's identity is
/// supplied as the widget key, so unrelated table rebuilds do not replay it.
class BoardCardMotion extends StatefulWidget {
  final Offset origin;
  final Widget child;

  const BoardCardMotion({super.key, required this.origin, required this.child});

  @override
  State<BoardCardMotion> createState() => _BoardCardMotionState();
}

class _BoardCardMotionState extends State<BoardCardMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
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
      final progress = Curves.easeOutCubic.transform(_controller.value);
      return Transform.translate(
        offset: widget.origin * (1 - progress),
        child: Transform.scale(
          scale: 0.84 + 0.16 * progress,
          child: Opacity(opacity: progress, child: child),
        ),
      );
    },
  );
}
