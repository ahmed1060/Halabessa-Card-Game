import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/global_settings.dart';

class GlobalSettingsNotifier extends StateNotifier<GlobalSettings> {
  GlobalSettingsNotifier() : super(GlobalSettings()) {
    _listenToSettings();
  }

  void _listenToSettings() {
    // Listen to main global document (timer, score)
    FirebaseFirestore.instance
        .collection('settings')
        .doc('global')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        state = state.copyWith(
          defaultTurnTimer: snapshot.data()?['defaultTurnTimer'] as int? ?? 10,
          defaultTargetScore: snapshot.data()?['defaultTargetScore'] as int? ?? 41,
        );
      }
    });

    // Listen to overrides sub-collection (audio data and backups)
    FirebaseFirestore.instance
        .collection('settings')
        .doc('global')
        .collection('overrides')
        .snapshots()
        .listen((snapshot) {
      Map<String, String> newSfx = {};
      Map<String, String> newSfxBackups = {};
      String? newMusic;
      String? newMusicBackup;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final url = data['url'] as String?;
        final isBackup = data['isBackup'] as bool? ?? false;
        final assetPath = data['assetPath'] as String?;

        if (doc.id == 'music') {
          newMusic = url;
        } else if (doc.id == 'music_backup') {
          newMusicBackup = url;
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
      );
    }, onError: (error) {
      debugPrint('GlobalSettingsNotifier: Firestore Error: $error');
      if (error.toString().contains('permission-denied')) {
        debugPrint('GlobalSettingsNotifier: Possible Ad-blocker or Permission issue.');
      }
    });
  }

  Future<void> updateSettings(GlobalSettings newSettings) async {
    final batch = FirebaseFirestore.instance.batch();
    final mainDoc = FirebaseFirestore.instance.collection('settings').doc('global');
    final overridesColl = mainDoc.collection('overrides');
    
    // 1. Update main document
    batch.set(mainDoc, {
      'defaultTurnTimer': newSettings.defaultTurnTimer,
      'defaultTargetScore': newSettings.defaultTargetScore,
    }, SetOptions(merge: true));

    // 2. Music logic
    if (newSettings.musicOverrideUrl != null) {
       batch.set(overridesColl.doc('music'), {'url': newSettings.musicOverrideUrl});
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
    final mainDoc = FirebaseFirestore.instance.collection('settings').doc('global');
    final overridesColl = mainDoc.collection('overrides');

    if (type == 'music') {
      if (state.musicOverrideUrl != null) {
        await overridesColl.doc('music_backup').set({
          'url': state.musicOverrideUrl,
          'isBackup': true,
        });
      }
    } else {
      final url = state.sfxOverrides[assetPath];
      if (url != null) {
        final safeId = assetPath.replaceAll('/', '_');
        await overridesColl.doc('sfx_${safeId}_backup').set({
          'assetPath': assetPath,
          'url': url,
          'isBackup': true,
        });
      }
    }
  }

  Future<bool> clearOverride(String assetPath, String type) async {
    final mainDoc = FirebaseFirestore.instance.collection('settings').doc('global');
    final overridesColl = mainDoc.collection('overrides');

    if (type == 'music') {
      if (state.musicBackupUrl != null) {
        await overridesColl.doc('music').set({'url': state.musicBackupUrl});
        return true;
      } else {
        await overridesColl.doc('music').delete();
        return false;
      }
    } else {
      final safeId = assetPath.replaceAll('/', '_');
      if (state.sfxBackups.containsKey(assetPath)) {
        await overridesColl.doc('sfx_$safeId').set({
          'assetPath': assetPath,
          'url': state.sfxBackups[assetPath],
        });
        return true;
      } else {
        await overridesColl.doc('sfx_$safeId').delete();
        return false;
      }
    }
  }
}

final globalSettingsProvider = StateNotifierProvider<GlobalSettingsNotifier, GlobalSettings>((ref) {
  return GlobalSettingsNotifier();
});
