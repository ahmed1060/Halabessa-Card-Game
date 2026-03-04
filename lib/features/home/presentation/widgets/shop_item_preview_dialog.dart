import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as game_models;
import 'package:halabessa/features/game/presentation/widgets/card_widget.dart';
import '../providers/store_provider.dart';

class ShopItemPreviewDialog extends StatefulWidget {
  final ShopItem item;
  final bool isOwned;
  final VoidCallback onAction; // Purchase or Equip

  const ShopItemPreviewDialog({
    super.key,
    required this.item,
    required this.isOwned,
    required this.onAction,
  });

  @override
  State<ShopItemPreviewDialog> createState() => _ShopItemPreviewDialogState();
}

class _ShopItemPreviewDialogState extends State<ShopItemPreviewDialog> {
  final List<bool> _flipStates = [false, false, false, false, false]; // Ace, King, Back, Queen, Jack

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isSkin = item.type == ShopItemType.cardBack;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: ThemeConfig.darkBg.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: const TextStyle(fontFamily: ThemeConfig.fontHeading, fontSize: 24, color: Colors.white)),
                      Text(item.type.name.tr(), style: TextStyle(color: Colors.white54, fontSize: 14)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Main Preview (Card or Table)
                      if (isSkin)
                        _buildCardPreview()
                      else if (item.type == ShopItemType.tableSkin)
                        _buildTablePreview()
                      else
                        _buildGenericPreview(),
  
                      const SizedBox(height: 30),
  
                      // Suit Showcase (if applicable)
                      if (isSkin && item.suitIcons != null) _buildSuitShowcase(),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Action
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeConfig.primaryTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 8,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onAction();
                  },
                  child: Text(
                    widget.isOwned ? 'status_active'.tr() : (item.diamondPrice > 0 ? 'buy_for'.tr() + ' ${item.diamondPrice} 💎' : 'buy_for'.tr() + ' ${item.price} ⭐'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardPreview() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFlippableCard(0, game_models.Suit.spades, game_models.Rank.ace),
          const SizedBox(width: 16),
          _buildFlippableCard(1, game_models.Suit.hearts, game_models.Rank.king),
          const SizedBox(width: 16),
          _buildFlippableCard(2, null, null, isMiddle: true),
          const SizedBox(width: 16),
          _buildFlippableCard(3, game_models.Suit.clubs, game_models.Rank.queen),
          const SizedBox(width: 16),
          _buildFlippableCard(4, game_models.Suit.diamonds, game_models.Rank.jack),
        ],
      ),
    );
  }

  Widget _buildFlippableCard(int index, game_models.Suit? suit, game_models.Rank? rank, {bool isMiddle = false}) {
    return GestureDetector(
      onTap: () => setState(() => _flipStates[index] = !_flipStates[index]),
      child: TweenAnimationBuilder(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        tween: Tween<double>(begin: 0, end: _flipStates[index] ? 180 : 0),
        builder: (context, double value, child) {
          final isBackVisible = value >= 90;
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(value * 0.0174533),
            alignment: Alignment.center,
            child: isBackVisible 
              ? Transform.scale(
                  scaleX: -1, 
                  child: _buildFaceOrBack(index, suit, rank, isMiddle, true),
                )
              : _buildFaceOrBack(index, suit, rank, isMiddle, false),
          );
        },
      ),
    );
  }

  Widget _buildFaceOrBack(int index, game_models.Suit? suit, game_models.Rank? rank, bool isMiddle, bool isBackVisible) {
    // Determine what to show on each side
    if (isMiddle) {
      // Middle Card: Back -> 7 Diamonds
      return isBackVisible 
        ? _buildPreviewCard(game_models.Suit.diamonds, game_models.Rank.seven) 
        : _buildBackPreviewOnly();
    } else {
      // Side Cards: Front -> Back
      return isBackVisible 
        ? _buildBackPreviewOnly()
        : _buildPreviewCard(suit!, rank!);
    }
  }

  Widget _buildPreviewCard(game_models.Suit suit, game_models.Rank rank) {
    return CardWidget(
      card: game_models.Card(suit, rank),
      width: 100,
      height: 150,
      isFaceUp: true,
      customFrontPath: widget.item.frontSkinPath,
      customAceSkinPath: widget.item.aceSkinPath,
      customSevenDiamondSkinPath: widget.item.sevenDiamondSkinPath,
      faceIllustrations: widget.item.faceIllustrations,
    );
  }

  Widget _buildBackPreviewOnly() {
    return Container(
      width: 100,
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 15, offset: const Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: widget.item.assetPath.startsWith('http')
            ? Image.network(widget.item.assetPath, fit: BoxFit.cover)
            : Image.asset(widget.item.assetPath, fit: BoxFit.cover),
      ),
    );
  }



  Widget _buildSuitShowcase() {
    final suits = widget.item.suitIcons!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('custom_suit_set'.tr(), style: const TextStyle(color: ThemeConfig.goldAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: suits.entries.map((e) {
              String label = e.key.toUpperCase();
              String iconPath = e.value;
              
              return Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: iconPath.startsWith('http')
                      ? Image.network(iconPath, width: 40, height: 40, fit: BoxFit.contain)
                      : Image.asset(iconPath, width: 40, height: 40, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 4),
                  Text(label, style: const TextStyle(color: Colors.white30, fontSize: 10)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTablePreview() {
    return Center(
      child: Container(
        width: 300,
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: widget.item.assetPath.startsWith('http')
              ? Image.network(widget.item.assetPath, fit: BoxFit.cover)
              : Image.asset(widget.item.assetPath, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _buildGenericPreview() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: widget.item.assetPath.startsWith('http')
            ? Image.network(widget.item.assetPath, width: 150, height: 150, fit: BoxFit.contain)
            : Image.asset(widget.item.assetPath, width: 150, height: 150, fit: BoxFit.contain),
      ),
    );
  }
}
