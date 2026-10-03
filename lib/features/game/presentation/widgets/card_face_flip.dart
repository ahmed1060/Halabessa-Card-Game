import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Visual-only flip. Key by played-card identity; rebuilds keep its progress.
class CardFaceFlip extends StatefulWidget {
  final bool showBack;
  final Widget front;
  final Widget back;
  const CardFaceFlip({
    super.key,
    required this.showBack,
    required this.front,
    required this.back,
  });
  @override
  State<CardFaceFlip> createState() => _CardFaceFlipState();
}

class _CardFaceFlipState extends State<CardFaceFlip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
    value: widget.showBack ? 1 : 0,
  );

  @override
  void didUpdateWidget(CardFaceFlip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showBack == widget.showBack) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _flip.value = widget.showBack ? 1 : 0;
    } else {
      _flip.animateTo(widget.showBack ? 1 : 0, curve: Curves.easeInOut);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _flip.value = widget.showBack ? 1 : 0;
    }
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _flip,
    builder: (context, _) => Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(
        math.cos(math.pi * _flip.value).abs().clamp(.01, 1),
        1,
        1,
      ),
      child: _flip.value < .5 ? widget.front : widget.back,
    ),
  );
}
