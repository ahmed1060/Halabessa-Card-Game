import 'package:flutter/material.dart';
import 'team_capture_stack.dart';
import 'table_style.dart';

/// A reserved slot prevents the board moving when the dealer changes.
class DealerSeat extends StatelessWidget {
  final Widget seat;
  final bool isDealer;
  final bool compact;
  final int remaining;
  final String label;
  final GlobalKey? deckKey;
  final Widget Function(double, double) backBuilder;
  const DealerSeat({
    super.key,
    required this.seat,
    required this.isDealer,
    required this.remaining,
    required this.label,
    required this.backBuilder,
    this.deckKey,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final deck = SizedBox(
      width: 64,
      child: isDealer
          ? Semantics(
              label: '$label: $remaining',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FaceDownStack(
                    key: deckKey,
                    count: remaining,
                    backBuilder: backBuilder,
                    width: compact ? 30 : 38,
                    height: compact ? 42 : 54,
                  ),
                  Text(
                    '$remaining',
                    style: TableStyle.detail.copyWith(color: TableStyle.brass),
                  ),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TableStyle.detail,
                  ),
                ],
              ),
            )
          : const SizedBox(height: 84),
    );
    // Side seats use a vertical layout to keep the central table clear on a phone.
    return compact
        ? Column(mainAxisSize: MainAxisSize.min, children: [seat, deck])
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [const SizedBox(width: 64), seat, deck],
          );
  }
}
