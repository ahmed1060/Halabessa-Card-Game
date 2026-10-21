import 'package:flutter/material.dart';
import 'dart:async';
import 'table_style.dart';
import '../../../../core/widgets/lantern_panel.dart';

/// A two-way phase decision that stays in the hand tray. The first tap owns
/// the request until it resolves; a transient backend failure leaves a retry.
class MatchChoicePanel extends StatefulWidget {
  final String title, detail, firstLabel, secondLabel, failureMessage;
  final bool canVote;
  final bool deckSide;
  final DateTime? voteStartedAt;
  final String Function(int)? countdownLabel;
  final Future<void> Function()? onFirst, onSecond;
  const MatchChoicePanel({
    super.key,
    required this.title,
    required this.detail,
    required this.firstLabel,
    required this.secondLabel,
    required this.failureMessage,
    required this.canVote,
    this.deckSide = false,
    this.onFirst,
    this.onSecond,
    this.voteStartedAt,
    this.countdownLabel,
  });

  @override
  State<MatchChoicePanel> createState() => _MatchChoicePanelState();
}

class _MatchChoicePanelState extends State<MatchChoicePanel> {
  bool _pending = false;
  bool _failed = false;
  Timer? _clock;
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted && widget.voteStartedAt != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  int get _remaining => widget.voteStartedAt == null
      ? 10
      : ((10000 -
                    DateTime.now()
                        .difference(widget.voteStartedAt!)
                        .inMilliseconds) /
                1000)
            .ceil()
            .clamp(0, 10);
  Future<void> _submit(Future<void> Function()? action) async {
    if (_pending || action == null) return;
    setState(() {
      _pending = true;
      _failed = false;
    });
    try {
      await action();
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
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      if (widget.deckSide)
        Positioned(
          left:
              MediaQuery.sizeOf(context).width >
                  MediaQuery.sizeOf(context).height
              ? 124
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
      LanternPanel(
        selected: widget.deckSide,
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).height < 400
              ? 6
              : widget.deckSide
              ? 8
              : 12,
        ),
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
              _failed ? widget.failureMessage : widget.detail,
              textAlign: TextAlign.center,
              style: TableStyle.label.copyWith(color: TableStyle.ink),
            ),
            if (widget.countdownLabel != null) ...[
              const SizedBox(height: 6),
              Text(
                widget.countdownLabel!(_remaining),
                textAlign: TextAlign.center,
                style: TableStyle.label.copyWith(color: TableStyle.ink),
              ),
            ],
            if (widget.canVote && _remaining > 0) ...[
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, bounds) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    SizedBox(
                      width: widget.deckSide
                          ? (bounds.maxWidth < 184
                                ? bounds.maxWidth
                                : (bounds.maxWidth - 8) / 2)
                          : null,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: TableStyle.brass,
                          foregroundColor: TableStyle.ink,
                          minimumSize: Size(widget.deckSide ? 96 : 112, 48),
                          padding: widget.deckSide
                              ? const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 8,
                                )
                              : null,
                        ),
                        onPressed: _pending || widget.onFirst == null
                            ? null
                            : () => _submit(widget.onFirst),
                        child: Text(
                          widget.firstLabel,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: widget.deckSide
                          ? (bounds.maxWidth < 184
                                ? bounds.maxWidth
                                : (bounds.maxWidth - 8) / 2)
                          : null,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          // The application theme gives outlined buttons an ink fill.
                          // Keep the label readable on it, including pending requests.
                          backgroundColor: TableStyle.ink,
                          foregroundColor: TableStyle.ivory,
                          disabledBackgroundColor: TableStyle.ink,
                          disabledForegroundColor: TableStyle.ivory.withValues(
                            alpha: .6,
                          ),
                          minimumSize: Size(widget.deckSide ? 96 : 112, 48),
                          padding: widget.deckSide
                              ? const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 8,
                                )
                              : null,
                        ),
                        onPressed: _pending || widget.onSecond == null
                            ? null
                            : () => _submit(widget.onSecond),
                        child: Text(
                          widget.secondLabel,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}
