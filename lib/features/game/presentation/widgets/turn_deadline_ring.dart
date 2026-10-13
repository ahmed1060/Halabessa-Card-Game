import 'dart:async';
import 'dart:math' as math;
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
  final bool segmented;
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
    this.segmented = false,
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
      child: widget.segmented
          ? Semantics(
              label: widget.active && widget.duration > Duration.zero
                  ? (widget.remainingLabel?.call(
                          (remaining * widget.duration.inMilliseconds / 1000)
                              .ceil(),
                        ) ??
                        '${(remaining * widget.duration.inMilliseconds / 1000).ceil()} seconds remaining')
                  : null,
              child: CustomPaint(
                painter: _SegmentedRing(
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

class _SegmentedRing extends CustomPainter {
  final bool active;
  final double remaining;
  final Color foreground, background;
  _SegmentedRing(this.active, this.remaining, this.foreground, this.background);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(3);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = active ? 5 : 3;
    if (!active) {
      canvas.drawOval(rect, paint..color = background);
      return;
    }
    for (var i = 0; i < 16; i++) {
      paint.color = i / 16 < remaining
          ? foreground
          : foreground.withValues(alpha: .18);
      canvas.drawArc(
        rect,
        -math.pi / 2 + i * math.pi / 8,
        math.pi / 8 - .06,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SegmentedRing old) =>
      active != old.active ||
      remaining != old.remaining ||
      foreground != old.foreground ||
      background != old.background;
}
