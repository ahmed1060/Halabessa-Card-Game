import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/presentation/widgets/match_choice_panel.dart';
import 'package:halabessa/features/game/presentation/widgets/match_result_view.dart';

void main() {
  for (final size in [
    const Size(667, 375),
    const Size(844, 390),
    const Size(932, 430),
  ]) {
    testWidgets('rematch choices fit landscape $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 21),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: MatchResultView(
                title: 'فوز',
                subtitle: 'لعب رائع',
                firstTeam: 'فريقنا',
                secondTeam: 'المنافسين',
                firstScore: 41,
                secondScore: 20,
                stars: 50,
                coins: 100,
                starsLabel: 'نجوم',
                coinsLabel: 'عملات',
                homeLabel: 'الرئيسية',
                replayLabel: 'نلعب تاني',
                onHome: () => true,
                decision: MatchChoicePanel(
                  title: 'نلعب تاني في نفس الأوضة؟',
                  detail: 'تصويت اللاعبين: ١ من ٢',
                  firstLabel: 'أيوه، نلعب تاني',
                  secondLabel: 'لأ، نخلص هنا',
                  failureMessage: 'حاول تاني',
                  canVote: true,
                  onFirst: () async {},
                  onSecond: () async {},
                  voteStartedAt: DateTime.now(),
                  countdownLabel: (s) =>
                      'باقي $s ثانية · اللي ما يصوّتش صوته لأ',
                ),
              ),
            ),
          ),
        ),
      );
      for (final text in ['أيوه، نلعب تاني', 'لأ، نخلص هنا', 'الرئيسية']) {
        final rect = tester.getRect(find.text(text));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
        expect(rect.top, greaterThanOrEqualTo(0));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('expired vote disables choices but preserves countdown/status', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MatchChoicePanel(
          title: 'Vote',
          detail: 'Waiting',
          firstLabel: 'Yes',
          secondLabel: 'No',
          failureMessage: 'Retry',
          canVote: true,
          voteStartedAt: DateTime.now().subtract(const Duration(seconds: 10)),
          countdownLabel: (s) => '$s seconds',
          onFirst: () async {},
          onSecond: () async {},
        ),
      ),
    );
    expect(find.text('0 seconds'), findsOneWidget);
    expect(find.text('Yes'), findsNothing);
    expect(find.text('Waiting'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
