import 'dart:async';
import 'package:flutter/material.dart';
import 'table_style.dart';
import 'match_table_layout.dart';
import '../../../../core/widgets/lantern_card_fan.dart';
import '../../../../core/widgets/lantern_page_frame.dart';

/// Starts one recovery attempt per mounted identity, never from a build loop.
class MatchRecoveryView extends StatefulWidget {
  final Future<void> Function()? onRetry;
  final VoidCallback onExit;
  final String loadingTitle,
      unavailableTitle,
      explanation,
      retryLabel,
      exitLabel;
  final Duration timeout;
  final bool terminal;
  const MatchRecoveryView({
    super.key,
    required this.onRetry,
    required this.onExit,
    required this.loadingTitle,
    required this.unavailableTitle,
    required this.explanation,
    required this.retryLabel,
    required this.exitLabel,
    this.timeout = const Duration(seconds: 8),
    this.terminal = false,
  });
  @override
  State<MatchRecoveryView> createState() => _MatchRecoveryViewState();
}

class _MatchRecoveryViewState extends State<MatchRecoveryView> {
  Timer? _timeout;
  bool _pending = true;
  int _attempt = 0;
  @override
  void initState() {
    super.initState();
    if (widget.terminal) {
      _pending = false;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _recover();
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  Future<void> _recover() async {
    final attempt = ++_attempt;
    _timeout?.cancel();
    setState(() => _pending = true);
    _timeout = Timer(widget.timeout, () {
      if (mounted && attempt == _attempt) setState(() => _pending = false);
    });
    try {
      await widget.onRetry?.call();
      if (widget.terminal && mounted && attempt == _attempt) {
        _timeout?.cancel();
        setState(() => _pending = false);
      }
      // Binding a stream is not confirmation that a match loaded. The parent
      // removes this view only when it has both the profile and match state.
    } catch (_) {
      if (mounted && attempt == _attempt) {
        _timeout?.cancel();
        setState(() => _pending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => LanternPageFrame(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LanternWordmark(),
                  const SizedBox(height: 32),
                  const LanternCardFan(),
                  const SizedBox(height: 24),
                  if (_pending)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 24),
                      child: CircularProgressIndicator(color: TableStyle.brass),
                    ),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _pending ? widget.loadingTitle : widget.unavailableTitle,
                      textAlign: TextAlign.center,
                      style: TableStyle.label.copyWith(fontSize: 22),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.explanation,
                    textAlign: TextAlign.center,
                    style: TableStyle.label,
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: TableStyle.mint,
                          foregroundColor: TableStyle.ink,
                          minimumSize: const Size(140, 52),
                        ),
                        onPressed: _pending || widget.onRetry == null
                            ? null
                            : _recover,
                        child: Text(widget.retryLabel),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: TableStyle.ink,
                          foregroundColor: TableStyle.ivory,
                          side: const BorderSide(color: TableStyle.mint),
                          minimumSize: const Size(140, 52),
                        ),
                        onPressed: widget.onExit,
                        child: Text(widget.exitLabel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
