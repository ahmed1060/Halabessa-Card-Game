import 'package:halabessa/core/widgets/lantern_page_frame.dart';
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
import '../widgets/shop_card_artwork.dart';
import '../../../../core/widgets/lantern_panel.dart';
import '../../../game/presentation/widgets/table_style.dart';

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});
  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  bool _ownedOnly = false;
  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final notifier = ref.read(storeProvider.notifier);

    final user = ref.watch(currentUserProvider);

    return DefaultTabController(
      length: 4,
      child: LanternPageFrame(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            toolbarHeight: 110,
            centerTitle: true,
            title: LanternPageTitle(
              title: (_ownedOnly ? 'inventory_title' : 'store_title').tr(),
            ),
            bottom: TabBar(
              isScrollable: true,
              labelColor: TableStyle.ink,
              unselectedLabelColor: TableStyle.ivory,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: TableStyle.brass,
                borderRadius: BorderRadius.circular(24),
              ),
              tabs: [
                Tab(text: 'card_skins'.tr()),
                Tab(text: 'table_skins'.tr()),
                Tab(text: 'avatars_label'.tr()),
                Tab(text: 'store_consumables'.tr()),
              ],
            ),
          ),
          body: Column(
            children: [
              if (user != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _buildCurrencyChip(
                        context,
                        user.coins,
                        '🪙',
                        TableStyle.brass,
                        isAdmin: user.isAdmin,
                      ),
                      _buildCurrencyChip(
                        context,
                        user.diamonds,
                        '💎',
                        TableStyle.mint,
                        isAdmin: user.isAdmin,
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SegmentedButton<bool>(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? TableStyle.mint
                          : TableStyle.ink,
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? TableStyle.ink
                          : TableStyle.ivory,
                    ),
                    side: const WidgetStatePropertyAll(
                      BorderSide(color: TableStyle.mint),
                    ),
                  ),
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text('store_title'.tr()),
                      icon: const Icon(Icons.shopping_bag_outlined),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('inventory_title'.tr()),
                      icon: const Icon(Icons.inventory_2_outlined),
                    ),
                  ],
                  selected: {_ownedOnly},
                  onSelectionChanged: (selection) =>
                      setState(() => _ownedOnly = selection.first),
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    for (final entry in [
                      (ShopItemType.cardBack, 'card_skins'),
                      (ShopItemType.tableSkin, 'table_skins'),
                      (ShopItemType.avatar, 'avatars_label'),
                      (ShopItemType.consumable, 'store_consumables'),
                    ])
                      CustomScrollView(
                        slivers: [
                          _buildSectionHeader(
                            context,
                            entry.$2.tr(),
                            entry.$1,
                            user,
                            notifier,
                          ),
                          _buildSkinGrid(
                            context,
                            ref,
                            notifier,
                            store,
                            entry.$1,
                            user,
                          ),
                          const SliverPadding(
                            padding: EdgeInsets.only(bottom: 40),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    ShopItemType type,
    AppUser? user,
    StoreNotifier notifier,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: ThemeConfig.fontHeading,
                fontSize: 22,
                color: ThemeConfig.goldAccent,
              ),
            ),
            if (user?.isAdmin == true)
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: ThemeConfig.primaryTeal,
                ),
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

  Widget _buildSkinGrid(
    BuildContext context,
    WidgetRef ref,
    StoreNotifier notifier,
    StoreState store,
    ShopItemType type,
    AppUser? user,
  ) {
    final items = notifier.allItems
        .where(
          (i) =>
              i.type == type && (!_ownedOnly || store.ownedIds.contains(i.id)),
        )
        .toList();

    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.white30,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'no_items_available'.tr(),
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final int crossAxisCount = screenWidth < 500
        ? 2
        : (screenWidth < 850 ? 3 : 4);
    final double childAspectRatio = screenWidth < 500
        ? 0.78
        : (screenWidth < 850 ? 0.72 : 0.66);

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = items[index];
          final isOwned = item.type == ShopItemType.consumable
              ? false
              : store.ownedIds.contains(item.id);
          final isActive = (type == ShopItemType.cardBack)
              ? store.activeCardBackId == item.id
              : (type == ShopItemType.tableSkin
                    ? store.activeTableSkinId == item.id
                    : false);

          return _buildStoreItem(
            context,
            ref,
            item,
            isOwned,
            isActive,
            user,
            () async {
              try {
                if (item.type == ShopItemType.consumable) {
                  await notifier.purchaseItem(item);
                  if (context.mounted) {
                    ref
                        .read(multimediaServiceProvider)
                        .playSfx('sfx/purchase.mp3');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('item_unlocked'.tr(args: [item.name])),
                      ),
                    );
                  }
                } else if (isOwned) {
                  notifier.setActiveSkin(item.id, item.type);
                } else {
                  await notifier.purchaseItem(item);
                  if (context.mounted) {
                    ref
                        .read(multimediaServiceProvider)
                        .playSfx('sfx/purchase.mp3');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('item_unlocked'.tr(args: [item.name])),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  final errorStr = e.toString();
                  final message = errorStr.contains('diamonds')
                      ? 'not_enough_diamonds'.tr()
                      : (errorStr.contains('coins')
                            ? 'not_enough_coins'.tr()
                            : errorStr.replaceAll('Exception: ', ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.red.shade900,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      content: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.amberAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              message,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              }
            },
            onDelete: () => notifier.deleteItem(item.id),
          );
        }, childCount: items.length),
      ),
    );
  }

  Widget _buildStoreItem(
    BuildContext context,
    WidgetRef ref,
    ShopItem item,
    bool isOwned,
    bool isActive,
    AppUser? user,
    VoidCallback onTap, {
    required VoidCallback onDelete,
  }) {
    String statusText = item.price > 0
        ? '${item.price} 🪙'
        : 'status_free'.tr();
    final isDiamonds = item.diamondPrice > 0;
    final priceStr = isDiamonds
        ? '${item.diamondPrice} 💎'
        : '${item.price} 🪙';

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
          LanternPanel(
            selected: isActive,
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
                        child: item.type == ShopItemType.cardBack
                            ? LayoutBuilder(
                                builder: (context, bounds) {
                                  final height = bounds.maxHeight.clamp(
                                    0.0,
                                    180.0,
                                  );
                                  return ShopCardArtwork(
                                    item: item,
                                    width: height * .7,
                                    height: height,
                                  );
                                },
                              )
                            : item.assetPath.startsWith('http')
                            ? Image.network(
                                item.assetPath,
                                fit:
                                    (item.type == ShopItemType.cardBack ||
                                        item.type == ShopItemType.avatar)
                                    ? BoxFit.contain
                                    : BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.broken_image,
                                  color: Colors.white24,
                                  size: 32,
                                ),
                              )
                            : Image.asset(
                                item.assetPath,
                                fit:
                                    (item.type == ShopItemType.cardBack ||
                                        item.type == ShopItemType.avatar)
                                    ? BoxFit.contain
                                    : BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.style,
                                  color: Colors.white24,
                                  size: 32,
                                ),
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
                          color: TableStyle.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? TableStyle.brass
                              : (isOwned ? TableStyle.mint : TableStyle.ink),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isActive
                                ? ThemeConfig.goldAccent
                                : (isOwned
                                    ? Colors.teal.withValues(alpha: 0.4)
                                      : Colors.white12),
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
                            color: isActive
                                ? TableStyle.ink
                                : (isOwned ? TableStyle.ink : TableStyle.ivory),
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
                      builder: (c) => AdminAddItemDialog(
                        type: item.type,
                        initialItem: item,
                      ),
                    );
                    if (updated != null) {
                      ref.read(storeProvider.notifier).updateItem(updated);
                    }
                  }),
                  const SizedBox(width: 4),
                  _buildMiniAction(
                    Icons.delete_outline,
                    onDelete,
                    isDelete: true,
                  ),
                ],
                if (item.type == ShopItemType.cardBack ||
                    item.type == ShopItemType.tableSkin) ...[
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

  Widget _buildCurrencyChip(
    BuildContext context,
    int amount,
    String symbol,
    Color color, {
    bool isAdmin = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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

  Widget _buildMiniAction(
    IconData icon,
    VoidCallback onTap, {
    bool isDelete = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: (isDelete ? Colors.red : Colors.black).withValues(alpha: 0.7),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 0.8),
        ),
        child: Icon(icon, color: Colors.white, size: 13),
      ),
    );
  }
}
