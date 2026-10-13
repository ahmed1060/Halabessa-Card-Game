import 'package:flutter/material.dart';
import 'team_capture_stack.dart';
import 'table_style.dart';

/// A reserved slot prevents the board moving when the dealer changes.
class DealerSeat extends StatelessWidget {
  final Widget seat;
  final bool isDealer;
  final bool compact;
  final bool deckOnLeft;
  final bool deckBelow;
  final bool largeDeck;
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
    this.deckOnLeft = false,
    this.deckBelow = false,
    this.largeDeck = false,
  });

  @override
  Widget build(BuildContext context) {
    final deck = SizedBox(
      width: compact && !largeDeck ? 44 : 64,
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
                    width: compact && !largeDeck ? 30 : 46,
                    height: compact && !largeDeck ? 42 : 66,
                  ),
                  Text(
                    '$remaining',
                    style: TableStyle.detail.copyWith(
                      color: TableStyle.brass,
                      fontSize: largeDeck ? 16 : 12,
                      fontWeight: FontWeight.w700,
                    ),
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
    // A side dealer's deck sits beside the avatar, toward the table. Its
    // reserved physical side does not mirror when the reading direction changes.
    return compact
        ? Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              seat,
              if (isDealer)
                Positioned(
                  top: deckBelow ? 118 : 8,
                  left: deckBelow
                      ? 30
                      : deckOnLeft
                      ? (largeDeck ? -52 : -34)
                      : null,
                  right: deckBelow || deckOnLeft
                      ? null
                      : (largeDeck ? -52 : -34),
                  child: deck,
                ),
            ],
          )
        : Row(
            textDirection: TextDirection.ltr,
            mainAxisSize: MainAxisSize.min,
            children: deckOnLeft
                ? [deck, seat, const SizedBox(width: 64)]
                : [const SizedBox(width: 64), seat, deck],
          );
  }
}
