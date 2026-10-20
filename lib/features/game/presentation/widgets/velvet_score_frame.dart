import 'package:flutter/material.dart';
import 'table_style.dart';

/// Presentation only: the approved velvet scoreboard, with live widget content.
class VelvetScoreFrame extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const VelvetScoreFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x88000000),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: CustomPaint(
      painter: const _VelvetPainter(),
      child: Padding(padding: padding, child: child),
    ),
  );
}

class _VelvetPainter extends CustomPainter {
  const _VelvetPainter();
  Path _frame(Rect r) {
    const c = 16.0;
    return Path()
      ..moveTo(r.left + c, r.top)
      ..lineTo(r.right - c, r.top)
      ..quadraticBezierTo(r.right - c, r.top + c, r.right, r.top + c)
      ..lineTo(r.right, r.bottom - c)
      ..quadraticBezierTo(r.right - c, r.bottom - c, r.right - c, r.bottom)
      ..lineTo(r.left + c, r.bottom)
      ..quadraticBezierTo(r.left + c, r.bottom - c, r.left, r.bottom - c)
      ..lineTo(r.left, r.top + c)
      ..quadraticBezierTo(r.left + c, r.top + c, r.left + c, r.top)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = _frame(rect.deflate(2));
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF172B3C), Color(0xFF081726), Color(0xFF142233)],
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipPath(path);
    final weave = Paint()
      ..color = TableStyle.ivory.withValues(alpha: .018)
      ..strokeWidth = .5;
    for (double x = -size.height; x < size.width; x += 8) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        weave,
      );
    }
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF996226),
            TableStyle.brass,
            Color(0xFFFFE2A4),
            Color(0xFF996226),
          ],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ).createShader(rect),
    );
    canvas.drawPath(
      _frame(rect.deflate(7)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7
        ..color = TableStyle.brass.withValues(alpha: .7),
    );
    final gem = Paint()..color = TableStyle.brass.withValues(alpha: .8);
    for (final p in [
      const Offset(20, 20),
      Offset(size.width - 20, 20),
      Offset(20, size.height - 20),
      Offset(size.width - 20, size.height - 20),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(p.dx, p.dy - 3)
          ..lineTo(p.dx + 3, p.dy)
          ..lineTo(p.dx, p.dy + 3)
          ..lineTo(p.dx - 3, p.dy)
          ..close(),
        gem,
      );
    }
  }

  @override
  bool shouldRepaint(_VelvetPainter oldDelegate) => false;
}

class VelvetScoreTile extends StatelessWidget {
  final String label, scoreLabel;
  final int score;
  final Color color;
  final Widget? players, footer;
  final bool winner, compact;
  const VelvetScoreTile({
    super.key,
    required this.label,
    required this.score,
    required this.scoreLabel,
    required this.color,
    this.players,
    this.footer,
    this.winner = false,
    this.compact = false,
  });
  @override
  Widget build(BuildContext context) => VelvetScoreFrame(
    padding: EdgeInsets.all(compact ? 12 : 18),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TableStyle.label.copyWith(
            color: color,
            fontSize: compact ? 17 : 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (winner || players != null)
          SizedBox(
            height: 20,
            child: winner
                ? const Icon(
                    Icons.workspace_premium_rounded,
                    size: 20,
                    color: TableStyle.brass,
                  )
                : null,
          ),
        const SizedBox(height: 4),
        Text(
          '$score',
          key: const ValueKey('velvet-score-value'),
          style: TableStyle.label.copyWith(
            color: color,
            fontSize: compact ? 38 : 48,
            height: 1.1,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          scoreLabel,
          textAlign: TextAlign.center,
          style: TableStyle.detail.copyWith(color: TableStyle.ivory),
        ),
        if (players != null) ...[const SizedBox(height: 8), players!],
        if (footer != null) ...[const SizedBox(height: 8), footer!],
      ],
    ),
  );
}
