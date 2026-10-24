import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'default_audio_assets.dart';
import 'selected_audio_defaults.dart';

/// Existing logical keys, custom first, then the exact auditioned bundled file.
/// No remote settings are read here; offline callers explicitly disallow them.
class GameAudioSources {
  static Source? resolve(
    String path, {
    String? overrideUrl,
    bool allowRemote = true,
  }) {
    if (allowRemote && overrideUrl != null && overrideUrl.isNotEmpty) {
      return UrlSource(overrideUrl);
    }
    if (const bool.fromEnvironment(
      'HALABESSA_SELECTED_AUDIO_DEFAULTS',
      defaultValue: true,
    )) {
      final selected = SelectedAudioDefaults.files[path];
      if (selected != null) return AssetSource(selected, mimeType: 'audio/wav');
    }
    final data = path.startsWith('music/')
        ? DefaultAudioAssets.getMusic()
        : DefaultAudioAssets.getSfx(path);
    if (data == null) return null;
    return kIsWeb
        ? UrlSource(data)
        : BytesSource(
            base64Decode(data.split(',').last),
            mimeType: 'audio/wav',
          );
  }
}
