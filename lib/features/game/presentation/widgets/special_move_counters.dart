import 'package:flutter/material.dart';
import 'table_style.dart';

/// Accepted remaining uses only. These indicators never issue commands.
class SpecialMoveCounters extends StatelessWidget {
  final int slams, reveals;
  final String slamLabel, revealLabel;
  final String? activeMove;
  const SpecialMoveCounters({
    super.key,
    required this.slams,
    required this.reveals,
    required this.slamLabel,
    required this.revealLabel,
    this.activeMove,
  });
  @override
  Widget build(BuildContext context) => Row(
    textDirection: TextDirection.ltr,
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      _counter(
        'slam',
        Icons.back_hand_outlined,
        slams,
        TableStyle.brass,
        slamLabel,
      ),
      const SizedBox(width: 14),
      _counter(
        'reveal',
        Icons.visibility_outlined,
        reveals,
        TableStyle.mint,
        revealLabel,
      ),
    ],
  );
  Widget _counter(
    String id,
    IconData icon,
    int value,
    Color color,
    String label,
  ) => Semantics(
    label: label,
    value: '${value.clamp(0, 3)}',
    child: ExcludeSemantics(
      child: Opacity(
        opacity: value <= 0 ? .45 : 1,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 19,
              shadows: activeMove == id
                  ? [Shadow(color: color, blurRadius: 8)]
                  : null,
            ),
            const SizedBox(width: 4),
            Text(
              '${value.clamp(0, 3)}',
              key: ValueKey('special-$id-remaining'),
              textScaler: TextScaler.noScaling,
              style: TableStyle.label.copyWith(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
