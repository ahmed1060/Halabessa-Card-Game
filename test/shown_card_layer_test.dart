import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as game;
import 'package:halabessa/features/game/domain/models/card_feature_state.dart';
import 'package:halabessa/features/game/presentation/widgets/shown_card_layer.dart';
import 'package:halabessa/features/game/presentation/widgets/option_b_table.dart';
import 'package:halabessa/features/game/presentation/widgets/board_card_motion.dart';
import 'package:halabessa/features/game/presentation/widgets/hand_card_placement.dart';

const seats = ['a', 'b', 'c', 'd'];
final copies = [
  for (var p = 0; p < 4; p++)
    for (var c = 0; c < 3; c++)
      ShownCard(
        seats[p],
        '$p:$c',
        game.Card(game.Suit.values[p], game.Rank.values[c]),
      ),
];

void main() {
  for (final viewport in [
    const Size(430, 740),
    const Size(430, 932),
    const Size(760, 430),
    const Size(900, 430),
    const Size(1004, 430),
    const Size(1433, 430),
  ]) {
    testWidgets(
      'twelve disclosed copies remain separate from board/hand at $viewport',
      (tester) async {
        final geometry = OptionBGeometry(viewport);
        var contacts = 0;
        Widget scene(List<ShownCard> cards) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: geometry.size.width,
                height: geometry.size.height,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ShownCardLayer(
                        cards: cards,
                        seats: seats,
                        localUid: 'a',
                        geometry: geometry,
                        faceBuilder: (_, w, h) => SizedBox(
                          width: w,
                          height: h,
                          child: const ColoredBox(color: Colors.white),
                        ),
                        backBuilder: (w, h) => SizedBox(width: w, height: h),
                        onContact: (_) => contacts++,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(scene(copies));
        await tester.pumpAndSettle();
        expect(contacts, 0, reason: 'reconnect/mount must be silent');
        final boxes = [
          for (final card in copies)
            tester.getRect(find.byKey(ValueKey('shown-${card.eventId}'))),
        ];
        final sceneOffset = tester.getTopLeft(find.byType(ShownCardLayer));
        for (final box in boxes) {
          final local = box.shift(-sceneOffset);
          expect(
            local.overlaps(geometry.board),
            false,
            reason: 'not an active capture target',
          );
          expect(
            local.overlaps(geometry.hand),
            false,
            reason: 'hand input stays clear',
          );
          for (final hud in [
            geometry.history,
            geometry.menu,
            geometry.scores,
          ]) {
            expect(
              local.overlaps(hud),
              false,
              reason: 'public copies must not cover HUD',
            );
          }
        }
        for (var a = 0; a < boxes.length; a++)
          for (var b = a + 1; b < boxes.length; b++) {
            if (!cardUiRefinements ||
                copies[a].ownerUid != copies[b].ownerUid) {
              expect(
                boxes[a].overlaps(boxes[b]),
                false,
                reason: 'different players never share a public slot',
              );
            } else {
              expect(
                boxes[a].intersect(boxes[b]).width,
                lessThan(12),
                reason:
                    'only slight same-owner fan overlap; ranks remain exposed',
              );
            }
          }
        await tester.pumpWidget(scene(copies.skip(1).toList()));
        expect(find.byKey(const ValueKey('shown-0:0')), findsNothing);
        expect(find.byKey(const ValueKey('shown-0:1')), findsOneWidget);
        expect(contacts, 0);
      },
    );
  }
  testWidgets('new reveal contacts once; real play cancels a pending contact', (
    tester,
  ) async {
    var contacts = 0;
    Widget scene(List<ShownCard> cards) => MaterialApp(
      home: ShownCardLayer(
        cards: cards,
        seats: seats,
        localUid: 'a',
        geometry: OptionBGeometry(const Size(800, 430)),
        faceBuilder: (_, w, h) => SizedBox(width: w, height: h),
        backBuilder: (w, h) => SizedBox(width: w, height: h),
        onContact: (_) => contacts++,
      ),
    );
    await tester.pumpWidget(scene([]));
    await tester.pumpWidget(scene([copies.first]));
    await tester.pump(Duration(milliseconds: cardUiRefinements ? 289 : 269));
    expect(contacts, 0);
    await tester.pump(const Duration(milliseconds: 2));
    expect(contacts, 1);
    await tester.pumpAndSettle();
    await tester.pumpWidget(scene(copies.take(2).toList()));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpWidget(scene([copies.first]));
    await tester.pumpAndSettle();
    expect(contacts, 1);
  });
  testWidgets(
    'reduced motion keeps accepted-show feedback but mounts silently',
    (tester) async {
      var contacts = 0;
      Widget scene(List<ShownCard> cards) => MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ShownCardLayer(
            cards: cards,
            seats: seats,
            localUid: 'a',
            geometry: OptionBGeometry(const Size(800, 430)),
            faceBuilder: (_, w, h) => SizedBox(width: w, height: h),
            backBuilder: (w, h) => SizedBox(width: w, height: h),
            onContact: (_) => contacts++,
          ),
        ),
      );
      await tester.pumpWidget(scene([copies.first]));
      expect(contacts, 0);
      await tester.pumpWidget(scene(copies.take(2).toList()));
      await tester.pump(const Duration(milliseconds: 1));
      expect(contacts, 1);
      await tester.pumpAndSettle();
      expect(contacts, 1);
    },
  );
  testWidgets(
    'gesture slam has approach, contact lead and 50ms hold without domain callbacks',
    (tester) async {
      var contacts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: BoardCardMotion(
              origin: const Offset(0, 100),
              gestureSlam: true,
              onContact: () => contacts++,
              child: const SizedBox(
                key: ValueKey('card'),
                width: 64,
                height: 92,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 269));
      expect(contacts, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(contacts, 1);
      await tester.pump(const Duration(milliseconds: 30));
      final atContact = tester.getCenter(find.byKey(const ValueKey('card')));
      await tester.pump(const Duration(milliseconds: 49));
      expect(tester.getCenter(find.byKey(const ValueKey('card'))), atContact);
      await tester.pumpAndSettle();
      expect(contacts, 1);
    },
  );
}
