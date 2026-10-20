import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/core/theme/lantern_page_transitions.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets('game transition preserves native underlay, reduced=$reduced', (tester) async {
      Future<void> show(String name) => tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(builder: (context) =>
              const LanternPageTransitionsBuilder().buildTransitions<void>(
                MaterialPageRoute<void>(
                  settings: RouteSettings(name: name),
                  builder: (_) => const SizedBox(),
                ),
                context,
                const AlwaysStoppedAnimation(1),
                const AlwaysStoppedAnimation(0),
                const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      await show('/game');
      expect(tester.widget<ColoredBox>(find.byType(ColoredBox)).color, Colors.transparent);
      await show('/home');
      expect(tester.widget<ColoredBox>(find.byType(ColoredBox)).color, const Color(0xFF3B274C));
    });
  }
}
