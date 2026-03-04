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
  bool _isFlipped = false;

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
              child: SingleChildScrollView(
                child: Column(
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
                    widget.isOwned ? 'Equip Now' : (item.diamondPrice > 0 ? 'Buy for ${item.diamondPrice} 💎' : 'Buy for ${item.price} ⭐'),
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
    return Column(
      children: [
        const Text('Tap to Flip', style: TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => setState(() => _isFlipped = !_isFlipped),
          child: TweenAnimationBuilder(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            tween: Tween<double>(begin: 0, end: _isFlipped ? 180 : 0),
            builder: (context, double value, child) {
              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(value * 0.0174533),
                alignment: Alignment.center,
                child: value >= 90
                    ? RotatedBox(
                        quarterTurns: 2,
                        child: _buildFrontPreview(),
                      )
                    : _buildBackPreview(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBackPreview() {
    return Center(
      child: Container(
        width: 180,
        height: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5)],
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

  Widget _buildFrontPreview() {
    // Show a King or Ace as the front preview
    final previewCard = game_models.Card(game_models.Suit.hearts, game_models.Rank.king);
    return Center(
      child: CardWidget(
        card: previewCard,
        width: 180,
        height: 260,
        isFaceUp: true,
        customFrontPath: widget.item.frontSkinPath,
        faceIllustrations: widget.item.faceIllustrations,
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
          const Text('Custom Suit Set', style: TextStyle(color: ThemeConfig.goldAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: suits.entries.map((e) {
              return Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(e.value, width: 40, height: 40, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 4),
                  Text(e.key.toUpperCase(), style: const TextStyle(color: Colors.white30, fontSize: 10)),
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
