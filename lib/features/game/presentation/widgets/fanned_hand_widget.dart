import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as game_card;
import 'package:halabessa/features/game/presentation/widgets/card_widget.dart';

class FannedHandWidget extends StatefulWidget {
  final List<game_card.Card> cards;
  final Function(game_card.Card, Offset origin) onCardTap;
  final bool isMyTurn;

  const FannedHandWidget({
    super.key,
    required this.cards,
    required this.onCardTap,
    this.isMyTurn = false,
  });

  @override
  State<FannedHandWidget> createState() => _FannedHandWidgetState();
}

class _FannedHandWidgetState extends State<FannedHandWidget> {
  int? hoveredIndex;
  int? preSelectedIndex;
  Offset? preSelectedOrigin;

  @override
  void didUpdateWidget(FannedHandWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Auto-play pre-selected card when it becomes my turn
    if (!oldWidget.isMyTurn && widget.isMyTurn && preSelectedIndex != null) {
      if (preSelectedIndex! < widget.cards.length) {
        final card = widget.cards[preSelectedIndex!];
        final origin = preSelectedOrigin ?? Offset.zero;
        
        // Use a slight delay to allow the turn transition animation to breathe
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && widget.isMyTurn && widget.cards.contains(card)) {
            widget.onCardTap(card, origin);
            setState(() {
              preSelectedIndex = null;
              preSelectedOrigin = null;
            });
          }
        });
      } else {
        setState(() {
          preSelectedIndex = null;
          preSelectedOrigin = null;
        });
      }
    }

    // Reset pre-selection if cards change and the index is no longer valid
    if (widget.cards.length != oldWidget.cards.length) {
      if (preSelectedIndex != null && preSelectedIndex! >= widget.cards.length) {
        setState(() {
          preSelectedIndex = null;
          preSelectedOrigin = null;
        });
      }
    }
  }

  void _handleHoverUpdate(Offset localPosition, double fanWidth, double preferredSpacing, int cardCount) {
    // Magnetic/Exit logic: If finger is too far left/right or too far up, clear hover
    // Fix: Increased right boundary to include the full width of the rightmost card
    if (localPosition.dx < -50 || localPosition.dx > (fanWidth + 100) || localPosition.dy < -100 || localPosition.dy > 200) {
      if (hoveredIndex != null) {
        setState(() => hoveredIndex = null);
      }
      return;
    }

    // Map X position to card index
    int newIndex = (localPosition.dx / preferredSpacing).floor().clamp(0, cardCount - 1);
    
    if (newIndex != hoveredIndex) {
      HapticFeedback.selectionClick();
      setState(() => hoveredIndex = newIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) return const SizedBox.shrink();
    final int cardCount = widget.cards.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final bool isMobile = screenWidth < 500;
        
        // Configuration for the fan effect
        final double cardWidth = isMobile ? 70.0 : 85.0;
        final double cardHeight = isMobile ? 100.0 : 125.0;
        
        // Calculate dynamic spacing to ensure overlap
        final double preferredSpacing = isMobile ? 18.0 : 25.0;
        final double fanWidth = (cardCount - 1) * preferredSpacing;
        
        // Arc configuration
        final double arcHeight = isMobile ? 30.0 : 40.0;
        const double maxRotation = 0.18; // radians

        // To ensure the hovered or preselected card is on top, we sort the indices
        final List<int> buildIndices = List.generate(cardCount, (i) => i);
        final int? topIndex = hoveredIndex ?? preSelectedIndex;
        if (topIndex != null && topIndex < cardCount) {
          buildIndices.remove(topIndex);
          buildIndices.add(topIndex);
        }

        return GestureDetector(
          onPanStart: (details) => _handleHoverUpdate(details.localPosition, fanWidth, preferredSpacing, cardCount),
          onPanUpdate: (details) => _handleHoverUpdate(details.localPosition, fanWidth, preferredSpacing, cardCount),
          onPanEnd: (_) {
            if (hoveredIndex != null) {
              // Calculate the center of the card in local coordinates
              final double normalizedPos = cardCount > 1 
                  ? (hoveredIndex! / (cardCount - 1)) * 2 - 1 
                  : 0.0;
              final double xPos = (hoveredIndex! * preferredSpacing) + (cardWidth / 2);
              final double yPos = arcHeight * (normalizedPos * normalizedPos);
              final double yFromBottom = 20 + (arcHeight - yPos) + (cardHeight / 2);
              
              final double widgetWidth = fanWidth + cardWidth;
              final double finalX = xPos - (widgetWidth / 2);
              final double finalY = -(yFromBottom - 20);
              final Offset origin = Offset(finalX, finalY);

              if (widget.isMyTurn) {
                HapticFeedback.mediumImpact();
                widget.onCardTap(widget.cards[hoveredIndex!], origin);
                setState(() {
                  preSelectedIndex = null;
                  preSelectedOrigin = null;
                });
              } else {
                // Pre-selection mode
                HapticFeedback.lightImpact();
                setState(() {
                  // Toggle logic: If tapping the same card, deselect it
                  if (preSelectedIndex == hoveredIndex) {
                    preSelectedIndex = null;
                    preSelectedOrigin = null;
                  } else {
                    preSelectedIndex = hoveredIndex;
                    preSelectedOrigin = origin;
                  }
                });
              }
            }
            setState(() => hoveredIndex = null);
          },
          onPanCancel: () => setState(() => hoveredIndex = null),
          child: Container(
            width: fanWidth + cardWidth,
            height: cardHeight + arcHeight + 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Colors.transparent), // Catch gestures
            child: Stack(
              clipBehavior: Clip.none,
              children: buildIndices.map((index) {
                final double normalizedPos = cardCount > 1 
                    ? (index / (cardCount - 1)) * 2 - 1 
                    : 0.0;
                
                final double xPos = (index * preferredSpacing);
                final double yPos = arcHeight * (normalizedPos * normalizedPos);
                final double rotation = normalizedPos * maxRotation;

                final bool isHovered = hoveredIndex == index;
                final bool isPreSelected = preSelectedIndex == index;
                final double elevationY = (isHovered || isPreSelected) ? -40.0 : 0.0;
                final double scale = (isHovered || isPreSelected) ? 1.25 : 1.0;

                return Positioned(
                  left: xPos,
                  bottom: 20 + (arcHeight - yPos),
                  child: MouseRegion( // Still works for Desktop
                    onEnter: (_) => setState(() => hoveredIndex = index),
                    onExit: (_) => setState(() => hoveredIndex = null),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutBack,
                      transform: Matrix4.identity()
                        ..translate(0.0, elevationY)
                        ..rotateZ(rotation)
                        ..scale(scale),
                      transformAlignment: Alignment.bottomCenter,
                      child: IgnorePointer( // Let the GestureDetector above handle the logic
                        child: Stack(
                          children: [
                            CardWidget(
                              card: widget.cards[index],
                              width: cardWidth,
                              height: cardHeight,
                              onTap: null, // Handled by GestureDetector
                            ),
                            if (isPreSelected && !isHovered)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.tealAccent.withOpacity(0.35),
                                        blurRadius: 15,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
