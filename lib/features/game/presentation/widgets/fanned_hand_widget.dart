import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as game_card;
import 'package:halabessa/features/game/presentation/widgets/card_widget.dart';
import 'table_style.dart';

/// Bounded, keyboard-accessible hand. Queued cards use identity, not list index.
class FannedHandWidget extends StatefulWidget {
  final List<game_card.Card> cards;
  final void Function(game_card.Card, Offset origin) onCardTap;
  final bool isMyTurn;
  final bool interactionEnabled;
  final Widget Function(game_card.Card, double, double)? cardBuilder;
  final String Function(game_card.Card)? cardLabelBuilder;
  final String playHint;
  final String queueHint;

  const FannedHandWidget({
    super.key, required this.cards, required this.onCardTap,
    this.isMyTurn = false, this.interactionEnabled = true, this.cardBuilder,
    this.cardLabelBuilder, this.playHint = 'Play card',
    this.queueHint = 'Queue card; tap again to cancel',
  });

  @override
  State<FannedHandWidget> createState() => _FannedHandWidgetState();
}

class _FannedHandWidgetState extends State<FannedHandWidget> {
  game_card.Card? _queued;
  game_card.Card? _hovered;
  Offset _queuedOrigin = Offset.zero;
  Timer? _autoPlay;
  Timer? _tapGuard;
  bool _submitting = false;
  double _dragDistance = 0;
  Offset _dragOrigin = Offset.zero;

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
        widget.isMyTurn && widget.interactionEnabled && _queued != null) {
      final selected = _queued!;
      _autoPlay?.cancel();
      _autoPlay = Timer(const Duration(milliseconds: 300), () {
        if (mounted && _queued == selected && widget.cards.contains(selected)) {
          _activate(selected, _queuedOrigin);
        }
      });
    }
  }

  void _activate(game_card.Card card, Offset origin) {
    if (!widget.interactionEnabled || _submitting || !widget.cards.contains(card)) return;
    _autoPlay?.cancel();
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
    });
    // Suppress double taps but allow retry after a rejected command.
    // Server revisions remain the authoritative duplicate protection.
    _tapGuard?.cancel();
    _tapGuard = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _submitting = false);
    });
    widget.onCardTap(card, origin);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, constraints) {
      final available = constraints.hasBoundedWidth
          ? constraints.maxWidth : MediaQuery.sizeOf(context).width;
      final compact = constraints.hasBoundedHeight && constraints.maxHeight < 145;
      final width = math.min(compact ? 60.0 : 80.0,
          math.max(40.0, (available - 32) / math.min(widget.cards.length, 4)));
      final height = width * 1.43;
      final spacing = widget.cards.length == 1 ? 0.0 :
          math.min(width + 8, math.max(0.0, (available - 16 - width) / (widget.cards.length - 1)));
      final totalWidth = width + spacing * (widget.cards.length - 1);
      final reducedMotion = MediaQuery.disableAnimationsOf(context);
      return Center(
        heightFactor: 1,
        child: SizedBox(
          width: totalWidth, height: height + 28,
          child: Stack(children: [
            for (var index = 0; index < widget.cards.length; index++)
              Positioned(
                key: ValueKey(widget.cards[index].firebaseKey),
                left: index * spacing, bottom: 8,
                child: Builder(builder: (cardContext) {
                  final card = widget.cards[index];
                  final selected = _queued == card;
                  void activate() {
                    final box = cardContext.findRenderObject() as RenderBox?;
                    _activate(card, box?.localToGlobal(Offset(width / 2, height / 2)) ?? Offset.zero);
                  }
                  return AnimatedPadding(
                    duration: reducedMotion ? Duration.zero : const Duration(milliseconds: 120),
                    padding: EdgeInsets.only(bottom: selected ? 12 : (_hovered == card ? 6 : 0)),
                    child: Semantics(
                      label: widget.cardLabelBuilder?.call(card) ?? card.toString(),
                      hint: widget.isMyTurn ? widget.playHint : widget.queueHint,
                      selected: selected,
                      child: GestureDetector(
                        key: ValueKey('hand-card-${card.firebaseKey}'),
                        onVerticalDragStart: widget.interactionEnabled ? (details) {
                          _dragDistance = 0;
                          _dragOrigin = details.globalPosition;
                        } : null,
                        onVerticalDragUpdate: widget.interactionEnabled ? (details) {
                          _dragDistance += details.delta.dy;
                        } : null,
                        onVerticalDragEnd: widget.interactionEnabled ? (_) {
                          if (_dragDistance < -36) _activate(card, _dragOrigin);
                          _dragDistance = 0;
                        } : null,
                        onVerticalDragCancel: () => _dragDistance = 0,
                        child: Material(
                          color: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: selected ? TableStyle.brass : Colors.transparent, width: 2),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            focusColor: TableStyle.brass.withOpacity(0.5),
                            onHover: (value) => setState(() => _hovered = value ? card : null),
                            onTap: widget.interactionEnabled && !_submitting ? activate : null,
                            child: ExcludeSemantics(child: IgnorePointer(child:
                              widget.cardBuilder?.call(card, width, height) ??
                                  CardWidget(card: card, width: width, height: height),
                            )),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
          ]),
        ),
      );
    });
  }
}
