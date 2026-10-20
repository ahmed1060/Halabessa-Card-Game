import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import 'package:halabessa/features/game/presentation/widgets/match_choice_panel.dart';
import 'package:halabessa/features/game/presentation/widgets/table_style.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('vote label contrasts with actual theme fill, dark=$dark', (
      tester,
    ) async {
      final pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? ThemeConfig.darkTheme : ThemeConfig.lightTheme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: MatchChoicePanel(
                  title: 'الكوتشينة خلصت!',
                  detail: 'تصويت اللاعبين: 0 من 1',
                  firstLabel: 'نفنط',
                  secondLabel: 'خليها زي ما هي',
                  failureMessage: 'حاول تاني',
                  canVote: true,
                  onFirst: () => pending.future,
                  onSecond: () async {},
                ),
              ),
            ),
          ),
        ),
      );
      Color labelColor() => DefaultTextStyle.of(
        tester.element(find.text('خليها زي ما هي')),
      ).style.color!;
      double contrast(Color a, Color b) {
        final x = a.computeLuminance(), y = b.computeLuminance();
        return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
      }

      expect(labelColor(), TableStyle.ivory);
      expect(contrast(labelColor(), TableStyle.ink), greaterThan(4.5));
      await tester.tap(find.text('نفنط'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      expect(
        contrast(
          Color.alphaBlend(labelColor(), TableStyle.ink),
          TableStyle.ink,
        ),
        greaterThan(4.5),
      );
      pending.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
