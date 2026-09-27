import 'dart:async';
import 'package:flutter/material.dart';
import 'table_style.dart';

/// Fixed seat geometry; the countdown is derived from the server turn timestamp.
class TableSeat extends StatefulWidget {
  final String name;
  final String detail;
  final String? avatarUrl;
  final String? message;
  final bool isBot;
  final bool active;
  final DateTime? turnStarted;
  final int turnSeconds;
  final VoidCallback? onPressed;
  const TableSeat({super.key, required this.name, required this.detail,
    this.avatarUrl, this.message, this.isBot = false, this.active = false,
    this.turnStarted, this.turnSeconds = 0, this.onPressed});

  @override
  State<TableSeat> createState() => _TableSeatState();
}

class _TableSeatState extends State<TableSeat> {
  Timer? _clock;
  @override
  void initState() { super.initState(); _updateClock(); }
  @override
  void didUpdateWidget(TableSeat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active || oldWidget.turnStarted != widget.turnStarted ||
        oldWidget.turnSeconds != widget.turnSeconds) _updateClock();
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
  void dispose() { _clock?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final url = widget.avatarUrl;
    final remaining = widget.turnStarted == null || widget.turnSeconds <= 0 ? 0.0 :
        (1 - DateTime.now().difference(widget.turnStarted!).inMilliseconds /
          (widget.turnSeconds * 1000)).clamp(0.0, 1.0);
    return SizedBox(width: 110, child: Tooltip(
      message: [widget.name, widget.detail, if (widget.message != null) widget.message!].join('\n'),
      child: Material(color: Colors.transparent, child: InkWell(
        onTap: widget.onPressed, borderRadius: BorderRadius.circular(12),
        focusColor: TableStyle.brass.withOpacity(0.4),
        child: Padding(padding: const EdgeInsets.all(4), child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            Stack(alignment: Alignment.center, children: [
              SizedBox(width: 44, height: 44, child: CircularProgressIndicator(
                value: widget.active ? (widget.turnSeconds > 0 ? remaining : 1) : 0,
                backgroundColor: TableStyle.muted.withOpacity(0.15),
                color: TableStyle.brass, strokeWidth: 2,
              )),
              CircleAvatar(radius: 18, backgroundColor: TableStyle.ink,
                foregroundImage: url == null || url.isEmpty ? null :
                  (url.startsWith('assets/') ? AssetImage(url) : NetworkImage(url)) as ImageProvider,
                onForegroundImageError: url == null || url.isEmpty ? null : (_, __) {},
                child: Icon(widget.isBot ? Icons.smart_toy_outlined : Icons.person_outline,
                  color: TableStyle.ivory, size: 22)),
            ]),
            const SizedBox(height: 4),
            Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TableStyle.detail.copyWith(color: TableStyle.ivory, fontWeight: FontWeight.w600)),
            Text(widget.detail, maxLines: 2, overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TableStyle.detail.copyWith(color: widget.active ? TableStyle.brass : TableStyle.muted)),
            if (widget.message != null)
              Text(widget.message!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TableStyle.detail),
          ],
        )),
      )),
    ));
  }
}
