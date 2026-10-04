import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'table_style.dart';
import 'deal_card_motion.dart';

/// Public seat information only. Hidden hands receive counts and backs, not faces.
class TableSeat extends StatefulWidget {
  final String name;
  final String detail;
  final String? avatarUrl;
  final String? portraitAsset;
  final String? dealerLabel;
  final String? message;
  final bool isBot;
  final bool active;
  final Color accent;
  final DateTime? turnStarted;
  final int turnSeconds;
  final VoidCallback? onPressed;
  final int? hiddenHandCount;
  final String? dealIdentity;
  final GlobalKey? dealerDeckKey;
  final Widget Function(double, double)? backBuilder;
  const TableSeat({
    super.key,
    required this.name,
    required this.detail,
    this.avatarUrl,
    this.portraitAsset,
    this.dealerLabel,
    this.message,
    this.isBot = false,
    this.active = false,
    this.accent = TableStyle.mint,
    this.turnStarted,
    this.turnSeconds = 0,
    this.onPressed,
    this.hiddenHandCount,
    this.dealIdentity,
    this.dealerDeckKey,
    this.backBuilder,
  });
  @override
  State<TableSeat> createState() => _TableSeatState();
}

class _TableSeatState extends State<TableSeat> {
  Timer? _clock;
  @override
  void initState() {
    super.initState();
    _updateClock();
  }

  @override
  void didUpdateWidget(TableSeat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active ||
        oldWidget.turnStarted != widget.turnStarted ||
        oldWidget.turnSeconds != widget.turnSeconds) {
      _updateClock();
    }
  }

  void _updateClock() {
    _clock?.cancel();
    if (widget.active && widget.turnStarted != null && widget.turnSeconds > 0) {
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.avatarUrl;
    final fallback =
        widget.portraitAsset ?? 'assets/images/avatars/lantern_partner_v1.png';
    final line = 16.0 * MediaQuery.textScalerOf(context).scale(12) / 12;
    final remaining = widget.turnStarted == null || widget.turnSeconds <= 0
        ? 0.0
        : (1 -
                  DateTime.now()
                          .difference(widget.turnStarted!)
                          .inMilliseconds /
                      (widget.turnSeconds * 1000))
              .clamp(0.0, 1.0);
    return SizedBox(
      width: 110,
      height: 110 + 4 * line,
      child: Tooltip(
        message: [
          widget.name,
          widget.detail,
          if (widget.dealerLabel != null) widget.dealerLabel!,
          if (widget.message != null) widget.message!,
        ].join('\n'),
        decoration: BoxDecoration(
          color: TableStyle.ink,
          border: Border.all(color: TableStyle.brass.withValues(alpha: .5)),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TableStyle.detail.copyWith(color: TableStyle.ivory),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(12),
            focusColor: TableStyle.brass.withValues(alpha: .4),
            child: DecoratedBox(
              key: const ValueKey('seat-active-surface'),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.transparent),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: CircularProgressIndicator(
                            value: widget.active
                                ? (widget.turnSeconds > 0 ? remaining : 1)
                                : 0,
                            backgroundColor: widget.accent,
                            color: TableStyle.brass,
                            strokeWidth: 3,
                          ),
                        ),
                        ClipOval(
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: url == null || url.isEmpty || widget.isBot
                                ? Image.asset(
                                    fallback,
                                    fit: BoxFit.cover,
                                    cacheWidth: 160,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.person_outline,
                                      color: TableStyle.ivory,
                                    ),
                                  )
                                : url.startsWith('assets/')
                                ? Image.asset(
                                    url,
                                    fit: BoxFit.cover,
                                    cacheWidth: 160,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.person_outline,
                                      color: TableStyle.ivory,
                                    ),
                                  )
                                : Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    cacheWidth: 160,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.person_outline,
                                      color: TableStyle.ivory,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Container(
                      height: line + 2,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: TableStyle.ink,
                        border: Border.all(color: widget.accent),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TableStyle.detail.copyWith(
                          color: TableStyle.ivory,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: line,
                      child: widget.dealerLabel == null
                          ? const SizedBox.shrink()
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: TableStyle.brass,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                widget.dealerLabel!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TableStyle.detail.copyWith(
                                  color: TableStyle.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                    ),
                    SizedBox(
                      height: 26 + line,
                      child: widget.hiddenHandCount == null
                          ? Text(
                              widget.detail,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TableStyle.detail,
                            )
                          : Semantics(
                              label: widget.detail,
                              excludeSemantics: true,
                              child: LayoutBuilder(
                                builder: (context, bounds) {
                                  final n = widget.hiddenHandCount!.clamp(0, 4);
                                  final fanWidth = math.max(
                                    0.0,
                                    bounds.maxWidth - 26,
                                  );
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: fanWidth,
                                        height: 32,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            for (
                                              var index = 0;
                                              index < n;
                                              index++
                                            )
                                              if (widget.backBuilder != null)
                                                Positioned(
                                                  left:
                                                      (fanWidth - 16) /
                                                      3 *
                                                      (index + (4 - n) / 2),
                                                  top: 4,
                                                  child: IgnorePointer(
                                                    child: Transform.rotate(
                                                      angle:
                                                          (index -
                                                              (n - 1) / 2) *
                                                          .10,
                                                      child:
                                                          widget.dealerDeckKey ==
                                                              null
                                                          ? widget.backBuilder!(
                                                              16,
                                                              24,
                                                            )
                                                          : DealCardMotion(
                                                              key: ValueKey(
                                                                '${widget.dealIdentity}-$index',
                                                              ),
                                                              sourceKey: widget
                                                                  .dealerDeckKey!,
                                                              delay: Duration(
                                                                milliseconds:
                                                                    index * 70,
                                                              ),
                                                              child:
                                                                  widget
                                                                      .backBuilder!(
                                                                    16,
                                                                    24,
                                                                  ),
                                                            ),
                                                    ),
                                                  ),
                                                ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        width: 24,
                                        height: 24,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: TableStyle.ink,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: TableStyle.brass,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Text(
                                          '${widget.hiddenHandCount}',
                                          textScaler: TextScaler.noScaling,
                                          style: TableStyle.label.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                    ),
                    SizedBox(
                      height: line,
                      child: widget.message == null
                          ? const SizedBox.shrink()
                          : Text(
                              widget.message!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TableStyle.detail,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
