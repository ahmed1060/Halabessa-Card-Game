import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to control the global visibility and active state of the Unity layer.
final unityLayerVisibilityProvider = StateProvider<bool>((ref) => false);

/// Provider to track if Unity has been initialized at least once globally.
final unityInitializedProvider = StateProvider<bool>((ref) => false);
