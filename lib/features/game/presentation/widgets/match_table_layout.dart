import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'table_style.dart';

/// Geometry only. Match state, rules and navigation stay outside this widget.
class MatchTableLayout extends StatelessWidget {
  final Widget header;
  final Widget partner;
  final Widget leftOpponent;
  final Widget rightOpponent;
  final Widget board;
  final Widget hand;
  final Widget status;
  final Widget controls;

  const MatchTableLayout({super.key, required this.header, required this.partner,
    required this.leftOpponent, required this.rightOpponent, required this.board,
    required this.hand, required this.status, required this.controls});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, bounds) {
    final wide = bounds.maxWidth >= 700 && bounds.maxWidth > bounds.maxHeight;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    // Header and tray keep their intrinsic text height. The arena has its own
    // minimum; a large header must never steal the side players' layout space.
    // One outer scroll view handles small windows and accessibility text sizes.
    final arenaHeight = math.max(260.0 * math.max(1.0, textScale),
        bounds.maxHeight - (wide ? 140.0 : 310.0) * textScale);
    final arena = Column(children: [
      Padding(padding: const EdgeInsets.only(top: 8), child: partner),
      Expanded(child: Row(children: [
        SizedBox(width: 82, child: leftOpponent),
        Expanded(child: Center(child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(width: 230, height: 200, child: board),
        ))),
        SizedBox(width: 82, child: rightOpponent),
      ])),
    ]);
    final tray = ColoredBox(
      key: const ValueKey('table-hand-tray'),
      color: TableStyle.ink.withOpacity(0.96),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          status,
          const SizedBox(height: 4),
          hand,
        ]),
      ),
    );
    return SingleChildScrollView(
      child: Column(children: [
        header,
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(child: SizedBox(height: arenaHeight, child: arena)),
              SizedBox(width: math.min(340.0, bounds.maxWidth * 0.4),
                child: tray),
            ])
        else ...[
          SizedBox(height: arenaHeight, child: arena),
          tray,
        ],
        Material(color: TableStyle.ink, child: controls),
      ]),
    );
  });
}

class MatchScoreBar extends StatelessWidget {
  final String firstLabel;
  final String secondLabel;
  final int firstScore;
  final int secondScore;
  final String details;
  final String roomLabel;
  final VoidCallback onCopyRoom;
  const MatchScoreBar({super.key, required this.firstLabel, required this.secondLabel,
    required this.firstScore, required this.secondScore, required this.details,
    required this.roomLabel, required this.onCopyRoom});

  @override
  Widget build(BuildContext context) => Material(
    color: TableStyle.ink,
    child: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 2), child: Column(children: [
      Row(children: [
        Expanded(child: _score(firstLabel, firstScore)),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(':', style: TableStyle.label)),
        Expanded(child: _score(secondLabel, secondScore)),
      ]),
      Row(children: [
        Expanded(child: Text(details, style: TableStyle.detail)),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: TableStyle.muted,
            minimumSize: const Size(48, 48)),
          onPressed: onCopyRoom, icon: const Icon(Icons.copy_outlined, size: 16),
          label: Text(roomLabel, style: TableStyle.detail),
        ),
      ]),
    ])),
  );

  Widget _score(String label, int score) => Semantics(
    label: '$label: $score', excludeSemantics: true,
    child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10, children: [
        Text(label, style: TableStyle.label, textAlign: TextAlign.center),
        Text('$score', style: TableStyle.label.copyWith(fontSize: 24, fontWeight: FontWeight.bold)),
      ]),
  );
}
