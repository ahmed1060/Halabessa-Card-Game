import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/models/capture.dart';
import '../../domain/models/card.dart' as game_card;
import 'table_style.dart';

typedef TableCardBuilder = Widget Function(game_card.Card, double, double);

/// No card data is passed to the back builder: hidden piles cannot leak faces.
class FaceDownStack extends StatefulWidget {
  final int count;
  final Widget Function(double, double) backBuilder;
  final double width;
  final double height;
  final bool animateGrowth;
  const FaceDownStack({
    super.key,
    required this.count,
    required this.backBuilder,
    this.width = 44,
    this.height = 62,
    this.animateGrowth = false,
  });

  @override
  State<FaceDownStack> createState() => _FaceDownStackState();

  Widget _buildStack(BuildContext context) => SizedBox(
    width: width + 10,
    height: height + 10,
    child: ExcludeSemantics(
      child: IgnorePointer(
        child: Stack(
          children: [
            if (count == 0)
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: TableStyle.muted.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            // At most six layers, irrespective of the number of collected cards.
            for (var layer = math.min(count, 6) - 1; layer >= 0; layer--)
              Positioned(
                left: layer * 1.8,
                top: layer * 1.8,
                child: backBuilder(width, height),
              ),
          ],
        ),
      ),
    ),
  );
}

class _FaceDownStackState extends State<FaceDownStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    value: 1,
  );
  @override
  void didUpdateWidget(FaceDownStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateGrowth &&
        widget.count > oldWidget.count &&
        !MediaQuery.disableAnimationsOf(context)) {
      _settle.forward(from: 0);
    } else if (widget.count != oldWidget.count) {
      _settle.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _settle.value = 1;
    }
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _settle,
    child: widget._buildStack(context),
    builder: (_, child) => Transform(
      alignment: Alignment.bottomCenter,
      transform: Matrix4.diagonal3Values(
        1 + .03 * math.sin(math.pi * _settle.value),
        1 - .07 * math.sin(math.pi * _settle.value),
        1,
      ),
      child: child,
    ),
  );
}

class TeamCaptureStack extends StatelessWidget {
  final List<Capture> captures;
  final String label;
  final String countLabel;
  final String latestLabel;
  final String historyLabel;
  final bool showLatest;
  final Color accent;
  final TableCardBuilder faceBuilder;
  final Widget Function(double, double) backBuilder;
  final VoidCallback? onHistory;
  final GlobalKey? pileKey;
  const TeamCaptureStack({
    super.key,
    required this.captures,
    required this.label,
    required this.countLabel,
    required this.latestLabel,
    required this.historyLabel,
    required this.faceBuilder,
    required this.backBuilder,
    this.onHistory,
    this.pileKey,
    this.showLatest = true,
    this.accent = TableStyle.mint,
  });

  @override
  Widget build(BuildContext context) {
    // A capture is stored only when a player wins a pile. This is already a
    // current-round collection, so no rival or collected-card detail is shown.
    final played = captures;
    final latest = played.isEmpty ? null : played.last.leadingCard;
    final count = captures.fold<int>(
      0,
      (total, capture) => total + capture.capturedCards.length,
    );
    return Semantics(
      button: onHistory != null,
      label: onHistory == null
          ? '$label, $countLabel'
          : '$label, $countLabel, $historyLabel',
      child: Material(
        color: TableStyle.ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: TableStyle.brass, width: 1.5),
        ),
        child: InkWell(
          onTap: onHistory,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TableStyle.detail.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          FaceDownStack(
                            key: pileKey,
                            count: count,
                            animateGrowth: true,
                            backBuilder: backBuilder,
                          ),
                          Text(
                            countLabel,
                            textAlign: TextAlign.center,
                            style: TableStyle.label.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showLatest) ...[
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              latestLabel,
                              textAlign: TextAlign.center,
                              style: TableStyle.detail.copyWith(
                                color: TableStyle.ivory,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 48,
                                  height: 72,
                                  child: latest == null
                                      ? Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: TableStyle.muted
                                                  .withValues(alpha: .3),
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        )
                                      : ExcludeSemantics(
                                          child: faceBuilder(latest, 48, 68),
                                        ),
                                ),
                                if (onHistory != null) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 26,
                                    height: 26,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: TableStyle.brass,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 18,
                                      color: TableStyle.ivory,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A round-scoped projection: never render capturedCards or rival captures.
class CaptureCardHistory extends StatelessWidget {
  final List<Capture> captures;
  final String title;
  final String explanation;
  final String emptyLabel;
  final String latestLabel;
  final String backLabel;
  final TableCardBuilder faceBuilder;
  final String Function(game_card.Card) cardLabel;
  const CaptureCardHistory({
    super.key,
    required this.captures,
    required this.title,
    required this.explanation,
    required this.emptyLabel,
    this.latestLabel = 'Latest',
    this.backLabel = 'Back to table',
    required this.faceBuilder,
    required this.cardLabel,
  });

  @override
  Widget build(BuildContext context) {
    final played = captures;
    return ColoredBox(
      color: TableStyle.ivory,
      child: Column(
        children: [
          ListTile(
            title: Text(
              title,
              style: TableStyle.label.copyWith(
                color: TableStyle.ink,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
            trailing: IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: const Icon(Icons.close, color: TableStyle.ink),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              explanation,
              style: TableStyle.label.copyWith(color: TableStyle.ink),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: played.isEmpty
                  ? Text(
                      emptyLabel,
                      style: TableStyle.detail.copyWith(color: TableStyle.ink),
                    )
                  : Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (var index = 0; index < played.length; index++)
                          Semantics(
                            label:
                                '${index + 1}. ${cardLabel(played[index].leadingCard)}',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: index == played.length - 1
                                          ? TableStyle.brass
                                          : TableStyle.ink.withValues(
                                              alpha: .2,
                                            ),
                                      width: index == played.length - 1 ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ExcludeSemantics(
                                        child: faceBuilder(
                                          played[index].leadingCard,
                                          70,
                                          100,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${index + 1}',
                                        style: TableStyle.detail.copyWith(
                                          color: TableStyle.ink,
                                        ),
                                      ),
                                      if (index == played.length - 1)
                                        Text(
                                          latestLabel,
                                          style: TableStyle.detail.copyWith(
                                            color: TableStyle.ink,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (index < played.length - 1)
                                  const ExcludeSemantics(
                                    child: Padding(
                                      padding: EdgeInsetsDirectional.only(
                                        start: 10,
                                      ),
                                      child: Icon(
                                        Icons.arrow_forward_rounded,
                                        color: TableStyle.ink,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: TableStyle.ink,
                    foregroundColor: TableStyle.ivory,
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(backLabel),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
