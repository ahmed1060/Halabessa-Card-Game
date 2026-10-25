import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/global_settings.dart';
import 'dart:async';
import 'native_play_provider.dart';
import '../services/audio_override_store.dart';
import '../services/backend_audio_override_store.dart';

class GlobalSettingsNotifier extends StateNotifier<GlobalSettings> {
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  AudioOverrideStore? _audioStore;
  AudioOverrideStore get _audio => _audioStore ??= BackendAudioOverrideStore();
  GlobalSettingsNotifier({
    bool listenRemote = true,
    AudioOverrideStore? audioStore,
  }) : _audioStore = audioStore,
       super(GlobalSettings()) {
    if (listenRemote) _listenToSettings();
  }

  void _listenToSettings() {
    // Listen to main global document (timer, score)
    _subscriptions.add(
      FirebaseFirestore.instance
          .collection('settings')
          .doc('global')
          .snapshots()
          .listen((snapshot) {
            if (!mounted) return;
            if (snapshot.exists && snapshot.data() != null) {
              state = state.copyWith(
                defaultTurnTimer:
                    snapshot.data()?['defaultTurnTimer'] as int? ?? 10,
                defaultTargetScore:
                    snapshot.data()?['defaultTargetScore'] as int? ?? 41,
              );
            }
          }, onError: (Object _) {}),
    );

    // Listen to overrides sub-collection (audio data and backups)
    _subscriptions.add(
      FirebaseFirestore.instance
          .collection('settings')
          .doc('global')
          .collection('overrides')
          .snapshots()
          .listen(
            (snapshot) {
              if (!mounted) return;
              Map<String, String> newSfx = {};
              Map<String, String> newSfxBackups = {};
              String? newMusic;
              String? newMusicBackup;
              String? newRoomMusic;
              String? newRoomMusicBackup;

              for (var doc in snapshot.docs) {
                final data = doc.data();
                final url = data['url'] as String?;
                final assetPath = data['assetPath'] as String?;

                if (doc.id == 'music') {
                  newMusic = url;
                } else if (doc.id == 'music_backup') {
                  newMusicBackup = url;
                } else if (doc.id == 'room_music') {
                  newRoomMusic = url;
                } else if (doc.id == 'room_music_backup') {
                  newRoomMusicBackup = url;
                } else if (doc.id.startsWith('sfx_')) {
                  if (assetPath != null && url != null) {
                    if (doc.id.endsWith('_backup')) {
                      newSfxBackups[assetPath] = url;
                    } else {
                      newSfx[assetPath] = url;
                    }
                  }
                }
              }

              state = state.copyWith(
                sfxOverrides: newSfx,
                sfxBackups: newSfxBackups,
                musicOverrideUrl: newMusic,
                musicBackupUrl: newMusicBackup,
                roomMusicOverrideUrl: newRoomMusic,
                roomMusicBackupUrl: newRoomMusicBackup,
              );
            },
            onError: (error) {
              debugPrint('GlobalSettingsNotifier: Firestore Error: $error');
              if (error.toString().contains('permission-denied')) {
                debugPrint(
                  'GlobalSettingsNotifier: Possible Ad-blocker or Permission issue.',
                );
              }
            },
          ),
    );
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  Future<void> updateSettings(GlobalSettings newSettings) async {
    final batch = FirebaseFirestore.instance.batch();
    final mainDoc = FirebaseFirestore.instance
        .collection('settings')
        .doc('global');
    final overridesColl = mainDoc.collection('overrides');

    // 1. Update main document
    batch.set(mainDoc, {
      'defaultTurnTimer': newSettings.defaultTurnTimer,
      'defaultTargetScore': newSettings.defaultTargetScore,
    }, SetOptions(merge: true));

    // 2. Music logic
    if (newSettings.musicOverrideUrl != null) {
      batch.set(overridesColl.doc('music'), {
        'url': newSettings.musicOverrideUrl,
      });
    }
    if (newSettings.roomMusicOverrideUrl != null) {
      batch.set(overridesColl.doc('room_music'), {
        'url': newSettings.roomMusicOverrideUrl,
      });
    }

    // 3. SFX logic
    for (var entry in newSettings.sfxOverrides.entries) {
      final assetPath = entry.key;
      final url = entry.value;
      final safeId = assetPath.replaceAll('/', '_');

      batch.set(overridesColl.doc('sfx_$safeId'), {
        'assetPath': assetPath,
        'url': url,
      });
    }

    await batch.commit();
  }

  Future<void> markAsDefault(String assetPath, String type) async {
    final id = audioDocumentId(assetPath, type);
    final copied = await _audio.copy(id, '${id}_backup', backup: true);
    if (!copied) throw StateError('audio_override_missing');
  }

  /// Save only the changed sound, never match settings or other overrides.
  Future<void> updateAudioOverride(
    String assetPath,
    String type,
    String url,
  ) async {
    final id = audioDocumentId(assetPath, type);
    if (url.isEmpty) throw ArgumentError('Empty audio URL');
    await _audio.write(id, {
      'url': url,
      if (type == 'sfx') 'assetPath': assetPath,
    });
  }

  /// Independent of saved remote backups: selected bundled files never change.
  Future<void> restoreBundledAudio(String assetPath, String type) =>
      _audio.delete(audioDocumentId(assetPath, type));

  Future<bool> clearOverride(String assetPath, String type) {
    final id = audioDocumentId(assetPath, type);
    return _audio.copy(
      '${id}_backup',
      id,
      backup: false,
      deleteTargetWhenMissing: true,
    );
  }
}

final globalSettingsProvider =
    StateNotifierProvider<GlobalSettingsNotifier, GlobalSettings>((ref) {
      final online = ref.watch(nativeOnlineEnabledProvider);
      return GlobalSettingsNotifier(listenRemote: !isNativeMobile || online);
    });
