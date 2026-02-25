import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final int cardCount = widget.cards.length;
        
        // Configuration for the fan effect
        const double cardWidth = 100.0;
        const double cardHeight = 150.0;
        
        // Calculate dynamic spacing to ensure overlap
        // We want cards to overlap by about 60-70%
        const double preferredSpacing = 30.0;
        final double fanWidth = (cardCount - 1) * preferredSpacing;
        
        // Arc configuration
        const double arcHeight = 40.0;
        const double maxRotation = 0.20; // radians

        // To ensure the hovered card is on top, we sort the indices
        final List<int> buildIndices = List.generate(cardCount, (i) => i);
        if (hoveredIndex != null) {
          buildIndices.remove(hoveredIndex);
          buildIndices.add(hoveredIndex!);
        }

        return Container(
          width: fanWidth + cardWidth,
          height: cardHeight + arcHeight + 40,
          alignment: Alignment.center,
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
              final double elevationY = isHovered ? -40.0 : 0.0;
              final double scale = isHovered ? 1.2 : 1.0;

              return Positioned(
                left: xPos,
                bottom: 20 + (arcHeight - yPos), // Invert parabola for upward arc
                child: MouseRegion(
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
                    child: CardWidget(
                      card: widget.cards[index],
                      width: cardWidth,
                      height: cardHeight,
                      onTap: widget.isMyTurn ? () => widget.onCardTap(widget.cards[index]) : null,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
