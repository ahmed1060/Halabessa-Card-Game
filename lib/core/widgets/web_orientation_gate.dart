import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../../features/game/presentation/widgets/table_style.dart';

final mobileWebOrientationGateProvider = Provider<bool>(
  (ref) =>
      kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS),
);

bool orientationMismatch(GameOrientation preferred, Size size) =>
    !size.isEmpty &&
    (size.width > size.height) != (preferred == GameOrientation.landscape);

/// Above the Navigator and native renderer: not a dismissible dialog/route.
/// Never transforms the canvas, pauses networking, or changes a turn deadline.
class WebOrientationGate extends ConsumerWidget {
  const WebOrientationGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(mobileWebOrientationGateProvider)) return child;
    final preferred = ref.watch(
      settingsProvider.select((s) => s.gameOrientation),
    );
    final media = MediaQuery.of(context);
    // This root builder is above Scaffold's keyboard-resized body. MediaQuery
    // size already describes the full view; adding insets would double-count
    // the keyboard and can incorrectly block a landscape phone.
    final blocked = orientationMismatch(preferred, media.size);
    final landscape = preferred == GameOrientation.landscape;
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          excluding: blocked,
          child: ExcludeFocus(
            excluding: blocked,
            child: AbsorbPointer(absorbing: blocked, child: child),
          ),
        ),
        if (blocked)
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: BlockSemantics(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: const ModalBarrier(
                        key: ValueKey('web-orientation-barrier'),
                        dismissible: false,
                        color: Color(0xAD192638),
                      ),
                    ),
                    SafeArea(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Semantics(
                            liveRegion: true,
                            child: Column(
                              key: const ValueKey('web-orientation-blocker'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.screen_rotation_rounded,
                                  size: 68,
                                  color: TableStyle.brass,
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  (landscape
                                          ? 'rotate_landscape_title'
                                          : 'rotate_portrait_title')
                                      .tr(),
                                  textAlign: TextAlign.center,
                                  style: TableStyle.label.copyWith(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'rotate_continue_detail'.tr(),
                                  textAlign: TextAlign.center,
                                  style: TableStyle.label.copyWith(
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'rotate_online_notice'.tr(),
                                  textAlign: TextAlign.center,
                                  style: TableStyle.detail,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
