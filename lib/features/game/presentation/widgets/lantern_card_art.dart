import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/models/card.dart' as game;
import 'table_style.dart';

/// Vector card artwork: correct ranks/pip counts, no font-scaled hit geometry.
/// Only the free default deck uses this; equipped/custom artwork stays intact.
class LanternCardArt extends StatelessWidget {
  final game.Card card;
  final bool faceUp;
  final double width;
  final double height;
  const LanternCardArt({
    super.key,
    required this.card,
    required this.faceUp,
    required this.width,
    required this.height,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _CardPainter(card, faceUp)),
        ),
        if (faceUp && card.rank.value > 10)
          Positioned(
            left: width * .19,
            top: height * .04,
            width: width * .62,
            height: height * .92,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Image.asset(
                'assets/images/cards/lantern/${card.rank.name}_v1.png',
                fit: BoxFit.fill,
                cacheWidth: 160,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        if (faceUp && card.rank.value > 10)
          Positioned.fill(
            child: CustomPaint(
              painter: _CardPainter(card, true, indicesOnly: true),
            ),
          ),
      ],
    ),
  );
}

class _CardPainter extends CustomPainter {
  final game.Card card;
  final bool faceUp;
  final bool indicesOnly;
  const _CardPainter(this.card, this.faceUp, {this.indicesOnly = false});
  String get rank => switch (card.rank) {
    game.Rank.ace => 'A',
    game.Rank.king => 'K',
    game.Rank.queen => 'Q',
    game.Rank.jack => 'J',
    _ => '${card.rank.value}',
  };
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 70, size.height / 100);
    if (indicesOnly) {
      final red =
          card.suit == game.Suit.hearts || card.suit == game.Suit.diamonds;
      final ink = red ? const Color(0xFFB63546) : TableStyle.ink;
      canvas.drawRect(
        const Rect.fromLTWH(3, 2, 14, 34),
        Paint()..color = TableStyle.ivory,
      );
      _corner(canvas, ink);
      canvas.translate(70, 100);
      canvas.rotate(math.pi);
      canvas.drawRect(
        const Rect.fromLTWH(3, 2, 14, 34),
        Paint()..color = TableStyle.ivory,
      );
      _corner(canvas, ink);
      canvas.restore();
      return;
    }
    final shape = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 70, 100),
      const Radius.circular(7),
    );
    canvas.drawRRect(
      shape,
      Paint()..color = faceUp ? TableStyle.ivory : TableStyle.felt,
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..color = faceUp ? TableStyle.ink : TableStyle.ivory
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    if (!faceUp) {
      final line = Paint()
        ..color = TableStyle.brass
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(4, 4, 62, 92),
          const Radius.circular(4),
        ),
        line,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(8, 8, 54, 84),
          const Radius.circular(3),
        ),
        line,
      );
      for (var row = 0; row < 5; row++) {
        for (var col = 0; col < 3; col++) {
          final x = 17.0 + col * 18;
          final y = 18.0 + row * 16;
          canvas.drawPath(
            Path()
              ..moveTo(x, y - 4)
              ..lineTo(x + 4, y)
              ..lineTo(x, y + 4)
              ..lineTo(x - 4, y)
              ..close(),
            Paint()
              ..color = TableStyle.mint.withValues(alpha: 0.7)
              ..style = PaintingStyle.stroke,
          );
        }
      }
      canvas.drawCircle(
        const Offset(35, 50),
        14,
        Paint()..color = TableStyle.felt,
      );
      canvas.drawCircle(const Offset(35, 50), 12, line);
      _suit(
        canvas,
        const Offset(35, 50),
        16,
        game.Suit.diamonds,
        TableStyle.brass,
      );
    } else {
      final red =
          card.suit == game.Suit.hearts || card.suit == game.Suit.diamonds;
      final ink = red ? const Color(0xFFB63546) : TableStyle.ink;
      _corner(canvas, ink);
      canvas.save();
      canvas.translate(70, 100);
      canvas.rotate(math.pi);
      _corner(canvas, ink);
      canvas.restore();
      if (card.rank == game.Rank.ace) {
        _suit(canvas, const Offset(35, 50), 27, card.suit, ink);
      } else if (card.rank.value <= 10) {
        final count = card.rank.value;
        // Pair rows plus a center pip for odd ranks; never synthetic card faces.
        final rows = count ~/ 2;
        for (var row = 0; row < rows; row++) {
          final y = rows == 1 ? 50.0 : 24.0 + row * 52 / (rows - 1);
          _suit(canvas, Offset(24, y), 12, card.suit, ink);
          _suit(canvas, Offset(46, y), 12, card.suit, ink);
        }
        if (count.isOdd) {
          _suit(canvas, const Offset(35, 50), 12, card.suit, ink);
        }
      } else {
        // Readable court-card medallion; rank remains the actual J/Q/K.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(18, 24, 34, 52),
            const Radius.circular(5),
          ),
          Paint()..color = TableStyle.brass.withValues(alpha: 0.2),
        );
        final crown = Path()
          ..moveTo(23, 37)
          ..lineTo(21, 28)
          ..lineTo(29, 32)
          ..lineTo(35, 25)
          ..lineTo(41, 32)
          ..lineTo(49, 28)
          ..lineTo(47, 37)
          ..close();
        canvas.drawPath(crown, Paint()..color = TableStyle.brass);
        _text(canvas, rank, const Offset(27, 39), 23, ink);
        _suit(canvas, const Offset(35, 68), 12, card.suit, ink);
      }
    }
    canvas.restore();
  }

  void _corner(Canvas canvas, Color color) {
    _text(canvas, rank, const Offset(5, 3), 15, color);
    _suit(canvas, const Offset(11, 28), 11, card.suit, color);
  }

  void _text(
    Canvas canvas,
    String value,
    Offset offset,
    double size,
    Color color,
  ) {
    final text = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w800,
          color: color,
          fontFamily: 'LanternDisplay',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, offset);
  }

  void _suit(
    Canvas canvas,
    Offset center,
    double size,
    game.Suit suit,
    Color color,
  ) {
    canvas.save();
    canvas.translate(center.dx - size / 2, center.dy - size / 2);
    canvas.scale(size / 20);
    final paint = Paint()..color = color;
    switch (suit) {
      case game.Suit.diamonds:
        canvas.drawPath(
          Path()
            ..moveTo(10, 0)
            ..lineTo(20, 10)
            ..lineTo(10, 20)
            ..lineTo(0, 10)
            ..close(),
          paint,
        );
      case game.Suit.hearts:
        canvas.drawPath(
          Path()
            ..moveTo(10, 19)
            ..cubicTo(-10, 5, 5, -7, 10, 4)
            ..cubicTo(15, -7, 30, 5, 10, 19)
            ..close(),
          paint,
        );
      case game.Suit.spades:
        canvas.drawPath(
          Path()
            ..moveTo(10, 0)
            ..cubicTo(-10, 15, 5, 24, 10, 13)
            ..cubicTo(15, 24, 30, 15, 10, 0)
            ..close(),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(10, 10)
            ..lineTo(6, 20)
            ..lineTo(14, 20)
            ..close(),
          paint,
        );
      case game.Suit.clubs:
        canvas.drawCircle(const Offset(10, 5), 5, paint);
        canvas.drawCircle(const Offset(5, 12), 5, paint);
        canvas.drawCircle(const Offset(15, 12), 5, paint);
        canvas.drawPath(
          Path()
            ..moveTo(10, 10)
            ..lineTo(6, 20)
            ..lineTo(14, 20)
            ..close(),
          paint,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CardPainter oldDelegate) =>
      oldDelegate.card != card ||
      oldDelegate.faceUp != faceUp ||
      oldDelegate.indicesOnly != indicesOnly;
}
