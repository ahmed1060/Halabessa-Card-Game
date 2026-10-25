import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'table_style.dart';
import 'table_chat_bubble.dart';
import 'deal_card_motion.dart';
import 'turn_deadline_ring.dart';
import '../../domain/logic/online_match_clock.dart';

/// Public seat information only. Hidden hands receive counts and backs, not faces.
class TableSeat extends StatefulWidget {
  final String name;
  final String detail;
  final bool showTooltip;
  final int revealedHandCount;
  final String? avatarUrl;
  final String? portraitAsset;
  final String? dealerLabel;
  final String? message;
  final String? messageIdentity;
  final DateTime? messageExpiresAt;
  final bool isBot;
  final bool active;
  final Color accent;
  final DateTime? turnStarted;
  final int turnSeconds;
  final Duration? turnDuration;
  final bool serverClock;
  final VoidCallback? onPressed;
  final int? hiddenHandCount;
  final String? dealIdentity;
  final GlobalKey? dealerDeckKey;
  final Widget Function(double, double)? backBuilder;
  final bool optionB;
  final bool chatBadge;
  final bool compactAvatar;
  final bool handOnRight;
  final String Function(int)? countdownSemantics;
  const TableSeat({
    super.key,
    required this.name,
    required this.detail,
    this.showTooltip = true,
    this.revealedHandCount = 0,
    this.avatarUrl,
    this.portraitAsset,
    this.dealerLabel,
    this.message,
    this.messageIdentity,
    this.messageExpiresAt,
    this.isBot = false,
    this.active = false,
    this.accent = TableStyle.mint,
    this.turnStarted,
    this.turnSeconds = 0,
    this.turnDuration,
    this.serverClock = false,
    this.onPressed,
    this.hiddenHandCount,
    this.dealIdentity,
    this.dealerDeckKey,
    this.backBuilder,
    this.optionB = false,
    this.chatBadge = false,
    this.compactAvatar = false,
    this.handOnRight = false,
    this.countdownSemantics,
  });
  @override
  State<TableSeat> createState() => _TableSeatState();
}

class _TableSeatState extends State<TableSeat> {
  Timer? _messageExpiry;
  bool _messageExpired = false;
  bool _avatarHovered = false;
  bool _focused = false;
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
        oldWidget.turnSeconds != widget.turnSeconds ||
        oldWidget.messageExpiresAt != widget.messageExpiresAt ||
        oldWidget.message != widget.message) {
      _updateClock();
    }
  }

  void _updateClock() {
    _messageExpiry?.cancel();
    final expiry = widget.messageExpiresAt;
    _messageExpired = expiry != null && !DateTime.now().isBefore(expiry);
    if (expiry != null && !_messageExpired) {
      _messageExpiry = Timer(expiry.difference(DateTime.now()), () {
        if (mounted) setState(() => _messageExpired = true);
      });
    }
  }

  @override
  void dispose() {
    _messageExpiry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = _messageExpired ? null : widget.message;
    final url = widget.avatarUrl;
    final fallback =
        widget.portraitAsset ?? 'assets/images/avatars/lantern_partner_v1.png';
    final line = widget.optionB
        ? 16.0
        : 16.0 * MediaQuery.textScalerOf(context).scale(12) / 12;
    final viewport = MediaQuery.sizeOf(context);
    final smallAvatar = widget.optionB && widget.compactAvatar;
    final compact =
        !widget.optionB &&
        viewport.width > viewport.height &&
        viewport.height < 500 &&
        line <= 18;
    return SizedBox(
      width: widget.optionB ? 126 : 110,
      height: widget.optionB
          ? 184
          : compact
          ? 146
          : 110 + 4 * line,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Semantics(
            container: true,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onPressed,
                borderRadius: BorderRadius.circular(12),
                // Keep the full accessible click target, but never tint the large
                // reserved seat rectangle. Feedback is painted on the avatar only.
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
                highlightColor: Colors.transparent,
                splashColor: Colors.transparent,
                onFocusChange: (focused) => setState(() => _focused = focused),
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
                        MouseRegion(
                          key: const ValueKey('avatar-hover-target'),
                          onEnter: (_) => setState(() => _avatarHovered = true),
                          onExit: (_) => setState(() => _avatarHovered = false),
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              SizedBox(
                                width: widget.optionB
                                    ? (smallAvatar ? 64 : 80)
                                    : 72,
                                height: widget.optionB
                                    ? (smallAvatar ? 64 : 80)
                                    : 72,
                                child: DecoratedBox(
                                  key: const ValueKey('avatar-feedback-circle'),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: widget.active
                                        ? [
                                            BoxShadow(
                                              color: TableStyle.brass
                                                  .withValues(alpha: .65),
                                              blurRadius: 16,
                                              spreadRadius: 2,
                                            ),
                                          ]
                                        : _avatarHovered || _focused
                                        ? [
                                            BoxShadow(
                                              color: widget.accent.withValues(
                                                alpha: .4,
                                              ),
                                              blurRadius: 10,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: TurnDeadlineRing(
                                    liquid: widget.optionB,
                                    remainingLabel: widget.countdownSemantics,
                                    active: widget.active,
                                    started: widget.turnStarted,
                                    duration:
                                        widget.turnDuration ??
                                        Duration(seconds: widget.turnSeconds),
                                    now: widget.serverClock
                                        ? OnlineMatchClock.instance.now
                                        : null,
                                    clockChanges: widget.serverClock
                                        ? OnlineMatchClock.instance
                                        : null,
                                    background: widget.accent,
                                    foreground: TableStyle.brass,
                                  ),
                                ),
                              ),
                              ClipOval(
                                child: _hint(
                                  SizedBox(
                                    width: widget.optionB
                                        ? (smallAvatar ? 56 : 70)
                                        : 64,
                                    height: widget.optionB
                                        ? (smallAvatar ? 56 : 70)
                                        : 64,
                                    child:
                                        url == null ||
                                            url.isEmpty ||
                                            widget.isBot
                                        ? Image.asset(
                                            fallback,
                                            fit: BoxFit.cover,
                                            cacheWidth: 160,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                                  Icons.person_outline,
                                                  color: TableStyle.ivory,
                                                ),
                                          )
                                        : url.startsWith('assets/')
                                        ? Image.asset(
                                            url,
                                            fit: BoxFit.cover,
                                            cacheWidth: 160,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                                  Icons.person_outline,
                                                  color: TableStyle.ivory,
                                                ),
                                          )
                                        : Image.network(
                                            url,
                                            fit: BoxFit.cover,
                                            cacheWidth: 160,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                                  Icons.person_outline,
                                                  color: TableStyle.ivory,
                                                ),
                                          ),
                                  ),
                                ),
                              ),
                              if (widget.chatBadge)
                                Positioned(
                                  top: -2,
                                  right: -4,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: const BoxDecoration(
                                      color: TableStyle.mint,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.chat_bubble_rounded,
                                      size: 14,
                                      color: TableStyle.ivory,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        _hint(
                          Container(
                            height: line + 2,
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(
                              color: TableStyle.ink,
                              border: Border.all(
                                color: compact && widget.dealerLabel != null
                                    ? TableStyle.brass
                                    : widget.accent,
                              ),
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
                        ),
                        SizedBox(
                          height:
                              compact ||
                                  (widget.optionB && widget.dealerLabel == null)
                              ? 0
                              : line,
                          child: compact || widget.dealerLabel == null
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
                          height: widget.optionB
                              ? (widget.hiddenHandCount == null ? 0 : 74)
                              : compact
                              ? 28
                              : 26 + line,
                          child: widget.hiddenHandCount == null
                              ? widget.optionB
                                    ? const SizedBox.shrink()
                                    : Text(
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
                                      if (widget.optionB) {
                                        final hand = _horizontalHand();
                                        // Keep the avatar/name and its hit target fixed.
                                        // Only the public backs/count move to its right.
                                        return widget.handOnRight
                                            ? Transform.translate(
                                                key: const ValueKey(
                                                  'seat-side-hand',
                                                ),
                                                offset: Offset(
                                                  92,
                                                  widget.dealerLabel == null
                                                      ? -64
                                                      : -80,
                                                ),
                                                child: hand,
                                              )
                                            : hand;
                                      }
                                      final n = widget.hiddenHandCount!.clamp(
                                        0,
                                        4,
                                      );
                                      final fanWidth = math.max(
                                        0.0,
                                        bounds.maxWidth - 26,
                                      );
                                      final handWidgets = <Widget>[
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
                                                        (fanWidth -
                                                            (widget.optionB
                                                                ? 20
                                                                : 16)) /
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
                                                            ? widget
                                                                  .backBuilder!(
                                                                widget.optionB
                                                                    ? 20
                                                                    : 16,
                                                                widget.optionB
                                                                    ? 28
                                                                    : 24,
                                                              )
                                                            : DealCardMotion(
                                                                key: ValueKey(
                                                                  '${widget.dealIdentity}-$index',
                                                                ),
                                                                sourceKey: widget
                                                                    .dealerDeckKey!,
                                                                delay: Duration(
                                                                  milliseconds:
                                                                      index *
                                                                      70,
                                                                ),
                                                                child: widget.backBuilder!(
                                                                  widget.optionB
                                                                      ? 20
                                                                      : 16,
                                                                  widget.optionB
                                                                      ? 28
                                                                      : 24,
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
                                      ];
                                      return Row(
                                        textDirection: TextDirection.ltr,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: widget.optionB
                                            ? handWidgets.reversed.toList()
                                            : handWidgets,
                                      );
                                    },
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            start: -16,
            end: -16,
            top:
                (smallAvatar ? 72.0 : 100.0) +
                line +
                2 +
                (widget.dealerLabel == null ? 0 : line),
            // The local seat sits directly above the left opponent in landscape.
            // Move only its bubble into the adjacent free space, in physical
            // coordinates so translated/RTL layouts keep the same table seats.
            child: Transform.translate(
              offset: Offset(
                widget.optionB &&
                        widget.chatBadge &&
                        viewport.width > viewport.height
                    ? 80
                    : 0,
                0,
              ),
              child: TableChatBubble(
                message: message,
                identity: widget.messageIdentity,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _horizontalHand() {
    final count = widget.hiddenHandCount!;
    final n = (count - widget.revealedHandCount).clamp(0, 4);
    return SizedBox(
      key: const ValueKey('seat-horizontal-fan'),
      width: 118,
      height: 74,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < n; i++)
            Positioned(
              left:
                  7 +
                  (i +
                          (4 -
                                  (widget.revealedHandCount > 0
                                      ? count.clamp(0, 4)
                                      : n)) /
                              2) *
                      24,
              top: (i - (n - 1) / 2).abs() * 2,
              child: Transform.rotate(
                angle: (i - (n - 1) / 2) * .12,
                child: IgnorePointer(
                  child: widget.dealerDeckKey == null
                      ? widget.backBuilder?.call(32, 46) ?? const SizedBox()
                      : DealCardMotion(
                          key: ValueKey('${widget.dealIdentity}-$i'),
                          sourceKey: widget.dealerDeckKey!,
                          delay: Duration(milliseconds: i * 70),
                          child:
                              widget.backBuilder?.call(32, 46) ??
                              const SizedBox(),
                        ),
                ),
              ),
            ),
          Positioned(
            top: 47,
            left: 47,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: TableStyle.ink,
                shape: BoxShape.circle,
                border: Border.all(color: TableStyle.brass, width: 1.5),
              ),
              child: Text(
                '$count',
                textScaler: TextScaler.noScaling,
                style: TableStyle.label.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hint(Widget child) => !widget.showTooltip || widget.detail.isEmpty
      ? child
      : Tooltip(
          message: widget.detail,
          decoration: BoxDecoration(
            color: TableStyle.ink,
            border: Border.all(color: TableStyle.brass.withValues(alpha: .5)),
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: TableStyle.detail.copyWith(color: TableStyle.ivory),
          child: child,
        );
}
