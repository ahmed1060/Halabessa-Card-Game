import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../domain/models/match_state.dart';
import '../../domain/models/round_score_breakdown.dart';
import 'table_style.dart';
import 'lantern_controls.dart';
import '../../domain/logic/online_match_clock.dart';
import '../../domain/logic/match_presentation_timing.dart';

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
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('round-results-fullscreen'),
    color: Colors.black.withValues(alpha: .32),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    TableStyle.ink.withValues(alpha: .9),
                    TableStyle.ink.withValues(alpha: .68),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: TableStyle.brass.withValues(alpha: .55),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final first = _team(
                    firstIsA ? 'teamA' : 'teamB',
                    (spectator ? 'team_a' : 'my_team').tr(),
                    TableStyle.mint,
                  );
                  final second = _team(
                    firstIsA ? 'teamB' : 'teamA',
                    (spectator ? 'team_b' : 'opponent_team').tr(),
                    TableStyle.red,
                  );
                  final wide =
                      bounds.maxWidth > 600 &&
                      MediaQuery.textScalerOf(context).scale(16) < 26;
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: bounds.maxHeight),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'round_finished'.tr(),
                              textAlign: TextAlign.center,
                              style: TableStyle.label.copyWith(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (wide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: first),
                                  const SizedBox(width: 32),
                                  Expanded(child: second),
                                ],
                              )
                            else ...[
                              first,
                              const SizedBox(height: 24),
                              second,
                            ],
                            const SizedBox(height: 24),
                            Text(
                              'round_advances_automatically'.tr(),
                              textAlign: TextAlign.center,
                              style: TableStyle.label,
                            ),
                            if (state.phaseStartedAt != null) ...[
                              const SizedBox(height: 8),
                              TurnCountdown(
                                started: state.phaseStartedAt!,
                                seconds: roundResultsDuration.inSeconds,
                                now: state.usesServerCommands
                                    ? OnlineMatchClock.instance.now
                                    : DateTime.now,
                                color: TableStyle.brass,
                                label: (seconds) =>
                                    'ui_seconds_short'.tr(args: ['$seconds']),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
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
            fontSize: 22,
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
          style: TableStyle.label.copyWith(
            color: color,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
