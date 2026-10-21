import 'dart:math' as math;
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
          ? DealDeck(
              remaining: remaining,
              label: label,
              deckKey: deckKey,
              backBuilder: backBuilder,
              small: compact && !largeDeck,
              largeLabel: largeDeck,
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

/// Presentation-only deck; dealer identity remains on the actual player's seat.
/// Option B reserves one fixed slot so a dealer change cannot crowd the board.
class DealDeck extends StatelessWidget {
  final int remaining;
  final String label;
  final GlobalKey? deckKey;
  final Widget Function(double, double) backBuilder;
  final bool small, largeLabel;
  final bool thematic;
  final String? shuffleIdentity;
  final DateTime? shuffleStartedAt;
  final bool hideArtwork;
  const DealDeck({
    super.key,
    required this.remaining,
    required this.label,
    required this.backBuilder,
    this.deckKey,
    this.small = false,
    this.largeLabel = true,
    this.thematic = false,
    this.shuffleIdentity,
    this.shuffleStartedAt,
    this.hideArtwork = false,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $remaining',
    child: SizedBox(
      width: small ? 44 : 64,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _shuffle(
            context,
            Opacity(
              opacity: hideArtwork ? 0 : 1,
              child: FaceDownStack(
                key: deckKey,
                count: remaining,
                backBuilder: backBuilder,
                width: small ? 30 : 46,
                height: small ? 42 : 66,
              ),
            ),
          ),
          Container(
            padding: thematic
                ? const EdgeInsets.symmetric(horizontal: 5)
                : EdgeInsets.zero,
            decoration: thematic
                ? BoxDecoration(
                    color: TableStyle.ink,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: TableStyle.brass),
                  )
                : null,
            child: Text(
              '$remaining',
              style: TableStyle.detail.copyWith(
                color: TableStyle.brass,
                fontSize: largeLabel ? 16 : 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (thematic)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: TableStyle.ink,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TableStyle.brass),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  style: TableStyle.detail.copyWith(
                    color: TableStyle.brass,
                    fontSize: 11,
                  ),
                ),
              ),
            )
          else
            Text(label, textAlign: TextAlign.center, style: TableStyle.detail),
        ],
      ),
    ),
  );

  Widget _shuffle(BuildContext context, Widget child) {
    final age = shuffleStartedAt == null
        ? Duration.zero
        : DateTime.now().difference(shuffleStartedAt!);
    final remaining = Duration(
      milliseconds: 650 - age.inMilliseconds.clamp(0, 650),
    );
    if (shuffleIdentity == null ||
        remaining <= Duration.zero ||
        MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey('deck-shuffle-$shuffleIdentity'),
      tween: Tween(begin: 0, end: 1),
      duration: remaining,
      child: child,
      builder: (_, t, content) {
        final wave = math.sin(t * math.pi * 4) * (1 - t);
        return Transform.translate(
          offset: Offset(wave * 6, 0),
          child: Transform.rotate(angle: wave * .06, child: content),
        );
      },
    );
  }
}
