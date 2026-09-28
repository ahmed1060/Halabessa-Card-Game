import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/presentation/widgets/match_result_view.dart';

Widget result({VoidCallback? replay, VoidCallback? home}) => MaterialApp(home: MatchResultView(
  title: 'Victory', subtitle: 'Great play', firstTeam: 'My Team', secondTeam: 'Opponent Team',
  firstScore: 42, secondScore: 30, stars: 3, coins: 100,
  starsLabel: 'Stars', coinsLabel: 'Coins', homeLabel: 'Return home',
  replayLabel: 'Play again', onHome: home ?? () {}, onReplay: replay));

void main() {
  for (final size in [const Size(320, 568), const Size(390, 844), const Size(844, 390)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('results fit $size at ${scale}x text', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: MatchResultView(title: 'Victory', subtitle: 'Great play',
            firstTeam: 'My Team', secondTeam: 'Opponent Team',
            firstScore: 42, secondScore: 30, stars: 3, coins: 100,
            starsLabel: 'Stars', coinsLabel: 'Coins', homeLabel: 'Return home',
            replayLabel: 'Play again', onHome: () {}, onReplay: () {}))));
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Return home'));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('online results have no invalid replay action', (tester) async {
    var homeCalls = 0;
    await tester.pumpWidget(result(home: () => homeCalls++));
    expect(find.text('Play again'), findsNothing);
    await tester.tap(find.text('Return home'));
    await tester.pump();
    expect(homeCalls, 1);
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed, isNull);
  });
  testWidgets('offline replay can be tapped only once', (tester) async {
    var replayCalls = 0;
    await tester.pumpWidget(result(replay: () => replayCalls++));
    await tester.tap(find.text('Play again'));
    await tester.pump();
    expect(replayCalls, 1);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
  });
}
