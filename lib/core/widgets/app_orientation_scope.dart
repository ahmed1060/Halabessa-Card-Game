import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';

/// Native orientation belongs to the app, never to an individual route.
Future<void> applyAppOrientation(GameOrientation orientation) async {
  // Browsers own rotation. Do not transform the canvas or rewrite tap positions.
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    return;
  }
  await SystemChrome.setPreferredOrientations(
    orientation == GameOrientation.landscape
        ? const [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]
        : const [DeviceOrientation.portraitUp],
  );
}

class AppOrientationScope extends ConsumerStatefulWidget {
  const AppOrientationScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppOrientationScope> createState() =>
      _AppOrientationScopeState();
}

class _AppOrientationScopeState extends ConsumerState<AppOrientationScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual<GameOrientation>(
      settingsProvider.select((settings) => settings.gameOrientation),
      (_, orientation) => unawaited(applyAppOrientation(orientation)),
      fireImmediately: true,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        applyAppOrientation(ref.read(settingsProvider).gameOrientation),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Route changes/unmounting must not unlock the user's saved preference.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
