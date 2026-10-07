import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/widgets/lantern_panel.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../game/presentation/widgets/table_style.dart';

/// Provider callbacks link the existing guest, never navigate to a sign-in form
/// that could silently replace the guest's account and progress.
class GuestProgressPanel extends StatefulWidget {
  final Future<bool> Function() onGoogle, onFacebook;
  final Future<bool> Function()? onApple;
  const GuestProgressPanel({
    super.key,
    required this.onGoogle,
    required this.onFacebook,
    this.onApple,
  });
  @override
  State<GuestProgressPanel> createState() => _GuestProgressPanelState();
}

class _GuestProgressPanelState extends State<GuestProgressPanel> {
  bool _pending = false;
  String? _error;
  Future<void> _link(Future<bool> Function() action) async {
    if (_pending) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await action(); // A cancelled provider flow is not an error or a success.
    } catch (error) {
      if (mounted)
        setState(() => _error = ErrorHandler.getAuthErrorMessage(error));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) => LanternPanel(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.shield_outlined, color: TableStyle.ink, size: 32),
        const SizedBox(height: 8),
        Text(
          'ui_save_progress'.tr(),
          textAlign: TextAlign.center,
          style: TableStyle.label.copyWith(
            color: TableStyle.ink,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'ui_guest_save'.tr(),
          textAlign: TextAlign.center,
          style: TableStyle.detail.copyWith(color: TableStyle.ink),
        ),
        const SizedBox(height: 14),
        for (final entry in [
          ('Google', Icons.g_mobiledata_rounded, widget.onGoogle),
          ('Facebook', Icons.facebook_rounded, widget.onFacebook),
          if (widget.onApple != null)
            ('Apple', Icons.apple_rounded, widget.onApple!),
        ]) ...[
          FilledButton.icon(
            key: ValueKey('guest-link-${entry.$1}'),
            style: FilledButton.styleFrom(
              backgroundColor: TableStyle.ink,
              foregroundColor: TableStyle.ivory,
              minimumSize: const Size(48, 48),
            ),
            onPressed: _pending ? null : () => _link(entry.$3),
            icon: Icon(entry.$2),
            label: Text(entry.$1),
          ),
          const SizedBox(height: 6),
        ],
        if (_pending)
          const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        if (_error != null)
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: TableStyle.detail.copyWith(color: TableStyle.ink),
            ),
          ),
      ],
    ),
  );
}
