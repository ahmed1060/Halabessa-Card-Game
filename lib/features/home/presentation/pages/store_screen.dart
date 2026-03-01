import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';
import '../../../../core/services/multimedia_service.dart';
import '../../../../core/theme/theme_config.dart';
import '../providers/store_provider.dart';
import '../widgets/admin_add_item_dialog.dart';

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
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: ThemeConfig.goldAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ThemeConfig.goldAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars, color: ThemeConfig.goldAccent, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      user.isAdmin ? '∞' : user.points.toString(),
                      style: TextStyle(
                        color: ThemeConfig.goldAccent, 
                        fontWeight: FontWeight.bold,
                        fontSize: user.isAdmin ? 20 : 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          _buildSectionHeader(context, 'card_skins'.tr(), ShopItemType.cardBack, user, notifier),
          _buildSkinGrid(context, notifier, store, ShopItemType.cardBack, user),
          _buildSectionHeader(context, 'table_skins'.tr(), ShopItemType.tableSkin, user, notifier),
          _buildSkinGrid(context, notifier, store, ShopItemType.tableSkin, user),
          _buildSectionHeader(context, 'avatars_label'.tr(), ShopItemType.avatar, user, notifier),
          _buildSkinGrid(context, notifier, store, ShopItemType.avatar, user),
          _buildSectionHeader(context, 'items_label'.tr(), ShopItemType.consumable, user, notifier),
          _buildSkinGrid(context, notifier, store, ShopItemType.consumable, user),
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

  Widget _buildSkinGrid(BuildContext context, StoreNotifier notifier, StoreState store, ShopItemType type, AppUser? user) {
    final items = notifier.allItems.where((i) => i.type == type).toList();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = items[index];
            final isOwned = item.type == ShopItemType.consumable ? false : store.ownedIds.contains(item.id);
            final isActive = (type == ShopItemType.cardBack) 
                ? store.activeCardBackId == item.id 
                : (type == ShopItemType.tableSkin ? store.activeTableSkinId == item.id : false);

            return _buildStoreItem(context, item, isOwned, isActive, user, () async {
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
                  notifier.setActiveSkin(item.id, type);
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
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            }, onDelete: () => notifier.deleteItem(item.id));
          },
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _buildStoreItem(BuildContext context, ShopItem item, bool isOwned, bool isActive, AppUser? user, VoidCallback onTap, {required VoidCallback onDelete}) {
    String statusText = item.price > 0 ? '${item.price} ⭐' : 'status_free'.tr();
    if (isActive) {
      statusText = 'status_active'.tr();
    } else if (isOwned) {
      statusText = 'status_owned'.tr();
    } else if (item.type == ShopItemType.consumable) {
      statusText = '${item.price} ⭐';
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive ? ThemeConfig.goldAccent : (isOwned ? Colors.white24 : Colors.white10),
                width: isActive ? 1.5 : 1,
              ),
              boxShadow: [
                if (isActive)
                  BoxShadow(color: ThemeConfig.goldAccent.withOpacity(0.15), blurRadius: 8, spreadRadius: 1),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: item.assetPath.startsWith('http') 
                        ? Image.network(
                            item.assetPath,
                            fit: (item.type == ShopItemType.cardBack || item.type == ShopItemType.avatar) ? BoxFit.contain : BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white24, size: 30),
                          )
                        : Image.asset(
                            item.assetPath,
                            fit: (item.type == ShopItemType.cardBack || item.type == ShopItemType.avatar) ? BoxFit.contain : BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => const Icon(Icons.style, color: Colors.white24, size: 30),
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
                        style: const TextStyle(fontFamily: ThemeConfig.fontHeading, fontSize: 13, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isActive ? ThemeConfig.goldAccent : (isOwned ? Colors.teal.withOpacity(0.2) : Colors.white10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontFamily: ThemeConfig.fontBody,
                            fontSize: 9, 
                            fontWeight: FontWeight.bold,
                            color: isActive ? Colors.black : (isOwned ? Colors.teal : Colors.white38),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (user?.isAdmin == true)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete, color: Colors.white, size: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
