import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool get isNativeMobile =>
    !kIsWeb &&
    [
      TargetPlatform.android,
      TargetPlatform.iOS,
    ].contains(defaultTargetPlatform);

// Native launch does not instantiate cloud clients until Online is chosen.
final nativeOnlineEnabledProvider = StateProvider<bool>((ref) => false);

// Overridden only inside the isolated local-play navigator, never persisted as
// an online identity and never accepted by cloud services.
final offlineSessionProvider = Provider<bool>((ref) => false);
