import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../domain/models/match_state.dart';
import '../../domain/models/round_score_breakdown.dart';
import 'table_style.dart';

/// Only public, real totals. Tafweet bonuses cannot be inferred from card count.
class RoundSummaryPanel extends StatelessWidget {
  final MatchState state;
  final bool firstIsA;
  final bool spectator;
  const RoundSummaryPanel({
    super.key,
    required this.state,
    required this.firstIsA,
    this.spectator = false,
  });
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: TableStyle.ink,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: TableStyle.brass),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'round_finished'.tr(),
            style: TableStyle.label.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _team(
                  firstIsA ? 'teamA' : 'teamB',
                  (spectator ? 'team_a' : 'my_team').tr(),
                  TableStyle.mint,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _team(
                  firstIsA ? 'teamB' : 'teamA',
                  (spectator ? 'team_b' : 'opponent_team').tr(),
                  TableStyle.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'round_advances_automatically'.tr(),
            textAlign: TextAlign.center,
            style: TableStyle.detail,
          ),
        ],
      ),
    ),
  );
  Widget _team(String id, String label, Color color) {
    final breakdown = RoundScoreBreakdown.forTeam(state, id);
    final captures = state.harvestStacks[id] ?? [];
    final plays = captures.where((capture) => !capture.isRoundAward).length;
    final cards = captures.fold<int>(
      0,
      (total, capture) => total + capture.cardCount,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TableStyle.label.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          '${'ui_round_captures'.tr()}: $plays',
          textAlign: TextAlign.center,
          style: TableStyle.detail,
        ),
        Text(
          '${'ui_round_cards'.tr()}: $cards',
          textAlign: TextAlign.center,
          style: TableStyle.detail,
        ),
        const SizedBox(height: 4),
        if (breakdown != null) ...[
          Text(
            '${'ui_capture_points'.tr()}: ${breakdown.captures}',
            textAlign: TextAlign.center,
            style: TableStyle.detail,
          ),
          if (state.mode == GameMode.tafweet)
            Text(
              '${'ui_tafweet_bonus'.tr()}: ${breakdown.tafweetBonus}',
              textAlign: TextAlign.center,
              style: TableStyle.detail,
            ),
          Text(
            '${'ui_majority_bonus'.tr()}: ${breakdown.majorityBonus}',
            textAlign: TextAlign.center,
            style: TableStyle.detail,
          ),
          Text(
            '${'ui_round_points'.tr()}: ${breakdown.total}',
            textAlign: TextAlign.center,
            style: TableStyle.label.copyWith(color: color),
          ),
        ],
        Text(
          '${'ui_round_score'.tr()}: ${id == 'teamA' ? state.teamAScore : state.teamBScore}',
          textAlign: TextAlign.center,
          style: TableStyle.label.copyWith(color: color),
        ),
      ],
    );
  }
}
