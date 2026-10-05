import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/core/widgets/lantern_panel.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as game;
import 'package:halabessa/features/game/presentation/widgets/card_widget.dart';
import 'package:halabessa/features/game/presentation/widgets/lantern_card_art.dart';
import 'package:halabessa/features/home/presentation/providers/store_provider.dart';
import 'package:halabessa/features/home/presentation/widgets/shop_card_artwork.dart';

void main() {
  final defaultItem = ShopItem(
    id: 'default_card',
    name: 'Default',
    assetPath: 'legacy-green-back.png',
    type: ShopItemType.cardBack,
    frontSkinPath: 'legacy-front.png',
  );
  for (final faceUp in [false, true]) {
    testWidgets('default preview uses gameplay lantern art, faceUp=$faceUp', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShopCardArtwork(item: defaultItem, faceUp: faceUp),
          ),
        ),
      );
      final art = tester.widget<LanternCardArt>(find.byType(LanternCardArt));
      expect(art.faceUp, faceUp);
      expect(find.byType(CardWidget), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('custom preview pins all artwork to the requested item', (
    tester,
  ) async {
    final item = ShopItem(
      id: 'custom-deck',
      name: 'Custom',
      assetPath: 'custom-back.png',
      frontSkinPath: 'custom-front.png',
      aceSkinPath: 'custom-ace.png',
      sevenDiamondSkinPath: 'custom-seven.png',
      faceIllustrations: {'king': 'custom-king.png'},
      suitIcons: {'spades': 'custom-spade.png'},
      type: ShopItemType.cardBack,
    );
    late Widget rendered;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            // Inspect the preview's output without instantiating backend providers.
            rendered = ShopCardArtwork(
              item: item,
              card: const game.Card(game.Suit.hearts, game.Rank.king),
              faceUp: true,
            ).build(context);
            return const SizedBox();
          },
        ),
      ),
    );
    final card = rendered as CardWidget;
    expect(card.skinId, item.id);
    expect(card.customBackPath, item.assetPath);
    expect(card.customFrontPath, item.frontSkinPath);
    expect(card.customAceSkinPath, item.aceSkinPath);
    expect(card.customSevenDiamondSkinPath, item.sevenDiamondSkinPath);
    expect(card.faceIllustrations, item.faceIllustrations);
    expect(card.customSuitIcons, item.suitIcons);
    expect(card.isFaceUp, isTrue);
  });
  testWidgets('ivory panel supports a narrow RTL layout', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: SizedBox(
              width: 280,
              child: LanternPanel(
                selected: true,
                padding: EdgeInsets.all(16),
                child: Text('حلبسه'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('حلبسه'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
