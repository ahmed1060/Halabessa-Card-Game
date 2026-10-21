import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerPhase;
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:halabessa/features/game/domain/models/card.dart' as game_card;
import 'package:halabessa/features/game/presentation/widgets/card_widget.dart';
import 'table_style.dart';
import 'board_card_motion.dart';
import 'deal_card_motion.dart';
import 'local_card_play_layer.dart';
import 'card_juice_controller.dart';
import 'option_b_table.dart' show OptionBGeometry;
import '../providers/visual_action_queue.dart';
export 'local_card_play_layer.dart' show CardPlayOrigin;

/// Shared by the Flutter hit targets and Unity's normalized visual anchors.
class HandFanGeometry {
  final double width, height, spacing;
  const HandFanGeometry._(this.width, this.height, this.spacing);
  factory HandFanGeometry(
    double available, {
    bool compact = false,
    double spread = 1,
  }) {
    // Widen the fan without scaling the card artwork itself.
    final sizingWidth = available / spread;
    final width = math.min(
      compact ? 60.0 : 118.0,
      math.max(40.0, (sizingWidth - 24) / 3.2),
    );
    return HandFanGeometry._(
      width,
      width * 1.43,
      math.max(0.0, (available - 16 - width) / 3),
    );
  }
}

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
  final VoidCallback? onPick;
  final VoidCallback? onHoldPulse;
  final bool renderArtwork;
  final bool largeCards;

  /// Optional new intents; no callback means the feature is not enabled.
  final FutureOr<void> Function(game_card.Card, CardPlayOrigin)? onCardSlam;
  final FutureOr<void> Function(game_card.Card, CardPlayOrigin)? onCardReveal;
  final int slamUsesRemaining;
  final int revealUsesRemaining;
  final VoidCallback? onUnavailable;
  final void Function(game_card.Card, bool queued, bool slam)? onSelectionPose;
  final void Function(
    game_card.Card,
    bool peek,
    double dragFraction,
    double velocity,
  )?
  onVisualPose;

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
    this.onPick,
    this.onHoldPulse,
    this.renderArtwork = true,
    this.largeCards = false,
    this.onVisualPose,
    this.onCardSlam,
    this.onCardReveal,
    this.slamUsesRemaining = 0,
    this.revealUsesRemaining = 0,
    this.onUnavailable,
    this.onSelectionPose,
  });

  @override
  State<FannedHandWidget> createState() => _FannedHandWidgetState();
}

class _FannedHandWidgetState extends State<FannedHandWidget>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  game_card.Card? _queued;
  bool _queuedSlam = false;
  bool _slamArmed = false;
  bool _holdCancelled = false;
  bool _holdBackgroundCancelled = false;
  game_card.Card? _hovered;
  CardPlayOrigin _queuedOrigin = const CardPlayOrigin(Rect.zero, 0);
  game_card.Card? _focused;
  final _geometry = <game_card.Card, CardPlayOrigin Function()>{};
  Timer? _autoPlay;
  Timer? _tapGuard;
  bool _submitting = false;
  bool _revealing = false;
  game_card.Card? _pendingCard;
  double _dragDistance = 0;
  double _dragVelocity = 0;
  game_card.Card? _pressed;
  Duration? _dragTime;
  Timer? _holdDelay, _holdPulses;
  game_card.Card? _holdCard;
  late final AnimationController _holdMotion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _holdMotion =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 160),
        )..addListener(() {
          if (mounted && _holdCard != null) setState(() {});
        });
  }

  void _stopHoldFeedback({bool rebuild = true}) {
    final changed = _holdCard != null;
    _holdDelay?.cancel();
    _holdPulses?.cancel();
    _holdDelay = _holdPulses = null;
    _holdCard = null;
    _holdMotion.stop();
    _holdMotion.value = 0;
    if (changed && rebuild && mounted) setState(() {});
  }

  void _startHoldFeedback(game_card.Card card) {
    _stopHoldFeedback(rebuild: false);
    if (!widget.interactionEnabled ||
        widget.onCardSlam == null ||
        widget.slamUsesRemaining <= 0 ||
        _submitting ||
        !cardJuiceEnabled)
      return;
    _holdCard = card;
    // Tap-down already owns one grab pulse. Build-up starts only on a held
    // press; the existing long-press recognizer still owns the marking time.
    _holdDelay = Timer(const Duration(milliseconds: 180), () {
      if (!mounted || _pressed != card || _slamArmed) {
        _stopHoldFeedback();
        return;
      }
      widget.onHoldPulse?.call();
      _holdPulses = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted || _pressed != card || _slamArmed) {
          _stopHoldFeedback();
          return;
        }
        widget.onHoldPulse?.call();
      });
      if (!MediaQuery.disableAnimationsOf(context)) _holdMotion.repeat();
    });
  }

  void _cancelPress() {
    _stopHoldFeedback(rebuild: false);
    _slamArmed = false;
    _holdCancelled = true;
    _pressed = null;
    _dragDistance = 0;
    _dragVelocity = 0;
    if (!mounted) return;
    // A recognizer can cancel while a card is removed or its callbacks are
    // disabled during layout. Clear intent now; repaint after the locked tree.
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _holdMotion.stop();
      _holdMotion.value = 0;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _holdBackgroundCancelled = true;
      _cancelPress();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopHoldFeedback(rebuild: false);
    _holdMotion.dispose();
    _autoPlay?.cancel();
    _tapGuard?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(FannedHandWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.interactionEnabled ||
        !widget.cards.contains(_holdCard) ||
        widget.onCardSlam == null ||
        widget.slamUsesRemaining <= 0) {
      _stopHoldFeedback(rebuild: false);
    }
    _geometry.removeWhere((card, _) => !widget.cards.contains(card));
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
          _activate(
            selected,
            _queuedOrigin,
            slam: _queuedSlam,
            fromQueue: true,
          );
        }
      });
    }
  }

  Future<void> _activate(
    game_card.Card card,
    CardPlayOrigin origin, {
    bool slam = false,
    bool fromQueue = false,
  }) async {
    if (!widget.interactionEnabled ||
        _submitting ||
        !widget.cards.contains(card)) {
      return;
    }
    _autoPlay?.cancel();
    // A short tap on the queued card cancels even during the 300ms turn-entry
    // window. The automatic execution path must not cancel its own selection.
    if (!fromQueue && !slam && _queued == card) {
      setState(() {
        _queued = null;
        _queuedSlam = false;
      });
      return;
    }
    if (slam && (widget.onCardSlam == null || widget.slamUsesRemaining <= 0)) {
      setState(() {
        _queued = null;
        _queuedSlam = false;
      });
      widget.onUnavailable?.call();
      return; // Exhausted slam must never fall through to normal play.
    }
    origin = _geometry[card]?.call() ?? origin;
    if (!widget.isMyTurn) {
      setState(() {
        _queued = card;
        _queuedSlam = slam;
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
      await (slam
          ? widget.onCardSlam!(card, origin)
          : widget.onCardTap(card, origin));
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

  Future<void> _reveal(game_card.Card card) async {
    if (!widget.interactionEnabled ||
        _revealing ||
        _submitting ||
        !widget.cards.contains(card))
      return;
    if (widget.onCardReveal == null || widget.revealUsesRemaining <= 0) {
      widget.onUnavailable?.call();
      return;
    }
    // Showing is independent from private selection and never calls onCardTap.
    setState(() => _revealing = true);
    try {
      await widget.onCardReveal!(card, _geometry[card]!());
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack),
      );
    } finally {
      if (mounted) setState(() => _revealing = false);
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
            !widget.largeCards &&
            constraints.hasBoundedHeight &&
            constraints.maxHeight < 145;
        // Reserve a four-card fan even after a play. Otherwise the Stack itself
        // recenters immediately and every remaining card appears to jump.
        final geometry = HandFanGeometry(
          available,
          compact: compact,
          spread: widget.largeCards ? OptionBGeometry.localHandSpread : 1,
        );
        final width = geometry.width;
        final height = geometry.height;
        final spacing = geometry.spacing;
        final fanWidth = width + spacing * 3;
        final totalWidth = width + spacing * (widget.cards.length - 1);
        final firstCardLeft = (fanWidth - totalWidth) / 2;
        final reducedMotion = MediaQuery.disableAnimationsOf(context);
        final raised = _pressed ?? _hovered ?? _focused ?? _queued;
        final order = [
          for (var i = 0; i < widget.cards.length; i++)
            if (widget.cards[i] != raised) i,
          for (var i = 0; i < widget.cards.length; i++)
            if (widget.cards[i] == raised) i,
        ];
        return Center(
          heightFactor: 1,
          child: OverflowBox(
            fit: OverflowBoxFit.deferToChild,
            minHeight: height + 28,
            maxHeight: height + 28,
            child: SizedBox(
              width: fanWidth,
              height: height + 28,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final index in order)
                    AnimatedPositioned(
                      key: ValueKey(
                        'hand-slot-${widget.cards[index].firebaseKey}',
                      ),
                      duration: reducedMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      left: firstCardLeft + index * spacing,
                      bottom:
                          8 +
                          (cardJuiceEnabled
                              ? handArc(index, widget.cards.length)
                              : 0),
                      child: Builder(
                        builder: (cardContext) {
                          final card = widget.cards[index];
                          final pending = _pendingCard == card;
                          final selected = _queued == card || pending;
                          final slamSelected =
                              (_queued == card && _queuedSlam) ||
                              (_pressed == card && _slamArmed);
                          final preparingReveal =
                              _pressed == card &&
                              _dragDistance > 18 &&
                              widget.onCardReveal != null;
                          final preparingSlam = _pressed == card && _slamArmed;
                          final holdVibration =
                              _holdCard == card &&
                                  _holdMotion.isAnimating &&
                                  !reducedMotion
                              ? math.sin(_holdMotion.value * math.pi * 2) * 1.2
                              : 0.0;
                          if (widget.onSelectionPose != null) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted)
                                widget.onSelectionPose?.call(
                                  card,
                                  _queued == card,
                                  slamSelected,
                                );
                            });
                          }
                          final angle =
                              (index - (widget.cards.length - 1) / 2) * .035;
                          if (widget.onVisualPose != null) {
                            final peek = card == raised && !pending;
                            final drag = _pressed == card
                                ? _dragDistance.clamp(-48, 20) / height
                                : 0.0;
                            final velocity = _pressed == card
                                ? (_holdMotion.isAnimating && _holdCard == card
                                      ? holdVibration * 180
                                      : _dragVelocity)
                                : 0.0;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                widget.onVisualPose?.call(
                                  card,
                                  peek,
                                  drag,
                                  velocity,
                                );
                              }
                            });
                          }
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
                          final artwork = Transform.translate(
                            key: ValueKey(
                              'hand-hold-tremble-${card.firebaseKey}',
                            ),
                            offset: Offset(holdVibration, 0),
                            child: CardJuiceController(
                              peek: card == raised && !pending,
                              drag: _pressed == card
                                  ? Offset(0, _dragDistance.clamp(-48, 20))
                                  : Offset.zero,
                              velocity: _pressed == card ? _dragVelocity : 0,
                              child: Transform.rotate(
                                key: ValueKey(
                                  'hand-art-angle-${card.firebaseKey}',
                                ),
                                angle: angle + holdVibration * .006,
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
                                          if (selected ||
                                              slamSelected ||
                                              _focused == card)
                                            Positioned.fill(
                                              child: DecoratedBox(
                                                key: ValueKey(
                                                  'hand-outline-${card.firebaseKey}',
                                                ),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.all(
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
                                          if (slamSelected)
                                            Positioned.fill(
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                child: DecoratedBox(
                                                  key: ValueKey(
                                                    'hand-slam-outline-${card.firebaseKey}',
                                                  ),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          width * .06,
                                                        ),
                                                    border: Border.all(
                                                      color: TableStyle.brass,
                                                      width: 1.5,
                                                    ),
                                                  ),
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
                          );

                          return AnimatedPadding(
                            duration: reducedMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 120),
                            padding: EdgeInsets.only(
                              bottom: cardJuiceEnabled
                                  ? 0
                                  : selected
                                  ? 12
                                  : (_hovered == card ? 6 : 0),
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
                                onLongPressStart:
                                    widget.interactionEnabled &&
                                        !_submitting &&
                                        widget.onCardSlam != null
                                    ? (_) {
                                        if (_holdBackgroundCancelled) return;
                                        _stopHoldFeedback(rebuild: false);
                                        setState(() {
                                          _pressed = card;
                                          _slamArmed = true;
                                          _holdCancelled = false;
                                        });
                                      }
                                    : null,
                                onLongPressMoveUpdate:
                                    widget.interactionEnabled &&
                                        widget.onCardSlam != null
                                    ? (details) {
                                        if (details.offsetFromOrigin.distance >
                                            36) {
                                          setState(() => _holdCancelled = true);
                                        }
                                      }
                                    : null,
                                onLongPressEnd:
                                    widget.interactionEnabled &&
                                        widget.onCardSlam != null
                                    ? (_) {
                                        _stopHoldFeedback(rebuild: false);
                                        final commit =
                                            _slamArmed && !_holdCancelled;
                                        setState(() {
                                          _pressed = null;
                                          _slamArmed = false;
                                        });
                                        if (commit)
                                          _activate(
                                            card,
                                            _geometry[card]!(),
                                            slam: true,
                                          );
                                      }
                                    : null,
                                onLongPressCancel:
                                    widget.interactionEnabled &&
                                        widget.onCardSlam != null
                                    ? _cancelPress
                                    : null,
                                onVerticalDragStart: widget.interactionEnabled
                                    ? (details) {
                                        _stopHoldFeedback(rebuild: false);
                                        _dragDistance = 0;
                                        _dragVelocity = 0;
                                        _dragTime = details.sourceTimeStamp;
                                        setState(() => _pressed = card);
                                      }
                                    : null,
                                onVerticalDragUpdate: widget.interactionEnabled
                                    ? (details) {
                                        final now = details.sourceTimeStamp;
                                        final elapsed =
                                            now != null && _dragTime != null
                                            ? (now - _dragTime!)
                                                      .inMicroseconds /
                                                  1000000
                                            : 1 / 60;
                                        setState(() {
                                          _dragDistance += details.delta.dy;
                                          _dragVelocity =
                                              details.delta.dy /
                                              math.max(.001, elapsed);
                                          _dragTime = now;
                                        });
                                      }
                                    : null,
                                onVerticalDragEnd: widget.interactionEnabled
                                    ? (_) {
                                        if (_dragDistance < -36) {
                                          activate();
                                        } else if (_dragDistance > 36) {
                                          _reveal(card);
                                        }
                                        _dragDistance = 0;
                                        setState(() {
                                          _pressed = null;
                                          _dragVelocity = 0;
                                        });
                                      }
                                    : null,
                                onVerticalDragCancel: _cancelPress,
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
                                    onTapDown:
                                        widget.interactionEnabled &&
                                            !_submitting
                                        ? (_) {
                                            _holdBackgroundCancelled = false;
                                            setState(() => _pressed = card);
                                            widget.onPick?.call();
                                            _startHoldFeedback(card);
                                          }
                                        : null,
                                    onTapUp: (_) {
                                      _stopHoldFeedback(rebuild: false);
                                      setState(() => _pressed = null);
                                    },
                                    onTapCancel: _cancelPress,
                                    onTap:
                                        widget.interactionEnabled &&
                                            !_submitting
                                        ? activate
                                        : null,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Opacity(
                                          opacity:
                                              !widget.renderArtwork ||
                                                  widget.hiddenCard == card
                                              ? 0
                                              : 1,
                                          child: widget.dealerDeckKey != null
                                              ? DealCardMotion(
                                                  key: ValueKey(
                                                    'hand-deal-${card.firebaseKey}',
                                                  ),
                                                  sourceKey:
                                                      widget.dealerDeckKey!,
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
                                                  travelDuration:
                                                      const Duration(
                                                        milliseconds: 380,
                                                      ),
                                                  initialOpacity: 0.65,
                                                  // Keep the hit target fixed while only the
                                                  // dealt card artwork travels into the hand.
                                                  child: artwork,
                                                ),
                                        ),
                                        if (preparingSlam || preparingReveal)
                                          Positioned(
                                            top: 0,
                                            right: 0,
                                            child: IgnorePointer(
                                              child: DecoratedBox(
                                                key: ValueKey(
                                                  'hand-remaining-${card.firebaseKey}',
                                                ),
                                                decoration: BoxDecoration(
                                                  color: TableStyle.ink,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: TableStyle.brass,
                                                  ),
                                                ),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 3,
                                                      ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        preparingSlam
                                                            ? Icons
                                                                  .bolt_outlined
                                                            : Icons
                                                                  .visibility_outlined,
                                                        color: TableStyle.brass,
                                                        size: 14,
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        '${(preparingSlam ? widget.slamUsesRemaining : widget.revealUsesRemaining).clamp(0, 3)}',
                                                        style: const TextStyle(
                                                          color:
                                                              TableStyle.brass,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
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
          ),
        );
      },
    );
  }
}
