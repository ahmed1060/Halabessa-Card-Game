import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/presentation/widgets/board_card_motion.dart';

void main() {
  Widget scene({bool reduceMotion = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(body: Center(child: BoardCardMotion(
        key: const ValueKey('arrival'),
        origin: const Offset(100, -80),
        child: const SizedBox(key: ValueKey('card'), width: 50, height: 70),
      ))),
    ),
  );

  testWidgets('card arrives once from its seat and settles on the table', (tester) async {
    await tester.pumpWidget(scene());
    expect(tester.widget<Opacity>(find.descendant(
      of: find.byType(BoardCardMotion), matching: find.byType(Opacity),
    )).opacity, closeTo(0.75, 0.01));
    final start = tester.getRect(find.byKey(const ValueKey('card'))).center;
    await tester.pumpAndSettle();
    final settled = tester.getRect(find.byKey(const ValueKey('card'))).center;
    expect(start.dx - settled.dx, closeTo(100, 1));
    expect(start.dy - settled.dy, closeTo(-80, 1));

    await tester.pumpWidget(scene());
    expect(tester.getRect(find.byKey(const ValueKey('card'))).center, settled);
  });

  testWidgets('reduced motion places the card immediately', (tester) async {
    await tester.pumpWidget(scene(reduceMotion: true));
    final card = tester.getRect(find.byKey(const ValueKey('card')));
    final board = tester.getRect(find.byType(BoardCardMotion));
    expect(card.center, board.center);
  });
}
