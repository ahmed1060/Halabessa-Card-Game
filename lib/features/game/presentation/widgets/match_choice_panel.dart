import 'package:flutter/material.dart';
import 'table_style.dart';

/// A two-way phase decision that stays in the hand tray. The first tap owns
/// the request until it resolves; a transient backend failure leaves a retry.
class MatchChoicePanel extends StatefulWidget {
  final String title, detail, firstLabel, secondLabel, failureMessage;
  final bool canVote;
  final Future<void> Function()? onFirst, onSecond;
  const MatchChoicePanel({super.key, required this.title, required this.detail,
    required this.firstLabel, required this.secondLabel, required this.failureMessage,
    required this.canVote, this.onFirst, this.onSecond});

  @override
  State<MatchChoicePanel> createState() => _MatchChoicePanelState();
}

class _MatchChoicePanelState extends State<MatchChoicePanel> {
  bool _pending = false;
  bool _failed = false;
  Future<void> _submit(Future<void> Function()? action) async {
    if (_pending || action == null) return;
    setState(() { _pending = true; _failed = false; });
    try {
      await action();
      if (mounted) setState(() => _pending = false);
    } catch (_) {
      if (mounted) setState(() { _pending = false; _failed = true; });
    }
  }

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Semantics(liveRegion: true, child: Text(widget.title, textAlign: TextAlign.center,
      style: TableStyle.label.copyWith(color: TableStyle.brass, fontWeight: FontWeight.bold))),
    const SizedBox(height: 6),
    Text(_failed ? widget.failureMessage : widget.detail,
      textAlign: TextAlign.center, style: TableStyle.label),
    if (widget.canVote) ...[
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: TableStyle.brass,
            foregroundColor: TableStyle.ink, minimumSize: const Size(112, 48)),
          onPressed: _pending || widget.onFirst == null ? null : () => _submit(widget.onFirst),
          child: Text(widget.firstLabel, textAlign: TextAlign.center),
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: TableStyle.ivory,
            minimumSize: const Size(112, 48)),
          onPressed: _pending || widget.onSecond == null ? null : () => _submit(widget.onSecond),
          child: Text(widget.secondLabel, textAlign: TextAlign.center),
        ),
      ]),
    ],
  ]);
}
