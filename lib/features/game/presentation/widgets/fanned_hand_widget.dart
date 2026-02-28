import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as game_card;
import 'package:halabessa/features/game/presentation/widgets/card_widget.dart';

class FannedHandWidget extends StatefulWidget {
  final List<game_card.Card> cards;
  final Function(game_card.Card) onCardTap;
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

  void _handleHoverUpdate(Offset localPosition, double fanWidth, double preferredSpacing, int cardCount) {
    // Magnetic/Exit logic: If finger is too far left/right or too far up, clear hover
    if (localPosition.dx < -50 || localPosition.dx > fanWidth + 50 || localPosition.dy < -100 || localPosition.dy > 200) {
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
        final double cardWidth = isMobile ? 84.0 : 100.0;
        final double cardHeight = isMobile ? 120.0 : 150.0;
        
        // Calculate dynamic spacing to ensure overlap
        final double preferredSpacing = isMobile ? 22.0 : 30.0;
        final double fanWidth = (cardCount - 1) * preferredSpacing;
        
        // Arc configuration
        final double arcHeight = isMobile ? 30.0 : 40.0;
        const double maxRotation = 0.18; // radians

        // To ensure the hovered card is on top, we sort the indices
        final List<int> buildIndices = List.generate(cardCount, (i) => i);
        if (hoveredIndex != null) {
          buildIndices.remove(hoveredIndex);
          buildIndices.add(hoveredIndex!);
        }

        return GestureDetector(
          onPanStart: (details) => _handleHoverUpdate(details.localPosition, fanWidth, preferredSpacing, cardCount),
          onPanUpdate: (details) => _handleHoverUpdate(details.localPosition, fanWidth, preferredSpacing, cardCount),
          onPanEnd: (_) {
            if (hoveredIndex != null && widget.isMyTurn) {
              HapticFeedback.mediumImpact();
              widget.onCardTap(widget.cards[hoveredIndex!]);
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
                final double elevationY = isHovered ? -45.0 : 0.0;
                final double scale = isHovered ? 1.25 : 1.0;

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
                        child: CardWidget(
                          card: widget.cards[index],
                          width: cardWidth,
                          height: cardHeight,
                          onTap: null, // Handled by GestureDetector
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
