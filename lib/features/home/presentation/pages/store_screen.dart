import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/theme_config.dart';
import '../providers/store_provider.dart';

class StoreScreen extends ConsumerWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final notifier = ref.read(storeProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Halabessa Store', style: GoogleFonts.righteous(letterSpacing: 1.5)),
      ),
      body: CustomScrollView(
        slivers: [
          _buildSectionHeader('Card Skins'),
          _buildSkinGrid(context, notifier, store, ShopItemType.cardBack),
          _buildSectionHeader('Table Skins'),
          _buildSkinGrid(context, notifier, store, ShopItemType.tableSkin),
          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        child: Text(
          title,
          style: GoogleFonts.righteous(fontSize: 22, color: ThemeConfig.goldAccent),
        ),
      ),
    );
  }

  Widget _buildSkinGrid(BuildContext context, StoreNotifier notifier, StoreState store, ShopItemType type) {
    final items = StoreNotifier.allItems.where((i) => i.type == type).toList();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          childAspectRatio: 0.85,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = items[index];
            final isOwned = store.ownedIds.contains(item.id);
            final isActive = (type == ShopItemType.cardBack) 
                ? store.activeCardBackId == item.id 
                : store.activeTableSkinId == item.id;

            return _buildStoreItem(context, item, isOwned, isActive, () {
              if (isOwned) {
                notifier.setActiveSkin(item.id, type);
              } else {
                notifier.purchaseItem(item.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${item.name} unlocked!')),
                );
              }
            });
          },
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _buildStoreItem(BuildContext context, ShopItem item, bool isOwned, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive ? ThemeConfig.goldAccent : (isOwned ? Colors.white24 : Colors.white10),
            width: isActive ? 2 : 1,
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(color: ThemeConfig.goldAccent.withOpacity(0.2), blurRadius: 10, spreadRadius: 1),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    item.assetPath,
                    fit: item.type == ShopItemType.cardBack ? BoxFit.contain : BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  Text(
                    item.name,
                    style: GoogleFonts.righteous(fontSize: 16, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? ThemeConfig.goldAccent : (isOwned ? Colors.teal.withOpacity(0.2) : Colors.white10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isActive ? 'ACTIVE' : (isOwned ? 'OWNED' : 'FREE'),
                      style: GoogleFonts.outfit(
                        fontSize: 10, 
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
    );
  }
}
