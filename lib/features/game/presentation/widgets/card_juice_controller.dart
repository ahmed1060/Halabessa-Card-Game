import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../providers/visual_action_queue.dart';

double handArc(int index, int count) {
  final x = index - (count - 1) / 2;
  return 7 * (2.25 - x * x).clamp(0, 2.25);
}

/// Applies spring poses to artwork only. The parent keeps input geometry,
/// membership and activation semantics unchanged.
class CardJuiceController extends StatefulWidget {
  final Widget child;
  final bool peek;
  final Offset drag;
  final double velocity;
  const CardJuiceController({
    super.key,
    required this.child,
    this.peek = false,
    this.drag = Offset.zero,
    this.velocity = 0,
  });
  @override
  State<CardJuiceController> createState() => _CardJuiceControllerState();
}

class _CardJuiceControllerState extends State<CardJuiceController>
    with SingleTickerProviderStateMixin {
  late final _spring = AnimationController.unbounded(vsync: this);
  double _from = 0, _to = 0;
  bool _reduced = false;
  double get _peek => _from + (_to - _from) * _spring.value;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context) || !cardJuiceEnabled;
    _retarget();
  }

  @override
  void didUpdateWidget(CardJuiceController oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.peek != widget.peek) _retarget();
  }

  void _retarget() {
    final target = widget.peek && cardJuiceEnabled ? 1.0 : 0.0;
    if (target == _to && !_reduced) return;
    _from = _peek;
    _to = target;
    _spring.stop();
    if (_reduced) {
      _from = _to;
      _spring.value = 1;
    } else {
      _spring.value = 0;
      _spring.animateWith(
        SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 420, damping: 32),
          0,
          1,
          0,
        ),
      );
    }
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _spring,
    child: widget.child,
    builder: (_, child) {
      final peek = _peek.clamp(0.0, 1.05);
      final drag = _reduced ? Offset.zero : widget.drag;
      final tilt = _reduced ? 0.0 : (widget.velocity / 9000).clamp(-.12, .12);
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..translateByDouble(drag.dx, drag.dy - peek * 12, 0, 1)
          ..setEntry(3, 2, .001)
          ..rotateX(tilt)
          ..scaleByDouble(1 + .2 * peek, 1 + .2 * peek, 1, 1),
        child: child,
      );
    },
  );
}

/// Contact freeze and shake are local to the table art, never timeScale/HUD.
class CardTableImpact extends StatefulWidget {
  final String? identity;
  final Widget child;
  final VoidCallback? onContact;
  final Duration contactDelay;
  const CardTableImpact({
    super.key,
    required this.child,
    this.identity,
    this.onContact,
    this.contactDelay = const Duration(milliseconds: 190),
  });
  @override
  State<CardTableImpact> createState() => _CardTableImpactState();
}

class _CardTableImpactState extends State<CardTableImpact>
    with SingleTickerProviderStateMixin {
  late final _impact = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  Timer? _contact;
  String? _started;
  bool _reduced = false;
  bool _contacted = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _impact.stop();
      _impact.value = 0;
      if (_started != null && !_contacted) {
        _contact?.cancel();
        _contact = Timer(Duration.zero, _notifyContact);
      }
    }
    _start();
  }

  @override
  void didUpdateWidget(CardTableImpact oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.identity != oldWidget.identity) {
      _started = null;
      _start();
    }
  }

  void _start() {
    if (widget.identity == _started) return;
    _contact?.cancel();
    _impact.stop();
    _impact.value = 0;
    _started = widget.identity;
    _contacted = false;
    if (_started == null || !cardJuiceEnabled) return;
    _contact = Timer(
      _reduced ? Duration.zero : widget.contactDelay,
      _notifyContact,
    );
  }

  void _notifyContact() {
    if (!mounted || _contacted) return;
    _contacted = true;
    widget.onContact?.call(); // Request sensory feedback 30ms before contact.
    if (!_reduced) _impact.forward(from: 0);
  }

  @override
  void dispose() {
    _contact?.cancel();
    _impact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _impact,
    child: widget.child,
    builder: (_, child) {
      // First 30ms reaches contact; next 50ms holds before the 120ms shake.
      final elapsed = _impact.value * 200;
      final p = ((elapsed - 80) / 120).clamp(0.0, 1.0);
      final pulse = math.sin(math.pi * p) * (1 - p);
      return Transform.translate(
        offset: Offset(math.sin(p * math.pi * 6) * 2 * (1 - p), 0),
        child: Transform.scale(
          scaleX: 1 + pulse * .04,
          scaleY: 1 - pulse * .03,
          child: child,
        ),
      );
    },
  );
}
