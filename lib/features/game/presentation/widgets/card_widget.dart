import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:playing_cards/playing_cards.dart';

import '../../domain/models/card.dart' as game_card;
import '../../../home/presentation/providers/store_provider.dart';

class CardWidget extends ConsumerWidget {
  final game_card.Card card;
  final bool isFaceUp;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final String? customBackPath;
  final String? customFrontPath;
  final Map<String, String>? faceIllustrations;

  const CardWidget({
    super.key,
    required this.card,
    this.isFaceUp = true,
    this.width = 84,
    this.height = 120,
    this.onTap,
    this.customBackPath,
    this.customFrontPath,
    this.faceIllustrations,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final notifier = ref.watch(storeProvider.notifier);
    final activeCard = notifier.allItems.firstWhere(
      (i) => i.id == store.activeCardBackId, 
      orElse: () => notifier.allItems[0]
    );

    final effectiveBackPath = customBackPath ?? activeCard.assetPath;
    final effectiveFrontPath = customFrontPath ?? activeCard.frontSkinPath ?? 'assets/images/cards/premium/card_front_premium_bg.png';
    final effectiveIllustrations = faceIllustrations ?? activeCard.faceIllustrations;

    if (!isFaceUp) {
      return GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: width,
          height: height,
          child: PlayingCardView(
            card: PlayingCard(
              _mapSuit(card.suit),
              _mapRank(card.rank),
            ),
            showBack: true,
            style: PlayingCardViewStyle(
              cardBackContentBuilder: (context) => ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: effectiveBackPath.startsWith('http')
                  ? Image.network(effectiveBackPath, fit: BoxFit.cover)
                  : Image.asset(effectiveBackPath, fit: BoxFit.cover),
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5),
            ),
            elevation: 8.0,
          ),
        ),
      );
    }

    // Custom Front Rendering
    return GestureDetector(
      onTap: onTap,
      child: Material(
        elevation: 8.0,
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
          ),
          child: Stack(
            children: [
              // Themed Background
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: effectiveFrontPath.startsWith('http')
                    ? Image.network(effectiveFrontPath, fit: BoxFit.cover)
                    : Image.asset(effectiveFrontPath, fit: BoxFit.cover),
                ),
              ),
              // Face Card Illustration
                Builder(
                  builder: (context) {
                    final illustrationPath = _getIllustrationPath(effectiveIllustrations);
                    if (illustrationPath == null) return const SizedBox.shrink();
                    return Center(
                      child: Opacity(
                        opacity: 0.8,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18.0),
                          child: illustrationPath.startsWith('http')
                            ? Image.network(illustrationPath, fit: BoxFit.contain)
                            : Image.asset(illustrationPath, fit: BoxFit.contain),
                        ),
                      ),
                    );
                  },
                ),
              _buildFrontOverlay(context, isFaceItem: _getIllustrationPath(effectiveIllustrations) != null, customFrontPath: effectiveFrontPath),
            ],
          ),
        ),
      ),
    );
  }

  String? _getIllustrationPath(Map<String, String>? illustrations) {
    if (illustrations == null) return null;
    if (card.rank == game_card.Rank.king) return illustrations['king'];
    if (card.rank == game_card.Rank.queen) return illustrations['queen'] ?? illustrations['king'];
    if (card.rank == game_card.Rank.jack) return illustrations['jack'] ?? illustrations['king'];
    return null;
  }

  Widget _buildFrontOverlay(BuildContext context, {required bool isFaceItem, required String customFrontPath}) {
    final color = _getCardColor(customFrontPath);
    final rankText = _getRankText();
    final suitIcon = _getSuitIcon();

    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: Stack(
        children: [
          // Top Left Rank
          Positioned(
            top: 0,
            left: 0,
            child: Column(
              children: [
                Text(rankText, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                Icon(suitIcon, color: color, size: 12),
              ],
            ),
          ),
          // Center Large Suit (Only if not a face item with illustration)
          if (!isFaceItem)
            Center(
              child: Icon(suitIcon, color: color.withOpacity(0.4), size: 40),
            ),
          // Bottom Right Rank (inverted)
          Positioned(
            bottom: 0,
            right: 0,
            child: RotatedBox(
              quarterTurns: 2,
              child: Column(
                children: [
                  Text(rankText, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                  Icon(suitIcon, color: color, size: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCardColor(String customFrontPath) {
    // If it's Neon theme, maybe use Cyan/Pink? 
    // For now, let's stick to standard Red/Black but brightened for the theme.
    if (card.suit == game_card.Suit.hearts || card.suit == game_card.Suit.diamonds) {
      return customFrontPath.contains('neon') == true ? const Color(0xFFFF4081) : Colors.redAccent;
    } else {
      return customFrontPath.contains('neon') == true ? const Color(0xFF00E5FF) : Colors.black87;
    }
  }

  String _getRankText() {
    switch (card.rank) {
      case game_card.Rank.ace: return 'A';
      case game_card.Rank.jack: return 'J';
      case game_card.Rank.queen: return 'Q';
      case game_card.Rank.king: return 'K';
      default: return (card.rank.index + 2).toString();
    }
  }

  IconData _getSuitIcon() {
    switch (card.suit) {
      case game_card.Suit.hearts: return Icons.favorite;
      case game_card.Suit.diamonds: return Icons.diamond;
      case game_card.Suit.clubs: return Icons.spa;
      case game_card.Suit.spades: return Icons.bolt; // Funky choice for Spades in Neon
    }
  }

  Suit _mapSuit(game_card.Suit suit) {
    switch (suit) {
      case game_card.Suit.hearts: return Suit.hearts;
      case game_card.Suit.diamonds: return Suit.diamonds;
      case game_card.Suit.clubs: return Suit.clubs;
      case game_card.Suit.spades: return Suit.spades;
    }
  }

  CardValue _mapRank(game_card.Rank rank) {
    switch (rank) {
      case game_card.Rank.two: return CardValue.two;
      case game_card.Rank.three: return CardValue.three;
      case game_card.Rank.four: return CardValue.four;
      case game_card.Rank.five: return CardValue.five;
      case game_card.Rank.six: return CardValue.six;
      case game_card.Rank.seven: return CardValue.seven;
      case game_card.Rank.eight: return CardValue.eight;
      case game_card.Rank.nine: return CardValue.nine;
      case game_card.Rank.ten: return CardValue.ten;
      case game_card.Rank.jack: return CardValue.jack;
      case game_card.Rank.queen: return CardValue.queen;
      case game_card.Rank.king: return CardValue.king;
      case game_card.Rank.ace: return CardValue.ace;
    }
  }
}
