import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/core/services/asset_preloader_service.dart';
import 'package:halabessa/features/home/presentation/providers/store_provider.dart';

void main() {
  test(
    'Lantern startup does not decode the unused shop or old raster cards',
    () {
      final paths = startupImagePaths(
        landscape: true,
        table: defaultTableSkin(),
        cardBack: StoreNotifier.builtinItems.firstWhere(
          (item) => item.id == 'default_card',
        ),
      );
      expect(paths, {'assets/images/tables/lantern_nights_v1.png'});
    },
  );
  test('only selected card artwork and current orientation are warmed', () {
    final paths = startupImagePaths(
      landscape: false,
      table: defaultTableSkin(),
      cardBack: ShopItem(
        id: 'custom',
        name: '',
        type: ShopItemType.cardBack,
        assetPath: 'https://cdn.invalid/card.png',
        frontSkinPath: 'front.png',
        faceIllustrations: {'king': 'king.png'},
      ),
    );
    expect(
      paths,
      containsAll([
        'https://cdn.invalid/card.png',
        'front.png',
        'king.png',
        'assets/images/tables/lantern_nights_portrait_v2.png',
      ]),
    );
  });
  test('remote skins use NetworkImage rather than a missing AssetImage', () {
    expect(
      startupImageProvider('https://cdn.invalid/card.png'),
      isA<NetworkImage>(),
    );
    expect(startupImageProvider('assets/back.png'), isA<AssetImage>());
  });
}
