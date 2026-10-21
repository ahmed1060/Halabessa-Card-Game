import 'dart:async';
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
  final bool deckSide;
  final bool shuffleIntro;
  final bool compact;
  final DateTime? startedAt;
  final String? shuffleTitle, shuffleMessage, shuffleNext;
  const MatchPhasePanel({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    required this.failureMessage,
    this.deckSide = false,
    this.shuffleIntro = false,
    this.compact = false,
    this.startedAt,
    this.shuffleTitle,
    this.shuffleMessage,
    this.shuffleNext,
  });
  @override
  State<MatchPhasePanel> createState() => _MatchPhasePanelState();
}

class _MatchPhasePanelState extends State<MatchPhasePanel> {
  bool _pending = false;
  bool _failed = false;
  bool _shuffling = false;
  Timer? _intro;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro?.cancel();
      _shuffling = false;
      return;
    }
    if (_intro != null || !widget.shuffleIntro) return;
    final age = widget.startedAt == null
        ? Duration.zero
        : DateTime.now().difference(widget.startedAt!);
    final remaining = Duration(
      milliseconds: 650 - age.inMilliseconds.clamp(0, 650),
    );
    if (remaining <= Duration.zero) return;
    _shuffling = true;
    _intro = Timer(remaining, () {
      if (mounted) setState(() => _shuffling = false);
    });
  }

  @override
  void dispose() {
    _intro?.cancel();
    super.dispose();
  }

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
      if (mounted) {
        setState(() {
          _pending = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return Semantics(
        label: '${widget.title}. ${widget.message}',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.onAction != null && widget.actionLabel != null)
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
              )
            else
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: TableStyle.detail,
              ),
            if (_failed)
              Text(
                widget.failureMessage,
                textAlign: TextAlign.center,
                style: TableStyle.detail,
              ),
          ],
        ),
      );
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (widget.deckSide)
          Positioned(
            left:
                MediaQuery.sizeOf(context).width >
                    MediaQuery.sizeOf(context).height
                ? 64
                : -8,
            top:
                MediaQuery.sizeOf(context).width >
                    MediaQuery.sizeOf(context).height
                ? -8
                : 28,
            child: Transform.rotate(
              angle: .785398,
              child: const SizedBox(
                width: 18,
                height: 18,
                child: ColoredBox(color: TableStyle.ivory),
              ),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: LanternPanel(
            selected: widget.deckSide,
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _shuffling
                        ? widget.shuffleTitle ?? widget.title
                        : widget.title,
                    textAlign: TextAlign.center,
                    style: TableStyle.label.copyWith(
                      color: TableStyle.ink,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _failed
                      ? widget.failureMessage
                      : _shuffling
                      ? widget.shuffleMessage ?? widget.message
                      : widget.message,
                  textAlign: TextAlign.center,
                  style: TableStyle.label.copyWith(color: TableStyle.ink),
                ),
                if (_shuffling) ...[
                  const SizedBox(height: 8),
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: TableStyle.brass,
                    ),
                  ),
                  if (widget.shuffleNext != null &&
                      widget.onAction == null) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.shuffleNext!,
                      textAlign: TextAlign.center,
                      style: TableStyle.detail.copyWith(color: TableStyle.ink),
                    ),
                  ],
                ],
                // The cosmetic shuffle never disables a legal cut or extends its deadline.
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
          ),
        ),
      ],
    );
  }
}
