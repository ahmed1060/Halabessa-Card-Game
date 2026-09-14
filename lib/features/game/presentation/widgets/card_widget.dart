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
  final String? customAceSkinPath;
  final String? customSevenDiamondSkinPath;
  final Map<String, String>? faceIllustrations;
  final Map<String, String>? customSuitIcons;

  const CardWidget({
    super.key,
    required this.card,
    this.isFaceUp = true,
    this.width = 70,
    this.height = 100,
    this.onTap,
    this.customBackPath,
    this.customFrontPath,
    this.customAceSkinPath,
    this.customSevenDiamondSkinPath,
    this.faceIllustrations,
    this.customSuitIcons,
    this.skinId,
  });

  final String? skinId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final notifier = ref.watch(storeProvider.notifier);
    
    final targetSkinId = skinId ?? store.activeCardBackId;
    final activeCard = notifier.allItems.firstWhere(
      (i) => i.id == targetSkinId, 
      orElse: () => notifier.allItems[0]
    );

    final effectiveBackPath = customBackPath ?? activeCard.assetPath;
    
    // Check for special card backgrounds
    String frontPath = activeCard.frontSkinPath ?? 'assets/images/cards/premium/card_front_premium_bg.png';
    if (card.rank == game_card.Rank.ace) {
      frontPath = customAceSkinPath ?? activeCard.aceSkinPath ?? frontPath;
    } else if (card.rank == game_card.Rank.seven && card.suit == game_card.Suit.diamonds) {
      frontPath = customSevenDiamondSkinPath ?? activeCard.sevenDiamondSkinPath ?? frontPath;
    }
    final effectiveFrontPath = customFrontPath ?? frontPath;

    final effectiveIllustrations = faceIllustrations ?? activeCard.faceIllustrations;
    final effectiveSuitIcons = customSuitIcons ?? activeCard.suitIcons;

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
                  ? Image.network(
                      effectiveBackPath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildCardBackFallback(),
                    )
                  : Image.asset(
                      effectiveBackPath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildCardBackFallback(),
                    ),
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
                    ? Image.network(
                        effectiveFrontPath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Colors.white),
                      )
                    : Image.asset(
                        effectiveFrontPath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Colors.white),
                      ),
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
                            ? Image.network(
                                illustrationPath,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                              )
                            : Image.asset(
                                illustrationPath,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                              ),
                        ),
                      ),
                    );
                  },
                ),
              _buildFrontOverlay(
                context, 
                isFaceItem: _getIllustrationPath(effectiveIllustrations) != null, 
                customFrontPath: effectiveFrontPath,
                customSuitIcons: effectiveSuitIcons,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardBackFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B2A4A), Color(0xFF0B132B)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.6), width: 1.5),
      ),
      child: Center(
        child: Container(
          width: 32,
          height: 48,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4), width: 1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(
            Icons.style_rounded,
            color: Color(0xFFD4AF37),
            size: 20,
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

  Widget _buildFrontOverlay(BuildContext context, {required bool isFaceItem, required String customFrontPath, Map<String, String>? customSuitIcons}) {
    final color = _getCardColor(customFrontPath);
    final rankText = _getRankText();
    
    Widget suitWidget;
    if (customSuitIcons != null) {
      String suitKey = card.suit.name;
      // Handle "Trifle" naming convention for Clubs in some themes
      if (card.suit == game_card.Suit.clubs && customSuitIcons.containsKey('trifle')) {
        suitKey = 'trifle';
      }
      
      final suitPath = customSuitIcons[suitKey];
      if (suitPath != null) {
        suitWidget = suitPath.startsWith('http') 
          ? Image.network(
              suitPath,
              width: 12,
              height: 12,
              errorBuilder: (_, __, ___) => Icon(_getSuitIcon(), color: color, size: 12),
            ) 
          : Image.asset(
              suitPath,
              width: 12,
              height: 12,
              errorBuilder: (_, __, ___) => Icon(_getSuitIcon(), color: color, size: 12),
            );
      } else {
        suitWidget = Icon(_getSuitIcon(), color: color, size: 12);
      }
    } else {
      suitWidget = Icon(_getSuitIcon(), color: color, size: 12);
    }

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
                Text(rankText, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                suitWidget,
              ],
            ),
          ),
          // Center Large Suit (Only if not a face item with illustration)
          if (!isFaceItem)
            Center(
              child: Opacity(
                opacity: 0.35,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Builder(
                    builder: (context) {
                      String suitKey = card.suit.name;
                      if (card.suit == game_card.Suit.clubs && customSuitIcons?.containsKey('trifle') == true) {
                        suitKey = 'trifle';
                      }
                      
                      final suitPath = customSuitIcons?[suitKey];
                      if (suitPath != null) {
                        return suitPath.startsWith('http')
                          ? Image.network(
                              suitPath,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(_getSuitIcon(), color: color, size: 40),
                            )
                          : Image.asset(
                              suitPath,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(_getSuitIcon(), color: color, size: 40),
                            );
                      }
                      return Icon(_getSuitIcon(), color: color, size: 40);
                    },
                  ),
                ),
              ),
            ),
          // Bottom Right Rank (inverted)
          Positioned(
            bottom: 0,
            right: 0,
            child: RotatedBox(
              quarterTurns: 2,
              child: Column(
                children: [
                  Text(rankText, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                  suitWidget,
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
