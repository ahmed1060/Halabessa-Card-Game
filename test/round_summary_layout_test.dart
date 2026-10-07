import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as cards;
import 'package:halabessa/features/game/domain/models/capture.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/game/presentation/widgets/match_table_layout.dart';
import 'package:halabessa/features/game/presentation/widgets/round_summary_panel.dart';

void main() {
  const card = cards.Card(cards.Suit.hearts, cards.Rank.ace);
  final state = MatchState(
    id: 'OFFLINE_QA',
    mode: GameMode.tafweet,
    playerIds: const ['a', 'b', 'c', 'd'],
    dealerIndex: 0,
    currentTurnIndex: 0,
    phase: GamePhase.roundScoring,
    teamAScore: 29,
    teamBScore: 15,
    harvestStacks: {
      'teamA': [
        Capture(
          leadingCard: card,
          capturedCards: List.filled(29, card),
          awardedPoints: 6,
        ),
      ],
      'teamB': [
        Capture(
          leadingCard: card,
          capturedCards: List.filled(21, card),
          isRoundAward: true,
        ),
      ],
    },
  );
  for (final size in [const Size(320, 568), const Size(932, 430)]) {
    for (final scale in [1.0, 2.0]) {
      for (final direction in TextDirection.values) {
        testWidgets(
          'recorded round awards fit real table $size $scale $direction',
          (tester) async {
            await tester.binding.setSurfaceSize(size);
            addTearDown(() => tester.binding.setSurfaceSize(null));
            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Directionality(
                    textDirection: direction,
                    child: Scaffold(
                      body: MatchTableLayout(
                        header: const SizedBox(height: 60),
                        partner: const SizedBox(height: 48),
                        leftOpponent: const SizedBox(height: 48),
                        rightOpponent: const SizedBox(height: 48),
                        board: const SizedBox(height: 100),
                        hand: const SizedBox(height: 100),
                        collections: const SizedBox(height: 130),
                        status: RoundSummaryPanel(state: state, firstIsA: true),
                        controls: const SizedBox(height: 48),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            expect(find.text('ui_round_points: 9'), findsOneWidget);
            expect(find.text('ui_round_score: 29'), findsOneWidget);
            expect(find.text('ui_majority_bonus: 3'), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }
}
