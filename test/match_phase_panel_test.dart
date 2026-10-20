import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/presentation/widgets/match_phase_panel.dart';

void main() {
  testWidgets('shuffle is bounded, cosmetic and leaves cut available', (
    tester,
  ) async {
    var cuts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatchPhasePanel(
            title: 'Cut',
            message: 'Your cut',
            failureMessage: 'Retry',
            shuffleIntro: true,
            shuffleTitle: 'Shuffling',
            shuffleMessage: 'Mixing',
            actionLabel: 'Cut now',
            onAction: () async {
              cuts++;
            },
          ),
        ),
      ),
    );
    expect(find.text('Shuffling'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Cut now'));
    await tester.pump();
    expect(cuts, 1);
    await tester.pump(const Duration(milliseconds: 650));
    expect(find.text('Shuffling'), findsNothing);
    expect(find.text('Your cut'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('reduced motion and stale snapshots skip shuffle replay', (
    tester,
  ) async {
    Widget panel(bool reduced, DateTime? started) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Scaffold(
          body: MatchPhasePanel(
            key: ValueKey('$reduced-$started'),
            title: 'Cut',
            message: 'Your cut',
            failureMessage: 'Retry',
            shuffleIntro: true,
            shuffleTitle: 'Shuffling',
            startedAt: started,
          ),
        ),
      ),
    );
    await tester.pumpWidget(panel(true, null));
    expect(find.text('Shuffling'), findsNothing);
    await tester.pumpWidget(
      panel(false, DateTime.now().subtract(const Duration(seconds: 5))),
    );
    expect(find.text('Shuffling'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('observers have no phase action', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MatchPhasePanel(
            title: 'Cut the deck',
            message: 'Waiting for the cutter',
            failureMessage: 'Retry',
          ),
        ),
      ),
    );
    expect(find.byType(FilledButton), findsNothing);
  });
  testWidgets('pending action blocks duplicates and errors allow retry', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatchPhasePanel(
            title: 'Cut the deck',
            message: 'Your cut',
            failureMessage: 'Try again',
            actionLabel: 'Cut',
            onAction: () {
              calls++;
              return pending.future;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Cut'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    pending.completeError(StateError('offline'));
    await tester.pump();
    expect(calls, 1);
    expect(find.text('Try again'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
}
