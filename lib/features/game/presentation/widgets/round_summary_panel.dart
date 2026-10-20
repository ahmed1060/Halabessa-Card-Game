import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../../domain/models/match_state.dart';
import '../../domain/models/round_score_breakdown.dart';
import 'table_style.dart';
import 'lantern_controls.dart';
import 'velvet_score_frame.dart';
import '../../domain/logic/online_match_clock.dart';
import '../../domain/logic/match_presentation_timing.dart';

/// Public recorded awards only. This scoreboard cannot advance a round.
class RoundSummaryPanel extends StatelessWidget {
  final MatchState state;
  final bool firstIsA, spectator;
  const RoundSummaryPanel({
    super.key,
    required this.state,
    required this.firstIsA,
    this.spectator = false,
  });

  String get _first => firstIsA ? 'teamA' : 'teamB';
  String get _second => firstIsA ? 'teamB' : 'teamA';
  int _cards(String id) => (state.harvestStacks[id] ?? []).fold(
    0,
    (n, capture) => n + capture.cardCount,
  );
  int _plays(String id) =>
      (state.harvestStacks[id] ?? []).where((c) => !c.isRoundAward).length;

  Widget _score(String id, String label, Color color) {
    final breakdown = RoundScoreBreakdown.forTeam(state, id);
    final score = id == 'teamA' ? state.teamAScore : state.teamBScore;
    return VelvetScoreTile(
      key: ValueKey('round-score-$id'),
      label: label,
      score: score,
      scoreLabel: 'ui_round_score'.tr(),
      color: color,
      compact: true,
      footer: breakdown == null
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: .6)),
              ),
              child: Column(
                children: [
                  Text('ui_round_points'.tr(), style: TableStyle.detail),
                  Text(
                    '+${breakdown.total}',
                    key: ValueKey('round-points-$id'),
                    textDirection: TextDirection.ltr,
                    style: TableStyle.label.copyWith(
                      color: color,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _stats() {
    final a = RoundScoreBreakdown.forTeam(state, _first);
    final b = RoundScoreBreakdown.forTeam(state, _second);
    Widget row(String key, int? first, int? second) => Container(
      key: ValueKey('round-stat-$key'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: TableStyle.ivory.withValues(alpha: .13)),
        ),
      ),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          SizedBox(
            width: 38,
            child: Text(
              second?.toString() ?? '—',
              textAlign: TextAlign.center,
              style: TableStyle.label.copyWith(
                color: TableStyle.red,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ),
          Expanded(
            child: Text(
              key.tr(),
              textAlign: TextAlign.center,
              style: TableStyle.label,
            ),
          ),
          SizedBox(
            width: 38,
            child: Text(
              first?.toString() ?? '—',
              textAlign: TextAlign.center,
              style: TableStyle.label.copyWith(
                color: TableStyle.mint,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row('ui_round_captures', _plays(_first), _plays(_second)),
        row('ui_round_cards', _cards(_first), _cards(_second)),
        if (a != null || b != null) ...[
          row('ui_capture_points', a?.captures, b?.captures),
          if (state.mode == GameMode.tafweet)
            row('ui_tafweet_bonus', a?.tafweetBonus, b?.tafweetBonus),
          row('ui_majority_bonus', a?.majorityBonus, b?.majorityBonus),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('round-results-fullscreen'),
    color: Colors.black.withValues(alpha: .35),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, bounds) {
            final wide =
                bounds.maxWidth >= 700 &&
                MediaQuery.textScalerOf(context).scale(14) <= 22;
            final first = _score(
              _first,
              (spectator ? 'team_a' : 'my_team').tr(),
              TableStyle.mint,
            );
            final second = _score(
              _second,
              (spectator ? 'team_b' : 'opponent_team').tr(),
              TableStyle.red,
            );
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: VelvetScoreFrame(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'round_finished'.tr(),
                          textAlign: TextAlign.center,
                          style: TableStyle.label.copyWith(
                            fontSize: wide ? 25 : 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (wide)
                          Row(
                            textDirection: TextDirection.ltr,
                            children: [
                              Expanded(flex: 3, child: second),
                              const SizedBox(width: 16),
                              Expanded(flex: 6, child: _stats()),
                              const SizedBox(width: 16),
                              Expanded(flex: 3, child: first),
                            ],
                          )
                        else ...[
                          Row(
                            textDirection: TextDirection.ltr,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: second),
                              const SizedBox(width: 10),
                              Expanded(child: first),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _stats(),
                        ],
                        const SizedBox(height: 14),
                        Text(
                          'round_advances_automatically'.tr(),
                          textAlign: TextAlign.center,
                          style: TableStyle.detail,
                        ),
                        if (state.phaseStartedAt != null) ...[
                          const SizedBox(height: 6),
                          TurnCountdown(
                            started: state.phaseStartedAt!,
                            seconds: roundResultsDuration.inSeconds,
                            now: state.usesServerCommands
                                ? OnlineMatchClock.instance.now
                                : DateTime.now,
                            color: TableStyle.brass,
                            label: (s) => 'ui_seconds_short'.tr(args: ['$s']),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
