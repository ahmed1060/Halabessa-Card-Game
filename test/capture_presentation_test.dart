import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/game/presentation/widgets/capture_presentation.dart';

void main() {
  testWidgets(
    'ordinary table plays serialize while accepted turn and scores stay current',
    (tester) async {
      final baseline = MatchState.fromJson({
        'id': 'TEST',
        'protocolVersion': 1,
        'serverVersion': 1,
        'playerIds': ['a', 'b', 'c', 'd'],
        'phase': 'playing',
      });
      Widget scene(MatchState state) => MaterialApp(
        home: CapturePresentation(
          state: state,
          builder: (visual) => Text(
            '${visual.board.length}:${visual.currentTurnIndex}:${visual.teamAScore}',
          ),
        ),
      );
      await tester.pumpWidget(scene(baseline));
      final one = MatchState.fromJson({
        ...baseline.toJson(),
        'serverVersion': 2,
        'currentTurnIndex': 1,
        'board': [
          {'suit': 'clubs', 'rank': 'two'},
        ],
      });
      await tester.pumpWidget(scene(one));
      final two = MatchState.fromJson({
        ...one.toJson(),
        'serverVersion': 3,
        'currentTurnIndex': 2,
        'teamAScore': 5,
        'board': [
          {'suit': 'clubs', 'rank': 'two'},
          {'suit': 'clubs', 'rank': 'three'},
        ],
      });
      await tester.pumpWidget(scene(two));
      expect(find.text('1:2:5'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('2:2:5'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  final now = DateTime.utc(2026, 10, 12);
  final first = MatchState.fromJson({
    'id': 'ABC12345',
    'protocolVersion': 1,
    'serverVersion': 1,
    'playerIds': ['a', 'bot_2', 'b', 'bot_4'],
    'phase': 'playing',
    'currentTurnIndex': 0,
    'dealerIndex': 0,
  });
  Map<String, dynamic> event(String id, String rank) => {
    'id': id,
    'team': 'teamA',
    'playerUid': 'a',
    'createdAt': now.toIso8601String(),
    'cards': [
      {'suit': 'hearts', 'rank': rank},
      {'suit': 'clubs', 'rank': rank},
    ],
  };
  Widget view(MatchState state, {bool reduced = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: CapturePresentation(
        state: state,
        now: () => now,
        builder: (visual) => Text(
          '${visual.phase.name}:${visual.board.map((c) => c.rank.name).join(',')}',
        ),
      ),
    ),
  );
  testWidgets(
    'queues accepted captures, preserves later board and never replays duplicates',
    (tester) async {
      await tester.pumpWidget(view(first));
      final captured = MatchState.fromJson({
        ...first.toJson(),
        'serverVersion': 2,
        'captureEvents': [event('1', 'ace')],
      });
      await tester.pumpWidget(view(captured));
      expect(find.text('capturing:ace,ace'), findsOneWidget);
      final following = MatchState.fromJson({
        ...captured.toJson(),
        'serverVersion': 4,
        'captureEvents': [event('1', 'ace'), event('2', 'king')],
        'board': [
          {'suit': 'clubs', 'rank': 'two'},
        ],
      });
      await tester.pumpWidget(view(following));
      expect(find.text('capturing:ace,ace'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1400));
      expect(find.text('capturing:king,king'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1400));
      expect(find.text('playing:two'), findsOneWidget);
      await tester.pumpWidget(view(following.copyWith(serverVersion: 5)));
      expect(find.text('playing:two'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'initial reconnect and reduced motion skip historical animation; new round resets',
    (tester) async {
      final captured = MatchState.fromJson({
        ...first.toJson(),
        'serverVersion': 2,
        'captureEvents': [event('1', 'ace')],
      });
      await tester.pumpWidget(view(captured));
      expect(find.text('playing:'), findsOneWidget);
      final another = MatchState.fromJson({
        ...captured.toJson(),
        'serverVersion': 3,
        'captureEvents': [event('1', 'ace'), event('2', 'king')],
      });
      await tester.pumpWidget(view(another, reduced: true));
      expect(find.text('playing:'), findsOneWidget);
      await tester.pumpWidget(
        view(another.copyWith(roundCount: 2), reduced: false),
      );
      expect(find.text('playing:'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
