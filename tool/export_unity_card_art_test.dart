// Explicit offline asset bake using the existing Flutter artwork, not new art.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as cards;
import 'package:halabessa/features/game/presentation/widgets/card_widget.dart';
import 'package:halabessa/features/home/presentation/providers/store_provider.dart';

void main() {
  testWidgets('bake existing built-in card artwork for Unity', (tester) async {
    // This opt-in Flutter test is tooling, never application initialization.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        storeProvider.overrideWith(
          (ref) => StoreNotifier(prefs, ref, listenRemote: false),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      final font = FontLoader('LanternDisplay')
        ..addFont(rootBundle.load('assets/fonts/Righteous-Regular.ttf'));
      await font.load();
      final text = FontLoader('LanternText')
        ..addFont(rootBundle.load('assets/fonts/Cairo.ttf'));
      await text.load();
    });
    final boundaryKey = GlobalKey();
    Future<void> render(
      cards.Card card,
      String skin,
      bool faceUp,
      String name,
    ) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeConfig.lightTheme,
            home: Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: CardWidget(
                  card: card,
                  skinId: skin,
                  isFaceUp: faceUp,
                  width: 70,
                  height: 100,
                ),
              ),
            ),
          ),
        ),
      );
      final context = boundaryKey.currentContext!;
      final item = StoreNotifier.builtinItems.firstWhere(
        (item) => item.id == skin,
      );
      final images = <String>{
        item.assetPath,
        if (item.frontSkinPath != null) item.frontSkinPath!,
        if (item.aceSkinPath != null) item.aceSkinPath!,
        if (item.sevenDiamondSkinPath != null) item.sevenDiamondSkinPath!,
        ...?item.faceIllustrations?.values,
        ...?item.suitIcons?.values,
        'assets/images/cards/lantern/jack_v1.png',
        'assets/images/cards/lantern/queen_v1.png',
        'assets/images/cards/lantern/king_v1.png',
      };
      await tester.runAsync(() async {
        for (final path in images) {
          await precacheImage(AssetImage(path), context);
        }
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 4);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final folder = Directory('build/unity-card-art/$skin');
        await folder.create(recursive: true);
        await File(
          '${folder.path}/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    for (final skin in ['default_card', 'neon_card', 'royal_card']) {
      for (final suit in cards.Suit.values) {
        for (final rank in cards.Rank.values) {
          final card = cards.Card(suit, rank);
          await render(card, skin, true, card.firebaseKey);
        }
      }
      await render(
        const cards.Card(cards.Suit.clubs, cards.Rank.ace),
        skin,
        false,
        'back',
      );
    }
    expect(
      Directory('build/unity-card-art')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.png')),
      hasLength(159),
    );
  }, skip: !const bool.fromEnvironment('EXPORT_UNITY_CARD_ART'));
}
