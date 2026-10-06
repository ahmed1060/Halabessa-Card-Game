import 'dart:async';
import 'package:flutter/material.dart';
import 'table_style.dart';
import 'match_table_layout.dart';
import '../../../../core/widgets/lantern_page_frame.dart';
import '../../../../core/widgets/lantern_panel.dart';

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
    child: LanternPageFrame(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth >= 560 &&
                  constraints.maxHeight < 600 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 20;
              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(
                    compact && widget.decision != null ? 12 : 20,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: compact ? 880 : 440),
                    child: compact
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: _summary(compact: true)),
                              const SizedBox(width: 32),
                              Expanded(
                                flex: widget.decision != null ? 2 : 1,
                                child: _details(compact: true),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _summary(),
                              const SizedBox(height: 24),
                              _details(),
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
  );

  Widget _summary({bool compact = false}) => LanternPanel(
    padding: EdgeInsets.all(compact ? 16 : 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: compact ? 56 : 80,
          child: const FittedBox(child: LanternWordmark()),
        ),
        SizedBox(height: compact ? 12 : 24),
        Icon(
          Icons.emoji_events_rounded,
          size: compact ? 42 : 52,
          color: TableStyle.brass,
        ),
        const SizedBox(height: 12),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: TableStyle.label.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: TableStyle.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.subtitle,
          textAlign: TextAlign.center,
          style: TableStyle.label.copyWith(color: TableStyle.ink),
        ),
        if ((widget.firstWon ? widget.firstPlayers : widget.secondPlayers) !=
            null) ...[
          const SizedBox(height: 16),
          (widget.firstWon ? widget.firstPlayers : widget.secondPlayers)!,
          const SizedBox(height: 8),
          Text(
            widget.firstWon ? widget.firstTeam : widget.secondTeam,
            style: TableStyle.label.copyWith(color: TableStyle.ink),
          ),
        ],
        if ((widget.firstWon ? widget.secondPlayers : widget.firstPlayers) !=
                null &&
            !compact) ...[
          const SizedBox(height: 16),
          (widget.firstWon ? widget.secondPlayers : widget.firstPlayers)!,
          const SizedBox(height: 8),
          Text(
            widget.firstWon ? widget.secondTeam : widget.firstTeam,
            style: TableStyle.detail.copyWith(color: TableStyle.ink),
          ),
        ],
      ],
    ),
  );

  Widget _details({bool compact = false}) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (compact && widget.decision != null)
        Row(
          children: [
            Expanded(
              child: _score(
                widget.firstTeam,
                widget.firstScore,
                TableStyle.mint,
                compact: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _score(
                widget.secondTeam,
                widget.secondScore,
                TableStyle.red,
                compact: true,
              ),
            ),
          ],
        )
      else ...[
        _score(
          widget.firstTeam,
          widget.firstScore,
          TableStyle.mint,
          compact: compact,
        ),
        const SizedBox(height: 8),
        _score(
          widget.secondTeam,
          widget.secondScore,
          TableStyle.red,
          compact: compact,
        ),
      ],
      SizedBox(
        height: compact && widget.decision != null
            ? 6
            : compact
            ? 12
            : 16,
      ),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 24,
        runSpacing: 12,
        children: [
          _reward(Icons.star_rounded, widget.starsLabel, widget.stars),
          _reward(
            Icons.monetization_on_rounded,
            widget.coinsLabel,
            widget.coins,
          ),
        ],
      ),
      SizedBox(
        height: compact && widget.decision != null
            ? 6
            : compact
            ? 12
            : 20,
      ),
      if (widget.decision != null) ...[
        widget.decision!,
        const SizedBox(height: 10),
      ],
      if (widget.onReplay != null) ...[
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: TableStyle.brass,
            foregroundColor: TableStyle.ink,
            minimumSize: const Size(48, 52),
          ),
          onPressed: _leaving || _replayRequested ? null : _replay,
          child: Text(widget.replayLabel),
        ),
        const SizedBox(height: 10),
      ],
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: TableStyle.ivory,
          minimumSize: const Size(48, 52),
        ),
        onPressed: _leaving ? null : _home,
        child: Text(widget.homeLabel),
      ),
    ],
  );

  Widget _score(String label, int score, Color color, {bool compact = false}) =>
      Semantics(
        label: '$label: $score',
        excludeSemantics: true,
        child: Container(
          padding: EdgeInsets.all(compact ? 12 : 16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label  ',
                  style: TableStyle.label.copyWith(color: TableStyle.ink),
                ),
                TextSpan(
                  text: '$score',
                  style: TableStyle.label.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: TableStyle.ink,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
  Widget _reward(IconData icon, String label, int value) => Semantics(
    label: '$label: $value',
    excludeSemantics: true,
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.center,
      spacing: 6,
      children: [
        Icon(icon, size: 20, color: TableStyle.brass),
        Text('$label $value', style: TableStyle.label),
      ],
    ),
  );
}
