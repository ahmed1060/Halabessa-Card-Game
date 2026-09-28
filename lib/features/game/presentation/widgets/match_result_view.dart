import 'package:flutter/material.dart';
import 'table_style.dart';

/// The only final-results surface. It owns no match rules or reward writes.
class MatchResultView extends StatefulWidget {
  final String title, subtitle, firstTeam, secondTeam;
  final int firstScore, secondScore, stars, coins;
  final String starsLabel, coinsLabel, homeLabel, replayLabel;
  final VoidCallback onHome;
  final VoidCallback? onReplay;
  const MatchResultView({super.key, required this.title, required this.subtitle,
    required this.firstTeam, required this.secondTeam, required this.firstScore,
    required this.secondScore, required this.stars, required this.coins,
    required this.starsLabel, required this.coinsLabel,
    required this.homeLabel, required this.replayLabel,
    required this.onHome, this.onReplay});

  @override
  State<MatchResultView> createState() => _MatchResultViewState();
}

class _MatchResultViewState extends State<MatchResultView> {
  bool _leaving = false;
  void _home() {
    if (_leaving) return;
    setState(() => _leaving = true);
    widget.onHome();
  }
  void _replay() {
    if (_leaving || widget.onReplay == null) return;
    setState(() => _leaving = true);
    widget.onReplay!();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvoked: (didPop) { if (!didPop) _home(); },
    child: Scaffold(
    backgroundColor: TableStyle.ink,
    body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, textAlign: TextAlign.center,
              style: TableStyle.label.copyWith(fontSize: 28, fontWeight: FontWeight.bold,
                color: TableStyle.brass)),
            const SizedBox(height: 8),
            Text(widget.subtitle, textAlign: TextAlign.center, style: TableStyle.label),
            const SizedBox(height: 24),
            _score(widget.firstTeam, widget.firstScore),
            const SizedBox(height: 8),
            _score(widget.secondTeam, widget.secondScore),
            const SizedBox(height: 24),
            Wrap(alignment: WrapAlignment.center, spacing: 24, runSpacing: 12, children: [
              _reward(Icons.star_rounded, widget.starsLabel, widget.stars),
              _reward(Icons.monetization_on_rounded, widget.coinsLabel, widget.coins),
            ]),
            const SizedBox(height: 28),
            if (widget.onReplay != null) ...[
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: TableStyle.brass,
                  foregroundColor: TableStyle.ink, minimumSize: const Size(48, 52)),
                onPressed: _leaving ? null : _replay, child: Text(widget.replayLabel)),
              const SizedBox(height: 10),
            ],
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: TableStyle.ivory,
                minimumSize: const Size(48, 52)),
              onPressed: _leaving ? null : _home, child: Text(widget.homeLabel)),
          ]),
      ),
    ))),
  ));

  Widget _score(String label, int score) => Semantics(
    label: '$label: $score', excludeSemantics: true,
    child: Row(children: [
      Expanded(child: Text(label, style: TableStyle.label)),
      Text('$score', style: TableStyle.label.copyWith(fontSize: 24, fontWeight: FontWeight.bold)),
    ]),
  );
  Widget _reward(IconData icon, String label, int value) => Semantics(
    label: '$label: $value', excludeSemantics: true,
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 20, color: TableStyle.brass),
      const SizedBox(width: 6),
      Text('$label $value', style: TableStyle.label),
    ]),
  );
}
