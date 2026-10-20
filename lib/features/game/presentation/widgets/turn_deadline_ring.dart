import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Smooth deadline presentation only. It never schedules or accepts a move.
class TurnDeadlineRing extends StatefulWidget {
  final bool active;
  final DateTime? started;
  final Duration duration;
  final Color foreground;
  final Color background;
  final DateTime Function()? now;
  final Listenable? clockChanges;
  final bool liquid;
  final String Function(int)? remainingLabel;
  const TurnDeadlineRing({
    super.key,
    required this.active,
    this.started,
    required this.duration,
    required this.foreground,
    required this.background,
    this.now,
    this.clockChanges,
    this.liquid = false,
    this.remainingLabel,
  });

  @override
  State<TurnDeadlineRing> createState() => _TurnDeadlineRingState();
}

class _TurnDeadlineRingState extends State<TurnDeadlineRing>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((elapsed) {
    if (mounted) {
      setState(() => _elapsed = elapsed);
      if (_expired(
        widget.now != null ? _now() : (_anchor ?? _now()).add(elapsed),
      )) {
        _ticker.stop();
      }
    }
  });
  Timer? _reducedClock;
  DateTime? _anchor;
  Duration _elapsed = Duration.zero;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    widget.clockChanges?.addListener(_recalibrated);
  }

  void _recalibrated() {
    if (!mounted) return;
    _restart();
    setState(() {});
  }

  DateTime _now() => widget.now?.call() ?? DateTime.now();
  bool _expired(DateTime sample) =>
      widget.started != null &&
      !sample.isBefore(widget.started!.add(widget.duration));

  void _restart() {
    _ticker.stop();
    _reducedClock?.cancel();
    _anchor = _now();
    _elapsed = Duration.zero;
    if (!widget.active ||
        widget.started == null ||
        widget.duration <= Duration.zero ||
        _expired(_now())) {
      return;
    }
    if (_reduced) {
      _reducedClock = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (mounted) setState(() {});
        if (_expired(_now())) _reducedClock?.cancel();
      });
    } else {
      _ticker.start();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _restart();
  }

  @override
  void didUpdateWidget(TurnDeadlineRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clockChanges != widget.clockChanges) {
      oldWidget.clockChanges?.removeListener(_recalibrated);
      widget.clockChanges?.addListener(_recalibrated);
    }
    if (oldWidget.active != widget.active ||
        oldWidget.started != widget.started ||
        oldWidget.duration != widget.duration ||
        oldWidget.now != widget.now ||
        oldWidget.clockChanges != widget.clockChanges) {
      _restart();
    }
  }

  @override
  void dispose() {
    widget.clockChanges?.removeListener(_recalibrated);
    _ticker.dispose();
    _reducedClock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sample = widget.now != null || _reduced
        ? _now()
        : (_anchor ?? _now()).add(_elapsed);
    final remaining = widget.started == null || widget.duration <= Duration.zero
        ? 1.0
        : (1 -
                  sample.difference(widget.started!).inMicroseconds /
                      widget.duration.inMicroseconds)
              .clamp(0.0, 1.0);
    return RepaintBoundary(
      child: widget.liquid
          ? Semantics(
              label: widget.active && widget.duration > Duration.zero
                  ? (widget.remainingLabel?.call(
                          (remaining * widget.duration.inMilliseconds / 1000)
                              .ceil(),
                        ) ??
                        '${(remaining * widget.duration.inMilliseconds / 1000).ceil()} seconds remaining')
                  : null,
              child: CustomPaint(
                key: const ValueKey('liquid-deadline-ring'),
                painter: LiquidDeadlineRingPainter(
                  widget.active,
                  remaining,
                  widget.foreground,
                  widget.background,
                ),
              ),
            )
          : CircularProgressIndicator(
              key: const ValueKey('turn-deadline-progress'),
              value: widget.active ? remaining : 0,
              backgroundColor: widget.background,
              color: widget.foreground,
              strokeWidth: 3,
            ),
    );
  }
}

/// A closed annulus at every remaining value, never an arc or segmented timer.
/// Only thickness changes; time/expiry still come from the existing clock above.
class LiquidDeadlineRingPainter extends CustomPainter {
  final bool active;
  final double remaining;
  final Color foreground, background;
  LiquidDeadlineRingPainter(
    this.active,
    this.remaining,
    this.foreground,
    this.background,
  );
  double get thickness => active ? 5 * remaining.clamp(0, 1) : 3;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    if (!active) {
      canvas.drawCircle(
        center,
        size.shortestSide / 2 - 3,
        paint
          ..strokeWidth = 3
          ..color = background,
      );
      return;
    }
    if (thickness <= 0) return;
    // Fixed outside diameter. Smooth radial shading suggests liquid depth,
    // without a sweep-gradient seam, ticks, detached droplets or a draining gap.
    final radius = size.shortestSide / 2 - 1 - thickness / 2;
    canvas.drawCircle(
      center,
      radius,
      paint
        ..strokeWidth = thickness + 1
        ..color = foreground.withValues(alpha: .3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    paint
      ..maskFilter = null
      ..strokeWidth = thickness
      ..shader =
          RadialGradient(
            colors: [
              foreground.withValues(alpha: .75),
              Color.lerp(foreground, Colors.white, .7)!,
              foreground,
            ],
            stops: [
              ((radius - thickness / 2) / (radius + thickness / 2)).clamp(0, 1),
              (radius / (radius + thickness / 2)).clamp(0, 1),
              1,
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: radius + thickness / 2),
          );
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(LiquidDeadlineRingPainter old) =>
      active != old.active ||
      remaining != old.remaining ||
      foreground != old.foreground ||
      background != old.background;
}
