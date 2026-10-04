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
}
