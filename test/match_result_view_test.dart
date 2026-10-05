import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/presentation/widgets/match_result_view.dart';

Widget result({VoidCallback? replay, VoidCallback? home, bool replayLeavesView = true}) => MaterialApp(home: MatchResultView(
  title: 'Victory', subtitle: 'Great play', firstTeam: 'My Team', secondTeam: 'Opponent Team',
  firstScore: 42, secondScore: 30, stars: 3, coins: 100,
  starsLabel: 'Stars', coinsLabel: 'Coins', homeLabel: 'Return home',
  replayLabel: 'Play again', onHome: () { home?.call(); return true; },
  onReplay: replay == null ? null : () { replay(); return true; },
  replayLeavesView: replayLeavesView));

void main() {
  testWidgets('failed home acknowledgement restores controls and permits retry', (tester) async {
    var calls = 0;
    final pending = Completer<bool>();
    await tester.pumpWidget(MaterialApp(home: MatchResultView(
      title: 'Victory', subtitle: 'Great play', firstTeam: 'Us', secondTeam: 'Them',
      firstScore: 21, secondScore: 10, stars: 3, coins: 100,
      starsLabel: 'Stars', coinsLabel: 'Coins', homeLabel: 'Return home',
      replayLabel: 'Play again', onReplay: () => true,
      onHome: () { calls++; return calls == 1 ? pending.future : Future.value(true); })));
    await tester.tap(find.text('Return home'));
    await tester.pump();
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed, isNull);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    pending.complete(false);
    await tester.pump();
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed, isNotNull);
    await tester.tap(find.text('Return home'));
    await tester.pump();
    expect(calls, 2);
  });
  testWidgets('failed replay can retry without blocking return home', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: MatchResultView(
      title: 'Victory', subtitle: 'Great play', firstTeam: 'Us', secondTeam: 'Them',
      firstScore: 21, secondScore: 10, stars: 3, coins: 100,
      starsLabel: 'Stars', coinsLabel: 'Coins', homeLabel: 'Return home',
      replayLabel: 'Play again', replayLeavesView: false, onHome: () => true,
      onReplay: () async { calls++; if (calls == 1) throw StateError('offline'); return false; })));
    await tester.tap(find.text('Play again'));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed, isNotNull);
    await tester.tap(find.text('Play again'));
    await tester.pump();
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets('rematch vote is single-shot but return home stays available', (tester) async {
    var votes = 0;
    var exits = 0;
    await tester.pumpWidget(result(replay: () => votes++, home: () => exits++,
      replayLeavesView: false));
    await tester.tap(find.text('Play again'));
    await tester.pump();
    expect(votes, 1);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed, isNotNull);
    await tester.tap(find.text('Return home'));
    expect(exits, 1);
  });
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
            replayLabel: 'Play again', onHome: () => true, onReplay: () => true))));
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
