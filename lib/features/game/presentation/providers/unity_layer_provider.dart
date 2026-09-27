import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to control the global visibility and active state of the Unity layer.
final unityLayerVisibilityProvider = StateProvider<bool>((ref) => false);

/// Provider to track if Unity has been initialized at least once globally.
final unityInitializedProvider = StateProvider<bool>((ref) => false);

/// A failed engine stays hidden for this app session, including late messages.
final unityFailedProvider = StateProvider<bool>((ref) => false);

final unityLayerActiveProvider = Provider<bool>((ref) =>
    ref.watch(unityLayerVisibilityProvider) &&
    ref.watch(unityInitializedProvider) &&
    !ref.watch(unityFailedProvider));
