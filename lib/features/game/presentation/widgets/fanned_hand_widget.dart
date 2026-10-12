import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as game_card;
import 'package:halabessa/features/game/presentation/widgets/card_widget.dart';
import 'table_style.dart';
import 'board_card_motion.dart';
import 'deal_card_motion.dart';
import 'local_card_play_layer.dart';
export 'local_card_play_layer.dart' show CardPlayOrigin;

/// Bounded, keyboard-accessible hand. Queued cards use identity, not list index.
class FannedHandWidget extends StatefulWidget {
  final List<game_card.Card> cards;
  final FutureOr<void> Function(game_card.Card, CardPlayOrigin origin)
  onCardTap;
  final game_card.Card? hiddenCard;
  final bool isMyTurn;
  final bool interactionEnabled;
  final Widget Function(game_card.Card, double, double)? cardBuilder;
  final String Function(game_card.Card)? cardLabelBuilder;
  final String playHint;
  final String queueHint;
  final String pendingHint;
  final GlobalKey? dealerDeckKey;

  const FannedHandWidget({
    super.key,
    required this.cards,
    required this.onCardTap,
    this.isMyTurn = false,
    this.interactionEnabled = true,
    this.cardBuilder,
    this.cardLabelBuilder,
    this.playHint = 'Play card',
    this.queueHint = 'Queue card; tap again to cancel',
    this.pendingHint = 'Sending move',
    this.dealerDeckKey,
    this.hiddenCard,
  });

  @override
  State<FannedHandWidget> createState() => _FannedHandWidgetState();
}

class _FannedHandWidgetState extends State<FannedHandWidget> {
  game_card.Card? _queued;
  game_card.Card? _hovered;
  CardPlayOrigin _queuedOrigin = const CardPlayOrigin(Rect.zero, 0);
  game_card.Card? _focused;
  final _geometry = <game_card.Card, CardPlayOrigin Function()>{};
  Timer? _autoPlay;
  Timer? _tapGuard;
  bool _submitting = false;
  game_card.Card? _pendingCard;
  double _dragDistance = 0;

  @override
  void dispose() {
    _autoPlay?.cancel();
    _tapGuard?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(FannedHandWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.cards.contains(_queued)) {
      _queued = null;
      _autoPlay?.cancel();
    }
    if (!widget.isMyTurn || !widget.interactionEnabled) _autoPlay?.cancel();
    if ((!oldWidget.isMyTurn || !oldWidget.interactionEnabled) &&
        widget.isMyTurn &&
        widget.interactionEnabled &&
        _queued != null) {
      final selected = _queued!;
      _autoPlay?.cancel();
      _autoPlay = Timer(const Duration(milliseconds: 300), () {
        if (mounted && _queued == selected && widget.cards.contains(selected)) {
          _activate(selected, _queuedOrigin);
        }
      });
    }
  }

  Future<void> _activate(game_card.Card card, CardPlayOrigin origin) async {
    if (!widget.interactionEnabled ||
        _submitting ||
        !widget.cards.contains(card)) {
      return;
    }
    _autoPlay?.cancel();
    origin = _geometry[card]?.call() ?? origin;
    if (!widget.isMyTurn) {
      setState(() {
        _queued = _queued == card ? null : card;
        _queuedOrigin = origin;
      });
      return;
    }
    setState(() {
      _queued = null;
      _submitting = true;
      _pendingCard = card;
    });
    // Keep the guard for the real request, not just a guessed network delay.
    // The short minimum also protects synchronous/offline callbacks.
    _tapGuard?.cancel();
    _tapGuard = Timer(const Duration(milliseconds: 600), () {
      if (mounted && _pendingCard == null) {
        setState(() => _submitting = false);
      }
    });
    try {
      await widget.onCardTap(card, origin);
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack),
      );
    } finally {
      if (mounted) {
        setState(() {
          _pendingCard = null;
          if (_tapGuard?.isActive != true) _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final compact =
            constraints.hasBoundedHeight && constraints.maxHeight < 145;
        // Reserve a four-card fan even after a play. Otherwise the Stack itself
        // recenters immediately and every remaining card appears to jump.
        final width = math.min(
          compact ? 60.0 : 94.0,
          math.max(40.0, (available - 24) / 3.5),
        );
        final height = width * 1.43;
        final spacing = math.min(
          width + 8,
          math.max(0.0, (available - 16 - width) / 3),
        );
        final fanWidth = width + spacing * 3;
        final totalWidth = width + spacing * (widget.cards.length - 1);
        final firstCardLeft = (fanWidth - totalWidth) / 2;
        final reducedMotion = MediaQuery.disableAnimationsOf(context);
        return Center(
          heightFactor: 1,
          child: SizedBox(
            width: fanWidth,
            height: height + 28,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var index = 0; index < widget.cards.length; index++)
                  AnimatedPositioned(
                    key: ValueKey(
                      'hand-slot-${widget.cards[index].firebaseKey}',
                    ),
                    duration: reducedMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    left: firstCardLeft + index * spacing,
                    bottom: 8,
                    child: Builder(
                      builder: (cardContext) {
                        final card = widget.cards[index];
                        final pending = _pendingCard == card;
                        final selected = _queued == card || pending;
                        final angle =
                            (index - (widget.cards.length - 1) / 2) * .035;
                        void activate() {
                          _activate(card, _geometry[card]!());
                        }

                        _geometry[card] = () {
                          final box =
                              cardContext.findRenderObject() as RenderBox?;
                          return CardPlayOrigin(
                            Rect.fromPoints(
                              box?.localToGlobal(Offset.zero) ?? Offset.zero,
                              box?.localToGlobal(Offset(width, height)) ??
                                  Offset.zero,
                            ),
                            angle,
                          );
                        };

                        // Artwork, selection and keyboard focus share one
                        // transform; the tap target remains fixed during deals.
                        final artwork = Transform.rotate(
                          key: ValueKey('hand-art-angle-${card.firebaseKey}'),
                          angle: angle,
                          child: ExcludeSemantics(
                            child: IgnorePointer(
                              child: SizedBox(
                                width: width,
                                height: height,
                                child: Stack(
                                  children: [
                                    widget.cardBuilder?.call(
                                          card,
                                          width,
                                          height,
                                        ) ??
                                        CardWidget(
                                          card: card,
                                          width: width,
                                          height: height,
                                        ),
                                    if (selected || _focused == card)
                                      Positioned.fill(
                                        child: DecoratedBox(
                                          key: ValueKey(
                                            'hand-outline-${card.firebaseKey}',
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.all(
                                              Radius.elliptical(
                                                width * .1,
                                                height * .07,
                                              ),
                                            ),
                                            border: Border.all(
                                              color: TableStyle.brass,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );

                        return AnimatedPadding(
                          duration: reducedMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 120),
                          padding: EdgeInsets.only(
                            bottom: selected ? 12 : (_hovered == card ? 6 : 0),
                          ),
                          child: Semantics(
                            label:
                                widget.cardLabelBuilder?.call(card) ??
                                card.toString(),
                            hint: widget.isMyTurn
                                ? widget.playHint
                                : widget.queueHint,
                            selected: selected,
                            value: pending ? widget.pendingHint : null,
                            child: GestureDetector(
                              key: ValueKey('hand-card-${card.firebaseKey}'),
                              onVerticalDragStart: widget.interactionEnabled
                                  ? (details) {
                                      _dragDistance = 0;
                                    }
                                  : null,
                              onVerticalDragUpdate: widget.interactionEnabled
                                  ? (details) {
                                      _dragDistance += details.delta.dy;
                                    }
                                  : null,
                              onVerticalDragEnd: widget.interactionEnabled
                                  ? (_) {
                                      if (_dragDistance < -36) {
                                        activate();
                                      }
                                      _dragDistance = 0;
                                    }
                                  : null,
                              onVerticalDragCancel: () => _dragDistance = 0,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  focusColor: Colors.transparent,
                                  splashColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onFocusChange: (value) => setState(
                                    () => _focused = value ? card : null,
                                  ),
                                  onHover: (value) => setState(
                                    () => _hovered = value ? card : null,
                                  ),
                                  onTap:
                                      widget.interactionEnabled && !_submitting
                                      ? activate
                                      : null,
                                  child: Opacity(
                                    opacity: widget.hiddenCard == card ? 0 : 1,
                                    child: widget.dealerDeckKey != null
                                        ? DealCardMotion(
                                            key: ValueKey(
                                              'hand-deal-${card.firebaseKey}',
                                            ),
                                            sourceKey: widget.dealerDeckKey!,
                                            delay: Duration(
                                              milliseconds: index * 70,
                                            ),
                                            child: artwork,
                                          )
                                        : BoardCardMotion(
                                            key: ValueKey(
                                              'hand-visual-${card.firebaseKey}',
                                            ),
                                            // New cards leave one point above the hand and
                                            // fan out; the card's hit target never moves.
                                            origin: Offset(
                                              fanWidth / 2 -
                                                  (firstCardLeft +
                                                      index * spacing +
                                                      width / 2),
                                              compact ? -72 : -108,
                                            ),
                                            delay: Duration(
                                              milliseconds: index * 70,
                                            ),
                                            travelDuration: const Duration(
                                              milliseconds: 380,
                                            ),
                                            initialOpacity: 0.65,
                                            // Keep the hit target fixed while only the
                                            // dealt card artwork travels into the hand.
                                            child: artwork,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
