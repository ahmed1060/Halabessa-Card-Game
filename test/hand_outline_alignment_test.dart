import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as game;
import 'package:halabessa/features/game/presentation/widgets/fanned_hand_widget.dart';
import 'package:halabessa/features/game/presentation/widgets/hand_card_placement.dart';
import 'package:halabessa/features/game/presentation/widgets/lantern_card_art.dart';
import 'package:halabessa/features/game/presentation/widgets/table_style.dart';

void main() {
  const cards = [
    game.Card(game.Suit.clubs, game.Rank.six),
    game.Card(game.Suit.diamonds, game.Rank.nine),
    game.Card(game.Suit.clubs, game.Rank.ace),
    game.Card(game.Suit.spades, game.Rank.eight),
  ];
  for (final direction in TextDirection.values) {
    testWidgets(
      'queued outline follows the same card silhouette and rotation $direction',
      (tester) async {
        final imageKey = GlobalKey();
        if (Platform.environment['HALABESSA_RENDER_HAND_QA'] == '1') {
          await tester.runAsync(() async {
            final font = FontLoader('LanternDisplay')
              ..addFont(rootBundle.load('assets/fonts/Righteous-Regular.ttf'));
            await font.load();
          });
        }
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: direction,
              child: Scaffold(
                backgroundColor: TableStyle.felt,
                body: Center(
                  child: RepaintBoundary(
                    key: imageKey,
                    child: SizedBox(
                      width: 440,
                      height: 230,
                      child: ColoredBox(
                        color: TableStyle.felt,
                        child: FannedHandWidget(
                          cards: cards,
                          onCardTap: (_, __) {},
                          cardBuilder: (card, width, height) => LanternCardArt(
                            key: ValueKey('face-${card.firebaseKey}'),
                            card: card,
                            faceUp: true,
                            width: width,
                            height: height,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('hand-card-clubs_six')));
        await tester.pumpAndSettle();
        final face = find.byKey(const ValueKey('face-clubs_six'));
        final outline = find.byKey(const ValueKey('hand-outline-clubs_six'));
        final rotation = find.byKey(const ValueKey('hand-art-angle-clubs_six'));
        expect(find.descendant(of: rotation, matching: face), findsOneWidget);
        if (cardUiRefinements) {
          expect(
            outline,
            findsNothing,
            reason: 'queue pose replaces the gold rim',
          );
        } else {
          expect(
            find.descendant(of: rotation, matching: outline),
            findsOneWidget,
          );
          expect(tester.getRect(outline), tester.getRect(face));
          final decoration =
              tester.widget<DecoratedBox>(outline).decoration as BoxDecoration;
          final size = tester.getSize(face);
          expect(
            decoration.borderRadius,
            BorderRadius.all(
              Radius.elliptical(size.width * .1, size.height * .07),
            ),
          );
        }
        // Optional review artifact, not a baseline that can hide a regression.
        if (Platform.environment['HALABESSA_RENDER_HAND_QA'] == '1') {
          await tester.runAsync(() async {
            final boundary =
                imageKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File('build/qa/hand-outline-${direction.name}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
