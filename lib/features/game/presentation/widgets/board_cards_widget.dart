import 'dart:math';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../domain/models/card.dart' as game_card;
import '../../domain/models/match_state.dart';
import '../../../../core/theme/theme_config.dart';
import 'card_widget.dart';
import 'board_card_motion.dart';

class BoardCardsWidget extends StatelessWidget {
  final List<game_card.Card> cards;
  final bool isLandscape;
  final bool isCapturing;
  final String? capturingTeam;
  final int capturingStage;
  final Map<String, Offset> arrivalOffsets;
  final bool captureToBottom;
  final Widget Function(game_card.Card, double, double)? cardBuilder;

  const BoardCardsWidget({
    super.key,
    required this.cards,
    this.isLandscape = false,
    this.isCapturing = false,
    this.capturingTeam,
    this.capturingStage = 0,
    this.arrivalOffsets = const {},
    this.captureToBottom = false,
    this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return Center(
        child: Container(
          width: isLandscape ? 180 : 140,
          height: isLandscape ? 120 : 95,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: Center(
            child: Text(
              'Halabessa',
              style: TextStyle(
                color: Colors.white.withOpacity(0.12),
                fontFamily: ThemeConfig.fontHeading,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      );
    }

    final cardWidth = isLandscape ? 72.0 : 64.0;
    final cardHeight = isLandscape ? 104.0 : 92.0;

    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final captureFlight = isCapturing && capturingStage > 0;
    final motionDuration = reducedMotion ? Duration.zero :
        const Duration(milliseconds: 300);

    return Center(
      child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Ambient table glow under the cards
            Container(
              width: (cardWidth * 2.2),
              height: (cardHeight * 1.6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: isCapturing
                        ? (capturingTeam == 'teamA' ? ThemeConfig.primaryTeal.withOpacity(0.45) : ThemeConfig.goldAccent.withOpacity(0.45))
                        : ThemeConfig.goldAccent.withOpacity(0.15),
                    blurRadius: 35,
                    spreadRadius: 8,
                  ),
                ],
              ),
            ),

            // The pile compresses on capture, then travels toward the winning
            // team. New cards independently arrive from their player's seat.
            AnimatedSlide(
              duration: motionDuration,
              curve: Curves.easeInOutCubic,
              offset: captureFlight
                  ? Offset(0, captureToBottom ? 1.3 : -1.3)
                  : Offset.zero,
              child: AnimatedScale(
                duration: motionDuration,
                curve: Curves.easeOutCubic,
                scale: isCapturing ? 0.84 : 1,
                child: AnimatedOpacity(
                  duration: motionDuration,
                  opacity: captureFlight ? 0.12 : 1,
                  child: SizedBox(
                    width: cardWidth * 2.2,
                    height: cardHeight * 1.6,
                    child: Stack(alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: _buildCardStack(cardWidth, cardHeight)),
                  ),
                ),
              ),
            ),

            // Card Count Badge (if more than 3 cards on table)
            if (cards.length > 3)
              Positioned(
                bottom: -22,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ThemeConfig.goldAccent.withOpacity(0.4), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.style, size: 12, color: ThemeConfig.goldAccent),
                      const SizedBox(width: 4),
                      Text(
                        '${cards.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
      ),
    );
  }

  Widget _arrivingCard(game_card.Card card, Widget child) => BoardCardMotion(
    key: ValueKey('board-${card.firebaseKey}'),
    origin: arrivalOffsets[card.firebaseKey] ?? const Offset(0, -95),
    child: child,
  );

  List<Widget> _buildCardStack(double width, double height) {
    // If 4 or fewer cards, fan them out horizontally with nice spacing
    final count = cards.length;
    final List<Widget> cardWidgets = [];

    if (count <= 4) {
      final totalSpan = (count - 1) * (width * 0.45);
      final startOffset = -totalSpan / 2;

      for (int i = 0; i < count; i++) {
        final card = cards[i];
        final isTop = i == count - 1;
        final xOffset = startOffset + (i * width * 0.45);
        // Pre-defined subtle angles for natural Egyptian card table feel
        final angle = (i - (count - 1) / 2) * 0.08;

        cardWidgets.add(
          KeyedSubtree(key: ValueKey('board-slot-${card.firebaseKey}'), child: Transform.translate(
            offset: Offset(xOffset, 0),
            child: Transform.rotate(
              angle: angle,
              child: _arrivingCard(card,
                _buildCardWithHighlight(card, width, height, isTop)),
            ),
          )),
        );
      }
    } else {
      // Pile of cards: show previous cards clustered, and the top card cleanly on top
      // Show up to 5 background cards with deterministic scatter
      final visibleBackgroundCount = min(count - 1, 5);
      final startIndex = count - 1 - visibleBackgroundCount;

      for (int i = startIndex; i < count - 1; i++) {
        final card = cards[i];
        final pseudoRandomAngle = (((i * 17) % 31) - 15) * (pi / 180.0);
        final pseudoRandomX = (((i * 13) % 21) - 10) * 1.5;
        final pseudoRandomY = (((i * 11) % 15) - 7) * 1.2;

        cardWidgets.add(
          KeyedSubtree(key: ValueKey('board-slot-${card.firebaseKey}'), child: Transform.translate(
            offset: Offset(pseudoRandomX, pseudoRandomY),
            child: Transform.rotate(
              angle: pseudoRandomAngle,
              child: _arrivingCard(card, Opacity(
                opacity: 0.85,
                child: _card(card, width, height),
              )),
            ),
          )),
        );
      }

      // Top card (active card to match)
      final topCard = cards.last;
      cardWidgets.add(
        KeyedSubtree(key: ValueKey('board-slot-${topCard.firebaseKey}'), child: Transform.translate(
          offset: const Offset(0, 0),
          child: _arrivingCard(topCard,
            _buildCardWithHighlight(topCard, width, height, true)),
        )),
      );
    }

    return cardWidgets;
  }

  Widget _buildCardWithHighlight(
    game_card.Card card,
    double width,
    double height,
    bool isTopCard,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isTopCard ? 0.45 : 0.25),
            blurRadius: isTopCard ? 14 : 8,
            offset: const Offset(0, 5),
          ),
          if (isTopCard)
            BoxShadow(
              color: ThemeConfig.goldAccent.withOpacity(0.35),
              blurRadius: 10,
              spreadRadius: 1,
            ),
        ],
      ),
      child: _card(card, width, height),
    );
  }

  Widget _card(game_card.Card card, double width, double height) =>
      cardBuilder?.call(card, width, height) ??
      CardWidget(card: card, width: width, height: height);
}
