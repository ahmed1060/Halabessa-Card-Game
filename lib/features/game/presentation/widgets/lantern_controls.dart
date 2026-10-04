import 'package:flutter/material.dart';
import 'dart:async';
import 'table_style.dart';

class LanternControlButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const LanternControlButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: SizedBox(
      width: MediaQuery.sizeOf(context).width < 350 ? 64 : 76,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: TableStyle.ink,
          foregroundColor: TableStyle.ivory,
          side: const BorderSide(color: TableStyle.mint, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Semantics(
          label: label,
          excludeSemantics: true,
          child: Icon(icon, size: 25),
        ),
      ),
    ),
  );
}

class LanternTurnBadge extends StatelessWidget {
  final String title;
  final String hint;
  final bool active;
  final DateTime? turnStarted;
  final int turnSeconds;
  const LanternTurnBadge({
    super.key,
    required this.title,
    required this.hint,
    required this.active,
    this.turnStarted,
    this.turnSeconds = 0,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.auto_awesome,
                  color: TableStyle.brass,
                  size: 18,
                ),
              ),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: active ? TableStyle.brass : TableStyle.ink,
                  border: Border.all(
                    color: active ? TableStyle.ink : TableStyle.mint,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TableStyle.label.copyWith(
                        fontWeight: FontWeight.w700,
                        color: active ? TableStyle.ink : TableStyle.ivory,
                      ),
                    ),
                    if (active && turnStarted != null && turnSeconds > 0)
                      TurnCountdown(
                        started: turnStarted!,
                        seconds: turnSeconds,
                      ),
                  ],
                ),
              ),
            ),
            if (active)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.auto_awesome,
                  color: TableStyle.brass,
                  size: 18,
                ),
              ),
          ],
        ),
        if (hint.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              hint,
              textAlign: TextAlign.center,
              style: TableStyle.detail.copyWith(color: TableStyle.ivory),
            ),
          ),
      ],
    ),
  );
}

/// A presentation clock, not a move scheduler. It never resets on a rebuild.
class TurnCountdown extends StatefulWidget {
  final DateTime started;
  final int seconds;
  const TurnCountdown({
    super.key,
    required this.started,
    required this.seconds,
  });
  @override
  State<TurnCountdown> createState() => _TurnCountdownState();
}

class _TurnCountdownState extends State<TurnCountdown> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remainingMs = widget.started
        .add(Duration(seconds: widget.seconds))
        .difference(DateTime.now())
        .inMilliseconds;
    final remaining = (remainingMs / 1000).ceil().clamp(0, widget.seconds);
    return Semantics(
      label: '$remaining seconds remaining',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 18, color: TableStyle.ink),
          Text(
            '${remaining}s',
            key: const ValueKey('local-turn-countdown'),
            textDirection: TextDirection.ltr,
            style: TableStyle.label.copyWith(
              color: TableStyle.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
