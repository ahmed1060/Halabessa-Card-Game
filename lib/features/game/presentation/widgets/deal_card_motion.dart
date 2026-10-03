import 'package:flutter/material.dart';
import 'board_card_motion.dart';

/// Measure source and destination after layout, once per newly dealt card.
/// Rebuilds/turn-clock ticks never restart a settled card's animation.
class DealCardMotion extends StatefulWidget {
  final GlobalKey sourceKey;
  final Widget child;
  final Duration delay;
  const DealCardMotion({
    super.key,
    required this.sourceKey,
    required this.child,
    this.delay = Duration.zero,
  });
  @override
  State<DealCardMotion> createState() => _DealCardMotionState();
}

class _DealCardMotionState extends State<DealCardMotion> {
  Offset? _origin;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final source = widget.sourceKey.currentContext?.findRenderObject();
      final target = context.findRenderObject();
      final origin =
          source is RenderBox &&
              source.hasSize &&
              target is RenderBox &&
              target.hasSize
          ? target.globalToLocal(
                  source.localToGlobal(source.size.center(Offset.zero)),
                ) -
                target.size.center(Offset.zero)
          : Offset.zero;
      setState(() => _origin = origin);
    });
  }

  @override
  Widget build(BuildContext context) => _origin == null
      ? Opacity(opacity: 0, child: widget.child)
      : BoardCardMotion(
          origin: _origin!,
          delay: widget.delay,
          travelDuration: const Duration(milliseconds: 380),
          initialOpacity: 1,
          child: widget.child,
        );
}
