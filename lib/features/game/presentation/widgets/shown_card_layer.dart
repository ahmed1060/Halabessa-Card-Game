import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/models/card.dart' as game;
import '../../domain/models/card_feature_state.dart';
import '../providers/visual_action_queue.dart';
import 'option_b_table.dart';
import 'table_style.dart';

/// Accepted public copies only. This layer cannot play, capture or own a card.
/// Flutter owns this overlay for both card renderers. A native adapter must
/// negotiate ownership instead of instantiating a second disclosed copy.
class ShownCardLayer extends StatefulWidget {
  final List<ShownCard> cards;
  final List<String> seats;
  final String localUid;
  final OptionBGeometry geometry;
  final Widget Function(game.Card, double, double) faceBuilder;
  final Widget Function(double, double) backBuilder;
  final void Function(String id)? onContact;
  const ShownCardLayer({
    super.key,
    required this.cards,
    required this.seats,
    required this.localUid,
    required this.geometry,
    required this.faceBuilder,
    required this.backBuilder,
    this.onContact,
  });
  @override
  State<ShownCardLayer> createState() => _ShownCardLayerState();
}

class _ShownCardLayerState extends State<ShownCardLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(vsync: this)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && _queue.active != null) {
        _queue.complete(_queue.active!.id, _queue.generation);
      }
    });
  late final VisualActionQueue<ShownCard> _queue = VisualActionQueue<ShownCard>(
    capacity: 1,
    allowance: const Duration(milliseconds: 100),
    onStart: (action) {
      _waiting.remove(action.id);
      _contact?.cancel();
      _contact = Timer(
        Duration(
          milliseconds: (action.duration.inMilliseconds * .64 - 30).round(),
        ),
        () {
          if (mounted && widget.cards.any((c) => c.eventId == action.id)) {
            widget.onContact?.call(action.id);
          }
        },
      );
      _motion.duration = action.duration;
      _motion.forward(from: 0);
      setState(() {});
    },
    onFinish: (_, __) {
      if (mounted) setState(() {});
    },
    onOverflow: () {
      _motion.stop();
      _contact?.cancel();
      _waiting.clear();
    },
  );
  final _waiting = <String>{};
  Timer? _contact;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context) || !cardJuiceEnabled;
    if (_reduced) {
      _motion.stop();
      _contact?.cancel();
      _waiting.clear();
      _queue.reset();
    }
  }

  @override
  void didUpdateWidget(ShownCardLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.cards.map((c) => c.eventId).toSet();
    if (_queue.active != null && !ids.contains(_queue.active!.id)) {
      // A real play beats a pending reveal, without refunding its disclosure.
      _motion.stop();
      _contact?.cancel();
      _waiting.clear();
      _queue.reset(alreadySeen: ids);
    }
    final old = oldWidget.cards.map((c) => c.eventId).toSet();
    final added = widget.cards.where((c) => !old.contains(c.eventId)).toList();
    // Mount/reconnect is deliberately silent. Catch-up snapshots of several
    // reveals settle immediately instead of making players wait for a backlog.
    if (added.length > 2 || _reduced) {
      _motion.stop();
      _contact?.cancel();
      _waiting.clear();
      _queue.reset(alreadySeen: ids);
      if (_reduced && added.length == 1) {
        final id = added.single.eventId;
        _contact = Timer(Duration.zero, () {
          if (mounted && widget.cards.any((c) => c.eventId == id))
            widget.onContact?.call(id);
        });
      }
      return;
    }
    for (final card in added) {
      _waiting.add(card.eventId);
      _queue.add(
        VisualAction(
          card.eventId,
          card,
          Duration(milliseconds: _queue.active == null ? 470 : 180),
        ),
      );
    }
  }

  @override
  void dispose() {
    _contact?.cancel();
    _queue.dispose();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _motion,
      builder: (_, __) => Stack(
        clipBehavior: Clip.none,
        children: [
          for (var seat = 0; seat < widget.seats.length; seat++)
            ..._seatCards(widget.seats[seat], seat),
        ],
      ),
    ),
  );

  List<Widget> _seatCards(String uid, int seat) {
    final cards = widget.cards.where((c) => c.ownerUid == uid).take(3).toList();
    final g = widget.geometry;
    final width = g.landscape ? 30.0 : 24.0, height = width * 1.44;
    final group = width * 3 + 6;
    Rect area;
    if (!g.landscape) {
      // One compact, seat-ordered disclosure rail, separated from live cards.
      area = Rect.fromLTWH(
        (g.size.width - group * 4 - 12) / 2 + seat * (group + 4),
        g.hand.top - height - 3,
        group,
        height,
      );
    } else {
      final centers = [
        Offset(g.hand.left - group / 2 - 16, g.board.bottom + 40),
        Offset(g.board.right + group / 2 + 18, g.board.center.dy),
        // The old top-center group hid behind the partner avatar/name/dealer.
        // Use the open table-side column, above (not over) the rival's row.
        Offset(g.board.right + group / 2 + 18, g.board.center.dy - height - 8),
        Offset(g.board.left - group / 2 - 18, g.board.center.dy),
      ];
      area = Rect.fromCenter(
        center: centers[seat],
        width: group,
        height: height,
      );
      if (seat == 0 && area.overlaps(g.left)) {
        // Narrow landscapes have no spare width beside the left bot's fan.
        // Keep the local disclosure beside our hand, but below that seat.
        area = area.translate(0, g.left.bottom + 8 - area.top);
      }
    }
    return [
      for (var i = 0; i < cards.length; i++)
        if (!_waiting.contains(cards[i].eventId))
          _copy(
            cards[i],
            Rect.fromLTWH(area.left + i * (width + 3), area.top, width, height),
            seat,
          ),
    ];
  }

  Widget _copy(ShownCard card, Rect target, int seat) {
    final active = _queue.active?.id == card.eventId;
    final t = active ? _motion.value : 1.0;
    final flight = ((t - .21) / .43).clamp(0.0, 1.0);
    final approach = (t / .21).clamp(0.0, 1.0);
    final settle = ((t - .75) / .25).clamp(0.0, 1.0);
    final from = seat == 0
        ? widget.geometry.hand.center
        : switch (seat) {
            1 => widget.geometry.right.center,
            2 => widget.geometry.partner.center,
            _ => widget.geometry.left.center,
          };
    final position = Offset.lerp(
      from,
      target.center,
      Curves.easeInCubic.transform(flight),
    )!;
    final scale = t < .64 ? 1 + .5 * approach * (1 - flight) : 1.0;
    final punch = math.sin(math.pi * settle) * .06;
    final flip = card.ownerUid == widget.localUid || !active ? 1.0 : flight;
    final front = flip >= .5;
    final face = front
        ? widget.faceBuilder(card.card, target.width, target.height)
        : widget.backBuilder(target.width, target.height);
    return Positioned.fromRect(
      rect: Rect.fromCenter(
        center: position,
        width: target.width,
        height: target.height,
      ),
      child: Semantics(
        key: ValueKey('shown-${card.eventId}'),
        label: '${card.ownerUid}: ${card.card}',
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, .001)
            ..rotateZ(active ? math.sin(math.pi * flight) * .16 : 0)
            ..scaleByDouble(
              scale *
                  (1 + punch) *
                  (front && flip == 1
                      ? 1
                      : math.cos(math.pi * flip).abs().clamp(.02, 1)),
              scale * (1 - punch),
              1,
              1,
            ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                width: 1.5,
                color: seat.isEven ? TableStyle.mint : TableStyle.red,
              ),
              borderRadius: BorderRadius.circular(3),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 3,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: face,
          ),
        ),
      ),
    );
  }
}
