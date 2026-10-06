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
  final Widget? collections;
  final Widget? localSeat;

  const MatchTableLayout({
    super.key,
    required this.header,
    required this.partner,
    required this.leftOpponent,
    required this.rightOpponent,
    required this.board,
    required this.hand,
    required this.status,
    required this.controls,
    this.collections,
    this.localSeat,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      if (collections != null) return _lanternComposition(context, bounds);
      final wide = bounds.maxWidth >= 700 && bounds.maxWidth > bounds.maxHeight;
      // A roomy landscape table keeps the player's hand beneath the play, so
      // the four seats and the card flight share one visual center. Very short
      // landscape screens retain the side tray to avoid hiding the board.
      final fullTable = wide && bounds.maxHeight >= 600;
      final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
      // Header and tray keep their intrinsic text height. The arena has its own
      // minimum; a large header must never steal the side players' layout space.
      // Only the play area scrolls on small windows and at larger text sizes.
      final arenaHeight = math.max(
        360.0 * math.max(1.0, textScale),
        bounds.maxHeight -
            (collections == null
                    ? (fullTable
                          ? 300.0
                          : wide
                          ? 140.0
                          : 310.0)
                    : (fullTable
                          ? 340.0
                          : wide
                          ? 140.0
                          : 490.0)) *
                textScale,
      );
      final arena = Column(
        children: [
          Padding(padding: const EdgeInsets.only(top: 8), child: partner),
          Expanded(
            child: Row(
              // Seats are physical table positions, not reading-order content.
              textDirection: TextDirection.ltr,
              children: [
                SizedBox(width: 82, child: leftOpponent),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: fullTable ? 280 : 230,
                        height: fullTable ? 240 : 200,
                        child: board,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 82, child: rightOpponent),
              ],
            ),
          ),
        ],
      );
      final tableSurface = fullTable && collections != null
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: SizedBox(
                  height: arenaHeight,
                  child: Row(
                    children: [
                      Expanded(child: arena),
                      SizedBox(
                        width: 300,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: collections!,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : Column(
              children: [
                SizedBox(height: arenaHeight, child: arena),
                if (collections != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: collections!,
                  ),
              ],
            );
      final tray = ColoredBox(
        key: const ValueKey('table-hand-tray'),
        color: TableStyle.ink.withValues(alpha: 0.96),
        child: ConstrainedBox(
          // Dealing, capture, and turn changes must not collapse the hand region
          // and move the rest of the table each time the cards disappear.
          constraints: const BoxConstraints(minHeight: 168),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                status,
                const SizedBox(height: 4),
                if (localSeat == null)
                  hand
                else
                  Row(
                    children: [
                      Expanded(child: hand),
                      SizedBox(width: 68, child: localSeat!),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
      return Column(
        children: [
          // Keep scores and round context visible while a short viewport scrolls
          // through the arena, phase action, hand, and controls.
          header,
          if (collections != null && (!wide || fullTable)) ...[
            Expanded(child: SingleChildScrollView(child: tableSurface)),
            SizedBox(width: bounds.maxWidth, child: tray),
            Material(color: TableStyle.ink, child: controls),
          ] else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (fullTable) ...[
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 980),
                          child: tableSurface,
                        ),
                      ),
                      Center(
                        child: SizedBox(
                          width: math.min(980, bounds.maxWidth),
                          child: tray,
                        ),
                      ),
                    ] else if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: tableSurface),
                          SizedBox(
                            width: math.min(340.0, bounds.maxWidth * 0.4),
                            child: tray,
                          ),
                        ],
                      )
                    else ...[
                      tableSurface,
                      SizedBox(width: bounds.maxWidth, child: tray),
                    ],
                    Material(color: TableStyle.ink, child: controls),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );

  /// One physical table coordinate system for seats, hands and card flights.
  /// At normal text sizes G1's hand stays below the arena in both orientations.
  /// Large text uses a scrolling layout rather than shrinking readable content.
  Widget _lanternComposition(BuildContext context, BoxConstraints bounds) {
    final wide = bounds.maxWidth > bounds.maxHeight && bounds.maxWidth >= 700;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 18;
    final shortLandscape = wide && bounds.maxHeight < 500 && !largeText;
    Widget remoteSeat(Widget seat) => shortLandscape
        ? SizedBox(
            height: 146,
            child: FittedBox(fit: BoxFit.scaleDown, child: seat),
          )
        : seat;
    final arena = largeText
        ? Column(
            children: [
              partner,
              Row(
                textDirection: TextDirection.ltr,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: leftOpponent),
                  Expanded(child: rightOpponent),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(height: 160, child: board),
            ],
          )
        : SizedBox(
            height: shortLandscape
                ? 260
                : wide
                ? 320
                : 310,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: remoteSeat(partner),
                ),
                Positioned(
                  left: wide ? 20 : 0,
                  top: shortLandscape
                      ? 50
                      : wide
                      ? 74
                      : 132,
                  width: wide ? 130 : 84,
                  child: remoteSeat(leftOpponent),
                ),
                Positioned(
                  right: wide ? 20 : 0,
                  top: shortLandscape
                      ? 50
                      : wide
                      ? 74
                      : 132,
                  width: wide ? 130 : 84,
                  child: remoteSeat(rightOpponent),
                ),
                Positioned(
                  left: wide ? 190 : 90,
                  right: wide ? 190 : 90,
                  bottom: 0,
                  height: shortLandscape
                      ? 100
                      : wide
                      ? 160
                      : 140,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: wide ? 340 : 250,
                        height: wide ? 160 : 140,
                        child: board,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
    final handArea = ConstrainedBox(
      key: const ValueKey('table-hand-tray'),
      constraints: const BoxConstraints(minHeight: 164),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          status,
          const SizedBox(height: 4),
          Row(
            textDirection: TextDirection.ltr,
            children: [
              if (localSeat != null) const SizedBox(width: 56),
              Expanded(child: hand),
              if (localSeat != null) SizedBox(width: 56, child: localSeat!),
            ],
          ),
        ],
      ),
    );
    Widget surface() => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        arena,
        if (!wide)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: collections!,
          ),
        if (wide)
          Row(
            textDirection: TextDirection.ltr,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(flex: 3, child: handArea),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: collections!,
                ),
              ),
            ],
          )
        else
          handArea,
      ],
    );
    return Column(
      children: [
        header,
        Expanded(
          child: largeText
              ? SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: surface(),
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, available) {
                    final logicalWidth = wide ? 920.0 : 430.0;
                    final minimumHeight = wide ? 484.0 : 620.0;
                    final scale = math.min(
                      available.maxWidth / logicalWidth,
                      available.maxHeight / minimumHeight,
                    );
                    // Preserve usable card targets on unusually short windows.
                    // Scrolling the arena is preferable to shrinking every action.
                    if (!wide && scale < .7) {
                      return SingleChildScrollView(child: surface());
                    }
                    // A single fit transform applies equally to painted cards, hit
                    // targets and the measured GlobalKeys used by card-flight motion.
                    return Center(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(width: logicalWidth, child: surface()),
                      ),
                    );
                  },
                ),
        ),
        controls,
      ],
    );
  }
}

class MatchScoreBar extends StatelessWidget {
  final String firstLabel;
  final String secondLabel;
  final int firstScore;
  final int secondScore;
  final String details;
  final String roomLabel;
  final VoidCallback? onCopyRoom;
  const MatchScoreBar({
    super.key,
    required this.firstLabel,
    required this.secondLabel,
    required this.firstScore,
    required this.secondScore,
    required this.details,
    required this.roomLabel,
    required this.onCopyRoom,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 700 &&
        MediaQuery.sizeOf(context).height < 500 &&
        MediaQuery.textScalerOf(context).scale(14) <= 16.8) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: Row(
          children: [
            const SizedBox(
              width: 100,
              child: FittedBox(child: LanternWordmark()),
            ),
            const SizedBox(width: 8),
            Expanded(child: _scoreRow()),
            if (onCopyRoom != null)
              IconButton(
                onPressed: onCopyRoom,
                tooltip: roomLabel,
                icon: const Icon(
                  Icons.copy_outlined,
                  color: TableStyle.ivory,
                  size: 18,
                ),
              ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: Column(
        children: [
          if (MediaQuery.sizeOf(context).width >= 700)
            Row(
              children: [
                const SizedBox(width: 160, child: LanternWordmark()),
                const SizedBox(width: 12),
                Expanded(child: _scoreRow()),
              ],
            )
          else ...[
            const LanternWordmark(),
            const SizedBox(height: 4),
            _scoreRow(),
          ],
          Row(
            children: [
              const Spacer(),
              if (onCopyRoom == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(roomLabel, style: TableStyle.detail),
                )
              else
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: TableStyle.muted,
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: onCopyRoom,
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  label: Text(roomLabel, style: TableStyle.detail),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scoreRow() => Row(
    children: [
      Expanded(child: _score(firstLabel, firstScore, TableStyle.mint)),
      const SizedBox(width: 4),
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: TableStyle.ink,
            border: Border.all(color: TableStyle.mint),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            details,
            textAlign: TextAlign.center,
            style: TableStyle.detail.copyWith(
              color: TableStyle.ivory,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      const SizedBox(width: 4),
      Expanded(child: _score(secondLabel, secondScore, TableStyle.red)),
    ],
  );
  Widget _score(String label, int score, Color accent) => Semantics(
    label: '$label: $score',
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TableStyle.ink, width: 2),
        boxShadow: const [
          BoxShadow(color: TableStyle.ink, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TableStyle.detail.copyWith(
              color: TableStyle.ink,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            '$score',
            style: TableStyle.label.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: TableStyle.ink,
            ),
          ),
        ],
      ),
    ),
  );
}

class LanternWordmark extends StatelessWidget {
  const LanternWordmark({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'حلبسه — Halabessa',
    excludeSemantics: true,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            Text(
              'حلبسه',
              textDirection: TextDirection.rtl,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: 'LanternArabic',
                fontSize: 44,
                height: 1.0,
                fontWeight: FontWeight.w900,
                foreground: Paint()
                  ..color = TableStyle.ink
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 5,
              ),
            ),
            const Text(
              'حلبسه',
              textDirection: TextDirection.rtl,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: 'LanternArabic',
                fontSize: 44,
                height: 1.0,
                fontWeight: FontWeight.w900,
                color: TableStyle.brass,
              ),
            ),
          ],
        ),
        const Text(
          'Halabessa',
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontFamily: 'LanternDisplay',
            fontSize: 16,
            height: 1.1,
            fontWeight: FontWeight.w800,
            color: TableStyle.brass,
          ),
        ),
      ],
    ),
  );
}
