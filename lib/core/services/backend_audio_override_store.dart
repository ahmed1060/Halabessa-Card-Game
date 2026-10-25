import 'audio_override_store.dart';
import 'selected_audio_defaults.dart';
import 'supabase_backend_service.dart';

typedef AudioSettingsCall =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> data);

/// Authenticated audio writes use the same verified admin as asset uploads.
/// Firestore remains the read/listener source; no admin credential is client-side.
class BackendAudioOverrideStore implements AudioOverrideStore {
  final AudioSettingsCall _call;
  BackendAudioOverrideStore({AudioSettingsCall? call})
    : _call =
          call ??
          ((data) => SupabaseBackendService.call(
            'updateAudioSetting',
            data: data,
            timeout: const Duration(seconds: 40),
          ));

  Map<String, dynamic> _slot(String id) {
    for (final path in SelectedAudioDefaults.files.keys) {
      final kind = path.startsWith('sfx/')
          ? 'sfx'
          : path == 'music/room_music.mp3'
          ? 'room_music'
          : 'music';
      if (audioDocumentId(path, kind) == id) {
        return {'assetKey': path, 'kind': kind};
      }
    }
    throw ArgumentError('Unknown audio slot');
  }

  Future<Map<String, dynamic>> _send(Map<String, dynamic> data) async {
    final result = await _call(data);
    if (result['ok'] != true) throw StateError('audio_settings_failed');
    return result;
  }

  @override
  Future<void> write(String id, Map<String, dynamic> data) async {
    final slot = _slot(id);
    final url = data['url'];
    if (url is! String ||
        url.isEmpty ||
        data.keys.any((key) => key != 'url' && key != 'assetPath') ||
        (data.containsKey('assetPath') &&
            data['assetPath'] != slot['assetKey'])) {
      throw ArgumentError('Invalid audio setting');
    }
    await _send({...slot, 'operation': 'replace', 'url': url});
  }

  @override
  Future<void> delete(String id) async {
    await _send({..._slot(id), 'operation': 'restoreBundled'});
  }

  @override
  Future<bool> copy(
    String sourceId,
    String targetId, {
    required bool backup,
    bool deleteTargetWhenMissing = false,
  }) async {
    final active = backup ? sourceId : targetId;
    final slot = _slot(active);
    if ((backup &&
            (targetId != '${active}_backup' || deleteTargetWhenMissing)) ||
        (!backup &&
            (sourceId != '${active}_backup' || !deleteTargetWhenMissing))) {
      throw ArgumentError('Invalid audio copy');
    }
    final result = await _send({
      ...slot,
      'operation': backup ? 'saveDefault' : 'restoreSaved',
    });
    if (result['copied'] is! bool) throw StateError('audio_settings_failed');
    return result['copied'] as bool;
  }
}
