import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../domain/models/capture.dart';
import 'team_capture_stack.dart';
import 'table_style.dart';

/// Physical table coordinates never depend on the language's reading direction.
/// Every motion origin and tap target inherits the same scene transform.
class OptionBGeometry {
  final Size size;
  final bool landscape;
  OptionBGeometry(Size viewport)
    : landscape = viewport.width > viewport.height,
      size = viewport.width > viewport.height
          ? Size(math.max(760, 430 * viewport.aspectRatio), 430)
          : Size(430, math.max(740, 430 / viewport.aspectRatio));

  Rect get local => const Rect.fromLTWH(8, 14, 126, 184);
  Rect get scores => landscape
      ? Rect.fromLTWH(size.width * .51, 8, 196, 64)
      : const Rect.fromLTWH(136, 8, 178, 64);
  Rect get history => Rect.fromLTWH(size.width - 108, 42, 100, 96);
  Rect get menu => Rect.fromLTWH(size.width - 93, 139, 70, 44);
  Rect get rivalPile => Rect.fromLTWH(size.width - 100, 191, 86, 132);
  Rect get partner => landscape
      ? Rect.fromLTWH(size.width * .25, 26, 238, 184)
      : const Rect.fromLTWH(82, 155, 238, 184);
  Rect get left =>
      Rect.fromLTWH(8, landscape ? 152 : size.height * .48, 126, 184);
  Rect get right => Rect.fromLTWH(
    landscape ? size.width - 257 : size.width - 134,
    landscape ? 152 : size.height * .48,
    126,
    184,
  );
  Rect get ourPile => Rect.fromLTWH(26, size.height - 120, 70, 112);
  Rect get hand => landscape
      ? Rect.fromLTWH(size.width * .47, size.height - 151, 302, 148)
      : Rect.fromLTWH(116, size.height - 188, 302, 180);
  Rect get board => landscape
      ? Rect.fromLTWH(size.width * .26, 212, size.width * .39, 96)
      : Rect.fromLTWH(132, size.height * .39, 166, 208);
  Rect get phase => landscape
      ? Rect.fromLTWH(size.width * .22, 194, size.width * .5, 204)
      : Rect.fromLTWH(56, size.height * .39, 318, 260);
}

class OptionBTable extends StatelessWidget {
  final Widget local, partner, left, right, scores, history, menu;
  final Widget ourPile, rivalPile, board, hand, phase;
  final bool showPhase;
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
          width: g.size.width,
          height: g.size.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              slot('board', g.board, SizedBox.expand(child: board)),
              slot('local', g.local, local),
              slot('partner', g.partner, partner),
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
                  g.phase,
                  SizedBox.expand(child: SingleChildScrollView(child: phase)),
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
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .055),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .6),
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
          fontSize: 26,
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
  final VoidCallback? onPressed;
  final TableCardBuilder faceBuilder;
  const TeamCapturePreview({
    super.key,
    required this.captures,
    required this.label,
    required this.faceBuilder,
    this.onPressed,
  });
  @override
  Widget build(BuildContext context) {
    final played = captures.where((c) => !c.isRoundAward).toList();
    final recent = played.skip(math.max(0, played.length - 2)).toList();
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 58,
                child: Row(
                  textDirection: TextDirection.ltr,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final capture in recent)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ExcludeSemantics(
                          child: faceBuilder(capture.leadingCard, 38, 54),
                        ),
                      ),
                    if (recent.isEmpty)
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
                  horizontal: 10,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: TableStyle.ink,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: TableStyle.mint.withValues(alpha: .6),
                  ),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  style: TableStyle.detail.copyWith(color: TableStyle.brass),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
