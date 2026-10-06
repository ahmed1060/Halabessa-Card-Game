import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/presentation/widgets/match_recovery_view.dart';

Widget recovery(Future<void> Function() retry, {VoidCallback? exit}) =>
    MaterialApp(
      home: MatchRecoveryView(
        onRetry: retry,
        onExit: exit ?? () {},
        loadingTitle: 'Recovering match',
        unavailableTitle: 'Match unavailable',
        explanation: 'Retry or return to the lobby.',
        retryLabel: 'Retry',
        exitLabel: 'Lobby',
      ),
    );

void main() {
  testWidgets('ended practice never reconnects automatically and can restart', (
    tester,
  ) async {
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MatchRecoveryView(
          terminal: true,
          onRetry: () async {
            starts++;
          },
          onExit: () {},
          loadingTitle: 'Starting practice',
          unavailableTitle: 'Practice ended',
          explanation: 'Choose a new difficulty.',
          retryLabel: 'Practice',
          exitLabel: 'Lobby',
        ),
      ),
    );
    await tester.pump();
    expect(starts, 0);
    expect(find.text('Practice ended'), findsOneWidget);
    await tester.tap(find.text('Practice'));
    await tester.pump();
    expect(starts, 1);
    expect(find.text('Practice ended'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'rebuilds do not restart recovery; timeout exposes explicit retry',
    (tester) async {
      var attempts = 0;
      Future<void> retry() async {
        attempts++;
      }

      await tester.pumpWidget(recovery(retry));
      await tester.pumpWidget(recovery(retry));
      await tester.pumpWidget(recovery(retry));
      expect(attempts, 1);
      expect(find.text('Recovering match'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
      expect(find.text('Match unavailable'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(attempts, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('failure exposes retry and lobby remains available', (
    tester,
  ) async {
    var exits = 0;
    await tester.pumpWidget(
      recovery(() async {
        throw StateError('offline');
      }, exit: () => exits++),
    );
    await tester.pump();
    expect(find.text('Match unavailable'), findsOneWidget);
    await tester.tap(find.text('Lobby'));
    expect(exits, 1);
    expect(find.textContaining('offline'), findsNothing);
  });
  testWidgets('short screen and large text remain scrollable', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MatchRecoveryView(
            onRetry: () async {},
            onExit: () {},
            loadingTitle: 'Recovering your match',
            unavailableTitle: 'Match unavailable',
            explanation: 'Retry or return to the lobby.',
            retryLabel: 'Retry',
            exitLabel: 'Lobby',
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
