import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/home/presentation/providers/store_provider.dart';

void main() {
  test('existing default ID previews the equipped Lantern table at no cost', () {
    final table = defaultTableSkin();
    expect(table.id, 'default_table');
    expect(table.assetPath, lanternTableAsset);
    expect(File(table.assetPath).existsSync(), isTrue);
    expect(table.price, 0); expect(table.diamondPrice, 0);
  });
  test('table fallback never resolves to a card back and preserves selections', () {
    final chosen = ShopItem(id: 'owned_table', name: 'Owned', assetPath: 'owned.png',
      type: ShopItemType.tableSkin);
    final items = [ShopItem(id: 'card', name: 'Card', assetPath: 'back.png',
      type: ShopItemType.cardBack), chosen, defaultTableSkin()];
    expect(resolveTableSkin(items, chosen.id), same(chosen));
    expect(resolveTableSkin(items, 'removed_table').id, 'default_table');
    expect(resolveTableSkin(items, 'card').type, ShopItemType.tableSkin);
  });
  test('every built-in theme and card illustration exists and IDs are unique', () {
    final items = StoreNotifier.builtinItems;
    expect(items.map((item) => item.id).toSet().length, items.length);
    for (final item in items) {
      for (final asset in [item.assetPath, item.frontSkinPath, item.aceSkinPath,
        item.sevenDiamondSkinPath, ...?item.faceIllustrations?.values,
        ...?item.suitIcons?.values].whereType<String>()) {
        expect(File(asset).existsSync(), isTrue, reason: '${item.id}: $asset');
      }
    }
  });
  test('card-back selection is typed and preserves an owned skin', () {
    final cards = StoreNotifier.builtinItems.where((item) => item.type == ShopItemType.cardBack).toList();
    final items = [defaultTableSkin(), ...cards];
    expect(resolveCardBack(items, 'neon_card').id, 'neon_card');
    expect(resolveCardBack(items, 'default_table').id, 'default_card');
    expect(resolveCardBack([], 'removed_card').id, 'default_card');
  });
}
