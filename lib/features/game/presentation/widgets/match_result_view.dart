import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'table_style.dart';
import 'match_table_layout.dart';
import 'velvet_score_frame.dart';

/// The only final-results surface. It owns no match rules or reward writes.
class MatchResultView extends StatefulWidget {
  final String title, subtitle, firstTeam, secondTeam;
  final int firstScore, secondScore, stars, coins;
  final String starsLabel, coinsLabel, homeLabel, replayLabel;
  final FutureOr<bool> Function() onHome;
  final FutureOr<bool> Function()? onReplay;
  final bool replayLeavesView;
  final Widget? decision;
  final Widget? firstPlayers, secondPlayers;
  final bool firstWon;
  const MatchResultView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.firstTeam,
    required this.secondTeam,
    required this.firstScore,
    required this.secondScore,
    required this.stars,
    required this.coins,
    required this.starsLabel,
    required this.coinsLabel,
    required this.homeLabel,
    required this.replayLabel,
    required this.onHome,
    this.onReplay,
    this.replayLeavesView = true,
    this.decision,
    this.firstPlayers,
    this.secondPlayers,
    this.firstWon = true,
  });

  @override
  State<MatchResultView> createState() => _MatchResultViewState();
}

class _MatchResultViewState extends State<MatchResultView> {
  bool _leaving = false;
  bool _replayRequested = false;
  Future<void> _home() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    try {
      final accepted = await widget.onHome();
      if (!accepted && mounted) setState(() => _leaving = false);
    } catch (_) {
      if (mounted) setState(() => _leaving = false);
    }
  }

  Future<void> _replay() async {
    if (_leaving || _replayRequested || widget.onReplay == null) return;
    setState(() {
      _replayRequested = true;
      _leaving = widget.replayLeavesView;
    });
    try {
      final accepted = await widget.onReplay!();
      if (!accepted && mounted) {
        setState(() {
          _replayRequested = false;
          _leaving = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _replayRequested = false;
          _leaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _home();
    },
    child: Scaffold(
      backgroundColor: TableStyle.felt,
      body: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, bounds) => Image.asset(
              bounds.maxWidth > bounds.maxHeight
                  ? 'assets/images/tables/halabessa_tabletop_landscape_v1.png'
                  : 'assets/images/tables/halabessa_tabletop_portrait_v1.png',
              fit: BoxFit.fill,
              excludeFromSemantics: true,
            ),
          ),
          const ColoredBox(color: Color(0x33000000)),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, bounds) {
                final compact =
                    bounds.maxWidth >= 560 &&
                    bounds.maxWidth > bounds.maxHeight &&
                    MediaQuery.textScalerOf(context).scale(14) <= 20;
                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(compact ? 12 : 16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: compact ? 900 : 440,
                      ),
                      child: compact && widget.decision != null
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _summary(compact: true),
                                      const SizedBox(height: 8),
                                      Row(
                                        textDirection: TextDirection.ltr,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: _team(false, compact: true),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _team(true, compact: true),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: _details(compact: true),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _summary(compact: compact),
                                SizedBox(height: compact ? 8 : 14),
                                if (compact)
                                  Row(
                                    textDirection: TextDirection.ltr,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _team(false, compact: true),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _team(true, compact: true),
                                      ),
                                    ],
                                  )
                                else ...[
                                  _team(widget.firstWon),
                                  const SizedBox(height: 12),
                                  _team(!widget.firstWon),
                                ],
                                SizedBox(height: compact ? 8 : 14),
                                _details(compact: compact),
                              ],
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _summary({required bool compact}) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        height: compact ? 34 : 56,
        child: const FittedBox(child: LanternWordmark()),
      ),
      if (!compact) ...[
        const SizedBox(height: 8),
        const Icon(
          Icons.emoji_events_rounded,
          size: 32,
          color: TableStyle.brass,
        ),
      ],
      Text(
        widget.title,
        textAlign: TextAlign.center,
        style: TableStyle.label.copyWith(
          fontSize: compact ? 24 : 28,
          fontWeight: FontWeight.w900,
        ),
      ),
      Text(
        widget.subtitle,
        textAlign: TextAlign.center,
        style: TableStyle.detail,
      ),
    ],
  );

  Widget _team(bool first, {bool compact = false}) => SizedBox(
    width: double.infinity,
    child: VelvetScoreTile(
      key: ValueKey(first ? 'final-first-team' : 'final-second-team'),
      label: first ? widget.firstTeam : widget.secondTeam,
      score: first ? widget.firstScore : widget.secondScore,
      scoreLabel: 'ui_round_score'.tr(),
      color: first ? TableStyle.mint : TableStyle.red,
      compact: compact,
      winner: first == widget.firstWon,
      players: first ? widget.firstPlayers : widget.secondPlayers,
    ),
  );

  Widget _details({required bool compact}) {
    final actions = <Widget>[
      if (widget.onReplay != null)
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: TableStyle.brass,
            foregroundColor: TableStyle.ink,
            minimumSize: const Size(48, 48),
            side: const BorderSide(color: Color(0xFFFFE2A4)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: _leaving || _replayRequested ? null : _replay,
          child: Text(
            widget.replayLabel,
            textAlign: TextAlign.center,
            style: TableStyle.label.copyWith(
              color: TableStyle.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: TableStyle.ink,
          foregroundColor: TableStyle.ivory,
          side: const BorderSide(color: TableStyle.brass),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: _leaving ? null : _home,
        child: Text(widget.homeLabel, textAlign: TextAlign.center),
      ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: TableStyle.ink,
            border: Border.all(color: TableStyle.brass.withValues(alpha: .65)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 24,
            runSpacing: 8,
            children: [
              _reward(Icons.star_rounded, widget.starsLabel, widget.stars),
              _reward(
                Icons.monetization_on_rounded,
                widget.coinsLabel,
                widget.coins,
              ),
            ],
          ),
        ),
        if (widget.decision != null) ...[
          const SizedBox(height: 8),
          widget.decision!,
        ],
        const SizedBox(height: 8),
        if (compact)
          Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: actions[i]),
              ],
            ],
          )
        else
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            actions[i],
          ],
      ],
    );
  }

  Widget _reward(IconData icon, String label, int value) => Semantics(
    label: '$label: $value',
    excludeSemantics: true,
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        Icon(icon, size: 20, color: TableStyle.brass),
        Text('$label $value', style: TableStyle.label),
      ],
    ),
  );
}
