import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/presentation/widgets/match_phase_panel.dart';

void main() {
  testWidgets('observers have no phase action', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MatchPhasePanel(
      title: 'Cut the deck', message: 'Waiting for the cutter', failureMessage: 'Retry'))));
    expect(find.byType(FilledButton), findsNothing);
  });
  testWidgets('pending action blocks duplicates and errors allow retry', (tester) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MatchPhasePanel(
      title: 'Cut the deck', message: 'Your cut', failureMessage: 'Try again',
      actionLabel: 'Cut', onAction: () { calls++; return pending.future; }))));
    await tester.tap(find.text('Cut'));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    pending.completeError(StateError('offline'));
    await tester.pump();
    expect(calls, 1);
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
  });
}
