import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../domain/logic/online_match_clock.dart';

/// One wake-up, not a frame ticker. The server independently enforces readiness.
class MatchPlayAvailability extends StatefulWidget {
  const MatchPlayAvailability({
    super.key,
    required this.availableAt,
    required this.serverClock,
    required this.builder,
    this.now,
  });
  final DateTime? availableAt;
  final bool serverClock;
  final DateTime Function()? now;
  final Widget Function(bool ready) builder;
  @override
  State<MatchPlayAvailability> createState() => _MatchPlayAvailabilityState();
}

class _MatchPlayAvailabilityState extends State<MatchPlayAvailability>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _ready = true;
  DateTime _now() =>
      widget.now?.call() ??
      (widget.serverClock ? OnlineMatchClock.instance.now() : DateTime.now());
  void _schedule() {
    _timer?.cancel();
    final remaining = widget.availableAt?.difference(_now()) ?? Duration.zero;
    _ready = remaining <= Duration.zero;
    if (!_ready)
      _timer = Timer(remaining, () {
        if (mounted) setState(_schedule);
      });
  }

  void _refresh() {
    if (mounted) setState(_schedule);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    OnlineMatchClock.instance.addListener(_refresh);
    _schedule();
  }

  @override
  void didUpdateWidget(MatchPlayAvailability oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.availableAt != oldWidget.availableAt ||
        widget.serverClock != oldWidget.serverClock)
      _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    OnlineMatchClock.instance.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_ready);
}
