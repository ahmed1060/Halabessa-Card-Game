import 'package:flutter/material.dart';
import '../../../game/domain/models/card.dart' as game;
import '../../../game/presentation/widgets/card_widget.dart';
import '../../../game/presentation/widgets/lantern_card_art.dart';
import '../providers/store_provider.dart';

/// Preview the requested item, never the currently equipped deck. The free
/// default uses the same vector renderer as gameplay, not its legacy asset.
class ShopCardArtwork extends StatelessWidget {
  final ShopItem item;
  final game.Card card;
  final bool faceUp;
  final double width;
  final double height;
  const ShopCardArtwork({
    super.key,
    required this.item,
    this.card = const game.Card(game.Suit.spades, game.Rank.ace),
    this.faceUp = false,
    this.width = 100,
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    if (item.id == 'default_card') {
      return LanternCardArt(
        card: card,
        faceUp: faceUp,
        width: width,
        height: height,
      );
    }
    return CardWidget(
      card: card,
      skinId: item.id,
      isFaceUp: faceUp,
      width: width,
      height: height,
      customBackPath: item.assetPath,
      customFrontPath: item.frontSkinPath,
      customAceSkinPath: item.aceSkinPath,
      customSevenDiamondSkinPath: item.sevenDiamondSkinPath,
      faceIllustrations: item.faceIllustrations,
      customSuitIcons: item.suitIcons,
    );
  }
}
