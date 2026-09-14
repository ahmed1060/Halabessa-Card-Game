import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';
import '../../../../core/services/multimedia_service.dart';
import '../../../../core/theme/theme_config.dart';
import '../providers/store_provider.dart';
import '../widgets/admin_add_item_dialog.dart';
import '../widgets/shop_item_preview_dialog.dart';

class StoreScreen extends ConsumerWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final notifier = ref.read(storeProvider.notifier);

    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('store_title'.tr(), style: const TextStyle(fontFamily: ThemeConfig.fontHeading, letterSpacing: 1.5)),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildCurrencyChip(context, user.coins, '🪙', Colors.orange, isAdmin: user.isAdmin),
                  const SizedBox(width: 8),
                  _buildCurrencyChip(context, user.diamonds, '💎', ThemeConfig.primaryTeal, isAdmin: user.isAdmin),
                ],
              ),
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          _buildSectionHeader(context, 'card_skins'.tr(), ShopItemType.cardBack, user, notifier),
          _buildSkinGrid(context, ref, notifier, store, ShopItemType.cardBack, user),
          _buildSectionHeader(context, 'table_skins'.tr(), ShopItemType.tableSkin, user, notifier),
          _buildSkinGrid(context, ref, notifier, store, ShopItemType.tableSkin, user),
          _buildSectionHeader(context, 'avatars_label'.tr(), ShopItemType.avatar, user, notifier),
          _buildSkinGrid(context, ref, notifier, store, ShopItemType.avatar, user),
          _buildSectionHeader(context, 'store_consumables'.tr(), ShopItemType.consumable, user, notifier),
          _buildSkinGrid(context, ref, notifier, store, ShopItemType.consumable, user),
          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, ShopItemType type, AppUser? user, StoreNotifier notifier) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontFamily: ThemeConfig.fontHeading, fontSize: 22, color: ThemeConfig.goldAccent),
            ),
            if (user?.isAdmin == true)
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: ThemeConfig.primaryTeal),
                onPressed: () async {
                  final newItem = await showDialog<ShopItem>(
                    context: context,
                    builder: (context) => AdminAddItemDialog(type: type),
                  );
                  if (newItem != null) {
                    await notifier.addItem(newItem);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkinGrid(BuildContext context, WidgetRef ref, StoreNotifier notifier, StoreState store, ShopItemType type, AppUser? user) {
    final items = notifier.allItems.where((i) => i.type == type).toList();

    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inventory_2_outlined, color: Colors.white30, size: 18),
                const SizedBox(width: 8),
                Text('no_items_available'.tr(), style: const TextStyle(color: Colors.white38, fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final int crossAxisCount = screenWidth < 500 ? 2 : (screenWidth < 850 ? 3 : 4);
    final double childAspectRatio = screenWidth < 500 ? 0.78 : (screenWidth < 850 ? 0.72 : 0.66);

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = items[index];
            final isOwned = item.type == ShopItemType.consumable ? false : store.ownedIds.contains(item.id);
            final isActive = (type == ShopItemType.cardBack) 
                ? store.activeCardBackId == item.id 
                : (type == ShopItemType.tableSkin ? store.activeTableSkinId == item.id : false);

            return _buildStoreItem(context, ref, item, isOwned, isActive, user, () async {
              try {
                if (item.type == ShopItemType.consumable) {
                  await notifier.purchaseItem(item);
                  if (context.mounted) {
                    ref.read(multimediaServiceProvider).playSfx('sfx/purchase.mp3');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('item_unlocked'.tr(args: [item.name]))),
                    );
                  }
                } else if (isOwned) {
                  notifier.setActiveSkin(item.id, item.type);
                } else {
                  await notifier.purchaseItem(item);
                  if (context.mounted) {
                    ref.read(multimediaServiceProvider).playSfx('sfx/purchase.mp3');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('item_unlocked'.tr(args: [item.name]))),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  final errorStr = e.toString();
                  final message = errorStr.contains('diamonds')
                      ? 'not_enough_diamonds'.tr()
                      : (errorStr.contains('coins') ? 'not_enough_coins'.tr() : errorStr.replaceAll('Exception: ', ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.red.shade900,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      content: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              message,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              }
            }, onDelete: () => notifier.deleteItem(item.id));
          },
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _buildStoreItem(BuildContext context, WidgetRef ref, ShopItem item, bool isOwned, bool isActive, AppUser? user, VoidCallback onTap, {required VoidCallback onDelete}) {
    String statusText = item.price > 0 ? '${item.price} 🪙' : 'status_free'.tr();
    final isDiamonds = item.diamondPrice > 0;
    final priceStr = isDiamonds ? '${item.diamondPrice} 💎' : '${item.price} 🪙';

    if (isActive) {
      statusText = 'status_active'.tr();
    } else if (isOwned) {
      statusText = 'status_owned'.tr();
    } else if (user?.isAdmin == true) {
      statusText = 'status_grant'.tr();
    } else if (item.type == ShopItemType.consumable) {
      statusText = priceStr;
    } else {
      statusText = priceStr;
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              color: const Color(0xFF131A26),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive 
                    ? ThemeConfig.goldAccent 
                    : (isOwned ? Colors.tealAccent.withOpacity(0.4) : Colors.white10),
                width: isActive ? 2 : 1,
              ),
              boxShadow: [
                if (isActive)
                  BoxShadow(color: ThemeConfig.goldAccent.withOpacity(0.25), blurRadius: 10, spreadRadius: 1)
                else if (isOwned)
                  BoxShadow(color: Colors.teal.withOpacity(0.1), blurRadius: 6),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        color: Colors.black26,
                        alignment: Alignment.center,
                        child: item.assetPath.startsWith('http') 
                          ? Image.network(
                              item.assetPath,
                              fit: (item.type == ShopItemType.cardBack || item.type == ShopItemType.avatar) ? BoxFit.contain : BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white24, size: 32),
                            )
                          : Image.asset(
                              item.assetPath,
                              fit: (item.type == ShopItemType.cardBack || item.type == ShopItemType.avatar) ? BoxFit.contain : BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) => const Icon(Icons.style, color: Colors.white24, size: 32),
                            ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Column(
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontFamily: ThemeConfig.fontHeading, 
                          fontSize: 13, 
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive 
                              ? ThemeConfig.goldAccent 
                              : (isOwned ? Colors.teal.withOpacity(0.2) : Colors.white10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isActive 
                                ? ThemeConfig.goldAccent 
                                : (isOwned ? Colors.teal.withOpacity(0.4) : Colors.white12),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          statusText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: ThemeConfig.fontBody,
                            fontSize: 11, 
                            fontWeight: FontWeight.bold,
                            color: isActive ? Colors.black : (isOwned ? Colors.tealAccent : Colors.white70),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Overlay Actions (Admin Edit/Delete & Preview)
          Positioned(
            top: 6,
            right: 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (user?.isAdmin == true) ...[
                  _buildMiniAction(Icons.edit, () async {
                    final updated = await showDialog<ShopItem>(
                      context: context,
                      builder: (c) => AdminAddItemDialog(type: item.type, initialItem: item),
                    );
                    if (updated != null) {
                      ref.read(storeProvider.notifier).updateItem(updated);
                    }
                  }),
                  const SizedBox(width: 4),
                  _buildMiniAction(Icons.delete_outline, onDelete, isDelete: true),
                ],
                if (item.type == ShopItemType.cardBack || item.type == ShopItemType.tableSkin) ...[
                  const SizedBox(width: 4),
                  _buildMiniAction(Icons.visibility_outlined, () {
                    showDialog(
                      context: context,
                      builder: (c) => ShopItemPreviewDialog(
                        item: item, 
                        isOwned: isOwned, 
                        onAction: onTap,
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyChip(BuildContext context, int amount, String symbol, Color color, {bool isAdmin = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(symbol, style: TextStyle(color: color, fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            isAdmin ? '∞' : amount.toString(),
            style: TextStyle(
              color: color, 
              fontWeight: FontWeight.bold,
              fontSize: isAdmin ? 18 : 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniAction(IconData icon, VoidCallback onTap, {bool isDelete = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: (isDelete ? Colors.red : Colors.black).withOpacity(0.7),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 0.8),
        ),
        child: Icon(icon, color: Colors.white, size: 13),
      ),
    );
  }
}
