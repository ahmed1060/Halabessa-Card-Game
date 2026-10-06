import 'package:flutter/material.dart';
import 'table_style.dart';
import '../../../../core/widgets/lantern_panel.dart';

/// A phase action belongs in the tray, not in a modal covering the table.
class MatchPhasePanel extends StatefulWidget {
  final String title;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;
  final String failureMessage;
  const MatchPhasePanel({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    required this.failureMessage,
  });
  @override
  State<MatchPhasePanel> createState() => _MatchPhasePanelState();
}

class _MatchPhasePanelState extends State<MatchPhasePanel> {
  bool _pending = false;
  bool _failed = false;
  Future<void> _act() async {
    if (_pending || widget.onAction == null) return;
    setState(() {
      _pending = true;
      _failed = false;
    });
    try {
      await widget.onAction!();
      if (mounted) setState(() => _pending = false);
    } catch (_) {
      if (mounted)
        setState(() {
          _pending = false;
          _failed = true;
        });
    }
  }

  @override
  Widget build(BuildContext context) => LanternPanel(
    padding: const EdgeInsets.all(12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            widget.title,
            textAlign: TextAlign.center,
            style: TableStyle.label.copyWith(
              color: TableStyle.ink,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _failed ? widget.failureMessage : widget.message,
          textAlign: TextAlign.center,
          style: TableStyle.label.copyWith(color: TableStyle.ink),
        ),
        if (widget.onAction != null && widget.actionLabel != null) ...[
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: TableStyle.brass,
              foregroundColor: TableStyle.ink,
              minimumSize: const Size(120, 48),
            ),
            onPressed: _pending ? null : _act,
            child: _pending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.actionLabel!),
          ),
        ],
      ],
    ),
  );
}
