import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/presentation/widgets/match_choice_panel.dart';

Widget choice({required bool canVote, Future<void> Function()? first,
  Future<void> Function()? second}) => MaterialApp(home: Scaffold(body: Center(
    child: SizedBox(width: 300, child: MatchChoicePanel(
      title: 'Shuffle?', detail: 'Votes 1 of 4', firstLabel: 'Shuffle deck',
      secondLabel: 'Keep sequence', failureMessage: 'Try again', canVote: canVote,
      onFirst: first, onSecond: second)))));

void main() {
  testWidgets('spectator or completed voter cannot submit a choice', (tester) async {
    await tester.pumpWidget(choice(canVote: false, first: () async {}, second: () async {}));
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('Votes 1 of 4'), findsOneWidget);
  });
  testWidgets('one pending choice disables both actions, failure re-enables them', (tester) async {
    final pending = Completer<void>();
    var firstCalls = 0, secondCalls = 0;
    await tester.pumpWidget(choice(canVote: true,
      first: () { firstCalls++; return pending.future; },
      second: () async { secondCalls++; }));
    await tester.tap(find.text('Shuffle deck'));
    await tester.pump();
    expect(firstCalls, 1);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed, isNull);
    pending.completeError(StateError('offline'));
    await tester.pump();
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Keep sequence'));
    await tester.pump();
    expect(secondCalls, 1);
    expect(tester.takeException(), isNull);
  });
}
