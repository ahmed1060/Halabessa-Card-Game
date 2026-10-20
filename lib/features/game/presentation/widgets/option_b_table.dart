import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../domain/models/capture.dart';
import 'team_capture_stack.dart';
import 'table_style.dart';

/// Physical table coordinates never depend on the language's reading direction.
/// Every motion origin and tap target inherits the same scene transform.
class OptionBGeometry {
  static const tableCardSize = Size(64, 92);
  static const localHandSpread = 1.15;
  final Size size;
  final bool landscape;
  OptionBGeometry(Size viewport)
    : landscape = viewport.width > viewport.height,
      size = viewport.width > viewport.height
          ? Size(math.max(760, 430 * viewport.aspectRatio), 430)
          : Size(430, math.max(740, 430 / viewport.aspectRatio));

  Rect get local => Rect.fromLTWH(
    landscape ? size.width * .075 : 6,
    landscape ? 48 : 96,
    126,
    184,
  );
  Rect get scores => landscape
      ? Rect.fromLTWH(size.width * .5 - 71, 0, 142, 40)
      : const Rect.fromLTWH(144, 30, 142, 50);
  Rect get history => Rect.fromLTWH(
    size.width - (landscape ? 218 : 131),
    landscape ? 32 : 106,
    116,
    102,
  );
  Rect get menu => Rect.fromLTWH(
    landscape ? history.center.dx - 22 : history.right - 44,
    history.bottom + 4,
    44,
    44,
  );
  // Invisible collection anchors terminate at the corresponding history count.
  Rect get rivalPile =>
      Rect.fromLTWH(history.right - 22, history.bottom - 22, 20, 20);
  Rect get partner => landscape
      ? Rect.fromLTWH(size.width * .5 - 63, 40, 126, 184)
      : const Rect.fromLTWH(156, 190, 126, 184);
  Rect get deck =>
      Rect.fromLTWH(partner.left - 70, landscape ? 42 : 196, 64, 144);
  Rect get left => Rect.fromLTWH(
    landscape ? size.width * .045 : 6,
    landscape ? 170 : size.height * .43,
    126,
    184,
  );
  Rect get right => Rect.fromLTWH(
    landscape ? size.width * .835 : size.width - 132,
    landscape ? 170 : size.height * .43,
    126,
    184,
  );
  Rect get ourPile =>
      Rect.fromLTWH(history.left + 2, history.bottom - 22, 20, 20);
  Rect get hand => landscape
      ? Rect.fromLTWH(
          (size.width - size.width * .28 * localHandSpread) / 2,
          size.height - 134,
          size.width * .28 * localHandSpread,
          130,
        )
      : Rect.fromLTWH(
          (size.width - 310 * localHandSpread) / 2,
          size.height - 212,
          310 * localHandSpread,
          190,
        );
  Rect get board => landscape
      ? Rect.fromCenter(
          center: size.center(Offset.zero),
          width: size.width * .18,
          height: 132,
        )
      : Rect.fromCenter(
          center: size.center(Offset.zero),
          width: 166,
          height: 208,
        );
  // The phase prompt uses the real deck anchor, never a second presentation deck.
  Rect get cutDeck => deck;
  // Preserve the approved pre-deal popover space; no hand is shown yet.
  Rect get preCutPartner => landscape ? partner : partner.translate(0, -94);
  Rect get cutPopover => landscape
      ? Rect.fromLTWH(deck.left - 40, deck.top + 116, 252, 172)
      : Rect.fromLTWH(deck.right + 8, deck.top + 30, 240, 180);
  Rect get phase => landscape
      ? Rect.fromLTWH(size.width * .22, 194, size.width * .5, 204)
      : Rect.fromLTWH(56, size.height * .39, 318, 260);
}

class OptionBTable extends StatelessWidget {
  final Widget local, partner, left, right, scores, history, menu;
  final Widget ourPile, rivalPile, board, hand, phase;
  final Widget deck;
  final bool showPhase;
  final bool deckSidePhase;
  final GlobalKey? sceneKey;
  const OptionBTable({
    super.key,
    required this.local,
    required this.partner,
    required this.left,
    required this.right,
    required this.scores,
    required this.history,
    required this.menu,
    required this.ourPile,
    required this.rivalPile,
    required this.board,
    required this.hand,
    required this.phase,
    required this.showPhase,
    this.deckSidePhase = false,
    this.deck = const SizedBox.shrink(),
    this.sceneKey,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final g = OptionBGeometry(bounds.biggest);
      Widget slot(String name, Rect rect, Widget child) => Positioned.fromRect(
        rect: rect,
        child: Align(
          key: ValueKey('option-b-$name'),
          alignment: Alignment.topCenter,
          child: child,
        ),
      );
      return FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          key: sceneKey,
          width: g.size.width,
          height: g.size.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              slot('board', g.board, SizedBox.expand(child: board)),
              slot('local', g.local, local),
              slot(
                'partner',
                deckSidePhase ? g.preCutPartner : g.partner,
                partner,
              ),
              slot('deck', deckSidePhase ? g.cutDeck : g.deck, deck),
              slot('left', g.left, left),
              slot('right', g.right, right),
              slot('our-pile', g.ourPile, ourPile),
              slot('rival-pile', g.rivalPile, rivalPile),
              slot('hand', g.hand, SizedBox.expand(child: hand)),
              slot('history', g.history, history),
              slot('menu', g.menu, menu),
              // The collapsible HUD is an overlay, never a row that pushes the seats.
              slot('scores', g.scores, scores),
              if (showPhase)
                slot(
                  'phase',
                  deckSidePhase ? g.cutPopover : g.phase,
                  SizedBox.expand(
                    child: SingleChildScrollView(
                      clipBehavior: Clip.none,
                      child: phase,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class ClearScoreDisplay extends StatefulWidget {
  final int ourScore, phase, rivalScore;
  final String label, hideLabel, showLabel;
  const ClearScoreDisplay({
    super.key,
    required this.ourScore,
    required this.phase,
    required this.rivalScore,
    required this.label,
    required this.hideLabel,
    required this.showLabel,
  });
  @override
  State<ClearScoreDisplay> createState() => _ClearScoreDisplayState();
}

class _ClearScoreDisplayState extends State<ClearScoreDisplay> {
  bool _open = true;
  double _drag = 0;
  void _toggle() => setState(() => _open = !_open);
  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return Semantics(
      label: widget.label,
      button: true,
      expanded: _open,
      onTap: _toggle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        onVerticalDragStart: (_) => _drag = 0,
        onVerticalDragUpdate: (details) => _drag += details.delta.dy,
        onVerticalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (_drag.abs() > 12 || velocity.abs() > 50) {
            setState(() => _open = (_drag.abs() > 12 ? _drag : velocity) > 0);
          }
        },
        child: Column(
          children: [
            AnimatedSlide(
              offset: _open ? Offset.zero : const Offset(0, -1.4),
              duration: duration,
              child: AnimatedOpacity(
                opacity: _open ? 1 : 0,
                duration: duration,
                child: IgnorePointer(
                  ignoring: !_open,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                      child: Container(
                        key: const ValueKey('clear-score-glass'),
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .055),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: TableStyle.brass.withValues(alpha: .8),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: .16),
                              Colors.white.withValues(alpha: .015),
                            ],
                          ),
                        ),
                        child: Row(
                          textDirection: TextDirection.ltr,
                          children: [
                            _number(widget.ourScore, TableStyle.mint),
                            _divider(),
                            _number(widget.phase, TableStyle.ivory),
                            _divider(),
                            _number(widget.rivalScore, TableStyle.red),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Always-present grab target supports touch, keyboard and screen readers.
            Expanded(
              child: AnimatedSlide(
                offset: _open ? Offset.zero : const Offset(0, -2.5),
                duration: duration,
                child: Tooltip(
                  message: _open ? widget.hideLabel : widget.showLabel,
                  child: InkWell(
                    onTap: _toggle,
                    borderRadius: BorderRadius.circular(10),
                    child: Center(
                      child: Container(
                        width: 30,
                        height: 3,
                        decoration: BoxDecoration(
                          color: TableStyle.ivory.withValues(alpha: .8),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _number(int value, Color color) => Expanded(
    child: Center(
      child: Text(
        '$value',
        textScaler: TextScaler.noScaling,
        style: TableStyle.label.copyWith(
          fontSize: 21,
          fontWeight: FontWeight.w800,
          color: color,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
        ),
      ),
    ),
  );
  Widget _divider() => Container(width: 1, height: 24, color: Colors.white38);
}

class CompactCollectedPile extends StatelessWidget {
  final String label;
  final int count;
  final Color accent;
  final bool small;
  final GlobalKey pileKey;
  final Widget Function(double, double) backBuilder;
  const CompactCollectedPile({
    super.key,
    required this.label,
    required this.count,
    required this.pileKey,
    required this.backBuilder,
    this.small = false,
    this.accent = TableStyle.mint,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $count',
    excludeSemantics: true,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FaceDownStack(
          key: pileKey,
          count: count,
          backBuilder: backBuilder,
          width: small ? 36 : 48,
          height: small ? 52 : 68,
          animateGrowth: true,
        ),
        Container(
          key: const ValueKey('collected-count-tile'),
          width: small ? 40 : 72,
          decoration: BoxDecoration(
            color: TableStyle.ink,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: accent, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                color: accent,
                width: double.infinity,
                alignment: Alignment.center,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: TextScaler.noScaling,
                  style: TableStyle.detail.copyWith(
                    color: TableStyle.ink,
                    fontSize: small ? 9 : 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$count',
                textScaler: TextScaler.noScaling,
                style: TableStyle.label.copyWith(
                  fontSize: small ? 18 : 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Only the team's played capture cards from the current round are previewed.
class TeamCapturePreview extends StatelessWidget {
  final List<Capture> captures;
  final String label;
  final String? semanticsLabel;
  final VoidCallback? onPressed;
  final TableCardBuilder faceBuilder;
  final int ourCount, rivalCount;
  final Widget Function(double, double)? emptyBackBuilder;
  const TeamCapturePreview({
    super.key,
    required this.captures,
    required this.label,
    this.semanticsLabel,
    required this.faceBuilder,
    this.ourCount = 0,
    this.rivalCount = 0,
    this.emptyBackBuilder,
    this.onPressed,
  });
  @override
  Widget build(BuildContext context) {
    final played = captures.where((c) => !c.isRoundAward).toList();
    final recent = played.skip(math.max(0, played.length - 2)).toList();
    return Semantics(
      button: true,
      label: semanticsLabel ?? label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: TableStyle.ink,
              border: Border.all(color: TableStyle.brass),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 64,
                  child: Row(
                    textDirection: TextDirection.ltr,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final capture in recent)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: ExcludeSemantics(
                            child: faceBuilder(capture.leadingCard, 44, 62),
                          ),
                        ),
                      if (recent.isEmpty && emptyBackBuilder != null)
                        for (var i = 0; i < 2; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: emptyBackBuilder!(44, 62),
                          ),
                      if (recent.isEmpty && emptyBackBuilder == null)
                        const Icon(
                          Icons.style_outlined,
                          color: TableStyle.muted,
                          size: 32,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: TableStyle.ink,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: TableStyle.mint.withValues(alpha: .6),
                    ),
                  ),
                  child: Row(
                    textDirection: TextDirection.ltr,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _count(ourCount, TableStyle.mint),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TableStyle.detail.copyWith(
                              color: TableStyle.brass,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      _count(rivalCount, TableStyle.red),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _count(int count, Color accent) => Container(
    key: ValueKey(
      accent == TableStyle.mint ? 'history-our-count' : 'history-rival-count',
    ),
    constraints: const BoxConstraints(minWidth: 20),
    padding: const EdgeInsets.symmetric(horizontal: 2),
    decoration: BoxDecoration(
      color: accent,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      '$count',
      textAlign: TextAlign.center,
      textScaler: TextScaler.noScaling,
      style: TableStyle.label.copyWith(
        color: TableStyle.ink,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
