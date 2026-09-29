import 'dart:math';
import 'package:flutter/material.dart';
import '../../domain/models/card.dart' as game_card;
import '../../domain/models/match_state.dart';
import '../../../../core/theme/theme_config.dart';
import 'card_widget.dart';
import 'board_card_motion.dart';
import 'table_style.dart';

class BoardCardsWidget extends StatelessWidget {
  final List<game_card.Card> cards;
  final bool isLandscape;
  final bool isCapturing;
  final String? capturingTeam;
  final int capturingStage;
  final Map<String, Offset> arrivalOffsets;
  final bool captureToBottom;
  final String? captureLabel;
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
    this.captureLabel,
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
    final reflowDuration = reducedMotion ? Duration.zero :
        const Duration(milliseconds: 240);

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
              key: const ValueKey('capture-flight'),
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
                      children: _buildCardStack(cardWidth, cardHeight, reflowDuration)),
                  ),
                ),
              ),
            ),

            if (isCapturing && captureLabel != null && captureLabel!.isNotEmpty)
              Positioned(
                top: -48,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('capture-cue-$captureLabel'),
                  tween: Tween(begin: 0, end: 1),
                  duration: reducedMotion ? Duration.zero :
                      const Duration(milliseconds: 180),
                  builder: (context, progress, child) => Transform.translate(
                    offset: Offset(0, 8 * (1 - progress)),
                    child: Opacity(opacity: progress, child: child),
                  ),
                  child: Semantics(
                    liveRegion: true,
                    label: captureLabel,
                    excludeSemantics: true,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 220),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: TableStyle.ink,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: TableStyle.brass.withOpacity(0.7)),
                      ),
                      child: Text(captureLabel!, textAlign: TextAlign.center,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TableStyle.detail.copyWith(color: TableStyle.ivory,
                          fontWeight: FontWeight.w600)),
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

  Widget _positionedCard(game_card.Card card, double width, double height,
      Offset position, double angle, Widget child, Duration duration) =>
    KeyedSubtree(
      key: ValueKey('board-slot-${card.firebaseKey}'),
      child: AnimatedSlide(
        key: ValueKey('board-position-${card.firebaseKey}'),
        duration: duration,
        curve: Curves.easeOutCubic,
        offset: Offset(position.dx / width, position.dy / height),
        child: AnimatedRotation(
          duration: duration,
          curve: Curves.easeOutCubic,
          turns: angle / (2 * pi),
          child: _arrivingCard(card, child),
        ),
      ),
    );

  List<Widget> _buildCardStack(double width, double height, Duration reflowDuration) {
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

        cardWidgets.add(_positionedCard(card, width, height,
          Offset(xOffset, 0), angle,
          _buildCardWithHighlight(card, width, height, isTop), reflowDuration));
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

        cardWidgets.add(_positionedCard(card, width, height,
          Offset(pseudoRandomX, pseudoRandomY), pseudoRandomAngle,
          Opacity(opacity: 0.85, child: _card(card, width, height)),
          reflowDuration));
      }

      // Top card (active card to match)
      final topCard = cards.last;
      cardWidgets.add(_positionedCard(topCard, width, height,
        Offset.zero, 0,
        _buildCardWithHighlight(topCard, width, height, true),
        reflowDuration));
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
