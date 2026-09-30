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
    // A roomy landscape table keeps the player's hand beneath the play, so
    // the four seats and the card flight share one visual center. Very short
    // landscape screens retain the side tray to avoid hiding the board.
    final fullTable = wide && bounds.maxHeight >= 600;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    // Header and tray keep their intrinsic text height. The arena has its own
    // minimum; a large header must never steal the side players' layout space.
    // Only the play area scrolls on small windows and at larger text sizes.
    final arenaHeight = math.max(260.0 * math.max(1.0, textScale),
        bounds.maxHeight - (fullTable ? 300.0 : wide ? 140.0 : 310.0) * textScale);
    final arena = Column(children: [
      Padding(padding: const EdgeInsets.only(top: 8), child: partner),
      Expanded(child: Row(children: [
        SizedBox(width: 82, child: leftOpponent),
        Expanded(child: Center(child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(width: fullTable ? 280 : 230,
            height: fullTable ? 240 : 200, child: board),
        ))),
        SizedBox(width: 82, child: rightOpponent),
      ])),
    ]);
    final tray = ColoredBox(
      key: const ValueKey('table-hand-tray'),
      color: TableStyle.ink.withOpacity(0.96),
      child: ConstrainedBox(
        // Dealing, capture, and turn changes must not collapse the hand region
        // and move the rest of the table each time the cards disappear.
        constraints: const BoxConstraints(minHeight: 168),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            status,
            const SizedBox(height: 4),
            hand,
          ]),
        ),
      ),
    );
    return Column(children: [
      // Keep scores and round context visible while a short viewport scrolls
      // through the arena, phase action, hand, and controls.
      header,
      Expanded(child: SingleChildScrollView(
        child: Column(children: [
          if (fullTable) ...[
            Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: SizedBox(height: arenaHeight, child: arena),
            )),
            Center(child: SizedBox(
              width: math.min(980, bounds.maxWidth), child: tray,
            )),
          ] else if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(child: SizedBox(height: arenaHeight, child: arena)),
              SizedBox(width: math.min(340.0, bounds.maxWidth * 0.4),
                child: tray),
            ])
          else ...[
            SizedBox(height: arenaHeight, child: arena),
            SizedBox(width: bounds.maxWidth, child: tray),
          ],
          Material(color: TableStyle.ink, child: controls),
        ]),
      )),
    ]);
  });
}

class MatchScoreBar extends StatelessWidget {
  final String firstLabel;
  final String secondLabel;
  final int firstScore;
  final int secondScore;
  final String details;
  final String roomLabel;
  final VoidCallback? onCopyRoom;
  const MatchScoreBar({super.key, required this.firstLabel, required this.secondLabel,
    required this.firstScore, required this.secondScore, required this.details,
    required this.roomLabel, required this.onCopyRoom});

  @override
  Widget build(BuildContext context) => Material(
    color: TableStyle.ink,
    child: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 2), child: Column(children: [
      Row(children: [
        Expanded(child: _score(firstLabel, firstScore)),
        Container(width: 1, height: 36, margin: const EdgeInsets.symmetric(horizontal: 10),
          color: TableStyle.brass.withOpacity(0.45)),
        Expanded(child: _score(secondLabel, secondScore)),
      ]),
      Row(children: [
        Expanded(child: Text(details, style: TableStyle.detail)),
        if (onCopyRoom == null)
          Padding(padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(roomLabel, style: TableStyle.detail))
        else
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
    child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TableStyle.detail.copyWith(color: TableStyle.muted),
          textAlign: TextAlign.center),
        Text('$score', style: TableStyle.label.copyWith(fontSize: 26,
          fontWeight: FontWeight.bold, color: TableStyle.ivory)),
      ]),
  );
}
