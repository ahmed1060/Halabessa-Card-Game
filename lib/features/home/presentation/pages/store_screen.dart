import 'package:halabessa/core/widgets/lantern_page_frame.dart';
import 'dart:ui' as ui;
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
import '../../../../core/widgets/lantern_navigation_dock.dart';

class StoreScreen extends ConsumerStatefulWidget {
  final bool initialOwnedOnly;
  const StoreScreen({super.key, this.initialOwnedOnly = false});
  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  bool _ownedOnly = false;
  int _featuredIndex = 0;
  final Set<String> _pendingItems = {};
  @override
  void initState() {
    super.initState();
    _ownedOnly = widget.initialOwnedOnly;
  }

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
          bottomNavigationBar: const LanternNavigationDock(
            selected: LanternDestination.collection,
          ),
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
                          if (!_ownedOnly && entry.$1 == ShopItemType.cardBack)
                            _buildFeaturedDecks(context, notifier, store, user),
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
            () => _activateItem(context, item, isOwned, notifier),
            onDelete: () => notifier.deleteItem(item.id),
          );
        }, childCount: items.length),
      ),
    );
  }

  Future<void> _activateItem(
    BuildContext context,
    ShopItem item,
    bool isOwned,
    StoreNotifier notifier,
  ) async {
    if (_pendingItems.contains(item.id)) return;
    setState(() => _pendingItems.add(item.id));
    try {
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
    } finally {
      if (mounted) setState(() => _pendingItems.remove(item.id));
    }
  }

  Widget _buildFeaturedDecks(
    BuildContext context,
    StoreNotifier notifier,
    StoreState store,
    AppUser? user,
  ) {
    final items = notifier.allItems
        .where((item) => item.type == ShopItemType.cardBack)
        .toList();
    if (items.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 660),
          child: Column(
            children: [
              SizedBox(
                height: 330,
                child: PageView.builder(
                  itemCount: items.length,
                  onPageChanged: (index) =>
                      setState(() => _featuredIndex = index),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final owned = store.ownedIds.contains(item.id);
                    final active = store.activeCardBackId == item.id;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: TableStyle.felt,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: TableStyle.brass.withValues(alpha: .5),
                          ),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(
                                'ui_featured'.tr(),
                                style: TableStyle.detail,
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 155,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  textDirection: ui.TextDirection.ltr,
                                  children: [
                                    Transform.rotate(
                                      angle: -.1,
                                      child: ShopCardArtwork(
                                        item: item,
                                        width: 92,
                                        height: 136,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Transform.rotate(
                                      angle: .06,
                                      child: ShopCardArtwork(
                                        item: item,
                                        faceUp: true,
                                        width: 92,
                                        height: 136,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                item.name,
                                textAlign: TextAlign.center,
                                style: TableStyle.label.copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: active
                                      ? TableStyle.mint
                                      : TableStyle.brass,
                                  foregroundColor: TableStyle.ink,
                                  minimumSize: const Size.fromHeight(48),
                                ),
                                onPressed:
                                    active || _pendingItems.contains(item.id)
                                    ? null
                                    : () => _activateItem(
                                        context,
                                        item,
                                        owned,
                                        notifier,
                                      ),
                                icon: Icon(
                                  active
                                      ? Icons.check_circle_rounded
                                      : owned
                                      ? Icons.style_rounded
                                      : Icons.shopping_bag_outlined,
                                ),
                                label: Text(
                                  active
                                      ? 'status_active'.tr()
                                      : owned
                                      ? 'ui_equip'.tr()
                                      : '${item.diamondPrice > 0 ? item.diamondPrice : item.price} ${item.diamondPrice > 0 ? '💎' : '🪙'}',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < items.length; i++)
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.circle,
                        size: 8,
                        color: i == _featuredIndex
                            ? TableStyle.brass
                            : TableStyle.muted,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
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
            dark: _ownedOnly,
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
                                  return FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      textDirection: ui.TextDirection.ltr,
                                      children: [
                                        ShopCardArtwork(
                                          item: item,
                                          width: height * .6,
                                          height: height,
                                        ),
                                        const SizedBox(width: 6),
                                        ShopCardArtwork(
                                          item: item,
                                          faceUp: true,
                                          width: height * .6,
                                          height: height,
                                        ),
                                      ],
                                    ),
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
                        style: TextStyle(
                          fontFamily: ThemeConfig.fontHeading,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _ownedOnly ? TableStyle.ivory : TableStyle.ink,
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
