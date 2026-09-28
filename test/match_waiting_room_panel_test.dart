import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/presentation/widgets/match_waiting_room_panel.dart';

Widget room({String currentUid = 'me', List<String>? ids,
  Map<String, bool> votes = const {}, Future<void> Function()? ready,
  double textScale = 1.0}) =>
  MaterialApp(home: MediaQuery(data: MediaQueryData(
    textScaler: TextScaler.linear(textScale)),
    child: Scaffold(body: Align(alignment: Alignment.bottomCenter,
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520,
      maxHeight: 420), child: SingleChildScrollView(child:
      MatchWaitingRoomPanel(roomId: 'A_ROOM_WITH_A_LONG_IDENTIFIER',
        currentUid: currentUid, title: 'Waiting for players', roomLabel: 'Room ID:',
        waitingLabel: 'Waiting...', youLabel: 'You', botLabel: 'Bot',
        playerLabel: 'Player', readyLabel: 'Ready with bots',
        consentLabel: 'Waiting for consent', fullLabel: 'Starting soon',
        spectatorLabel: 'Spectating', inviteLabel: 'Invite friends',
        failureLabel: 'Try again', playerIds: ids ??
          ['me', 'bot_1', 'waiting_2', 'waiting_3'],
        playerNames: const {'bot_1': 'bot_name_template'},
        botVotes: votes, onReady: ready, onInvite: () {})))))));

void main() {
  testWidgets('bot placeholder has a readable name and counts as occupied', (tester) async {
    await tester.pumpWidget(room(ready: () async {}));
    expect(find.text('Bot 1'), findsOneWidget);
    expect(find.text('bot_name_template'), findsNothing);
    expect(find.text('1/1'), findsOneWidget);
    expect(find.text('Ready with bots'), findsOneWidget);
  });
  testWidgets('spectator and ready player have no bot vote action', (tester) async {
    await tester.pumpWidget(room(currentUid: 'spectator', ready: () async {}));
    expect(find.text('Spectating'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    await tester.pumpWidget(room(votes: const {'me': true}, ready: () async {}));
    expect(find.text('Waiting for consent'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });
  testWidgets('pending consent cannot be sent twice and failure can retry', (tester) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(room(ready: () { calls++; return pending.future; }));
    await tester.tap(find.text('Ready with bots'));
    await tester.pump();
    expect(calls, 1);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    pending.completeError(StateError('offline'));
    await tester.pump();
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(320, 568), const Size(390, 844),
      const Size(844, 390)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('waiting room fits $size at ${scale}x text', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(room(ready: () async {}, textScale: scale));
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Ready with bots'));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
