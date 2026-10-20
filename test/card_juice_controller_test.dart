import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/presentation/widgets/card_juice_controller.dart';

void main() {
  Widget scene({bool peek = false, bool reduced = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Center(
        child: CardJuiceController(
          peek: peek,
          child: const SizedBox(
            key: ValueKey('card-face'),
            width: 60,
            height: 90,
          ),
        ),
      ),
    ),
  );
  testWidgets('peek reaches 1.2x without resizing the input/layout box', (
    tester,
  ) async {
    await tester.pumpWidget(scene());
    final root = tester.getRect(find.byType(CardJuiceController));
    await tester.pumpWidget(scene(peek: true));
    await tester.pumpAndSettle();
    final transform = tester.widget<Transform>(
      find.descendant(
        of: find.byType(CardJuiceController),
        matching: find.byType(Transform),
      ),
    );
    expect(transform.transform.entry(0, 0), closeTo(1.2, .002));
    expect(tester.getRect(find.byType(CardJuiceController)), root);
    await tester.pumpWidget(scene());
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Transform>(
            find.descendant(
              of: find.byType(CardJuiceController),
              matching: find.byType(Transform),
            ),
          )
          .transform
          .entry(0, 0),
      closeTo(1, .002),
    );
  });
  testWidgets(
    'reduced motion settles immediately and disposal cancels contact',
    (tester) async {
      await tester.pumpWidget(scene(peek: true, reduced: true));
      await tester
          .pump(); // MaterialApp's first-frame setup is not card motion.
      expect(tester.binding.hasScheduledFrame, isFalse);
      var contacts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CardTableImpact(
            identity: 'capture',
            onContact: () => contacts++,
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(contacts, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));
      expect(contacts, 0);
    },
  );
  testWidgets(
    'enabling reduced motion cancels a pending impact without replay',
    (tester) async {
      var contacts = 0;
      Widget impact(bool reduced) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: CardTableImpact(
            identity: 'same-capture',
            onContact: () => contacts++,
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pumpWidget(impact(false));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(impact(true));
      await tester.pump(const Duration(milliseconds: 1));
      expect(contacts, 1);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(impact(false));
      await tester.pump(const Duration(milliseconds: 300));
      expect(contacts, 1);
    },
  );
  test('fan is parabolic and symmetric without changing card order', () {
    expect(handArc(0, 4), handArc(3, 4));
    expect(handArc(1, 4), handArc(2, 4));
    expect(handArc(1, 4), greaterThan(handArc(0, 4)));
  });
}
