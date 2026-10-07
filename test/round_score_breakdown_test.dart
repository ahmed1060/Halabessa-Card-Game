import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/models/card.dart';
import 'package:halabessa/features/game/domain/models/capture.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/game/domain/models/round_score_breakdown.dart';
import 'package:halabessa/features/auth/domain/models/ranking_period.dart';

const card = Card(Suit.hearts, Rank.ace);
MatchState round({int aCards = 30, int? award = 6}) => MatchState(
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
        capturedCards: List.filled(aCards - 1, card),
        awardedPoints: award,
      ),
    ],
    'teamB': [
      Capture(
        leadingCard: card,
        capturedCards: List.filled(51 - aCards, card),
        isRoundAward: true,
      ),
    ],
  },
);
void main() {
  test(
    'round details use recorded bonus, not cumulative score or leftover award',
    () {
      final result = RoundScoreBreakdown.forTeam(round(), 'teamA')!;
      expect(result.captures, 1);
      expect(result.tafweetBonus, 5);
      expect(result.majorityBonus, 3);
      expect(result.total, 9);
      expect(RoundScoreBreakdown.forTeam(round(), 'teamB')!.total, 0);
    },
  );
  test(
    'tie awards no majority; old bonuses and incomplete rounds are not guessed',
    () {
      expect(
        RoundScoreBreakdown.forTeam(round(aCards: 26), 'teamA')!.majorityBonus,
        0,
      );
      expect(RoundScoreBreakdown.forTeam(round(award: null), 'teamA'), isNull);
      expect(
        RoundScoreBreakdown.forTeam(
          round().copyWith(phase: GamePhase.playing),
          'teamA',
        ),
        isNull,
      );
      expect(
        RoundScoreBreakdown.forTeam(
          round().copyWith(harvestStacks: {}),
          'teamA',
        ),
        isNull,
      );
    },
  );
  test(
    'awards survive capture JSON and current-round replacement drops previous details',
    () {
      final capture = Capture.fromJson(
        round().harvestStacks['teamA']!.first.toJson(),
      );
      expect(capture.awardedPoints, 6);
      expect(
        RoundScoreBreakdown.forTeam(
          round().copyWith(harvestStacks: const {'teamA': [], 'teamB': []}),
          'teamA',
        ),
        isNull,
      );
    },
  );
  test('weekly period starts Monday in UTC across month/year boundary', () {
    expect(
      RankingPeriod.key(DateTime.parse('2026-10-05T01:00:00+03:00')),
      '2026-09-28',
    );
    expect(
      RankingPeriod.key(DateTime.parse('2026-10-05T00:00:00Z')),
      '2026-10-05',
    );
    expect(
      RankingPeriod.end(DateTime.utc(2026, 12, 31)),
      DateTime.utc(2027, 1, 4),
    );
  });
}
