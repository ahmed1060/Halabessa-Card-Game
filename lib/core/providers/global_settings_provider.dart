import 'package:cloud_firestore/cloud_firestore.dart';
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

    // Listen to overrides sub-collection (audio data)
    FirebaseFirestore.instance
        .collection('settings')
        .doc('global')
        .collection('overrides')
        .snapshots()
        .listen((snapshot) {
      Map<String, String> newSfx = {};
      String? newMusic;

      for (var doc in snapshot.docs) {
        if (doc.id == 'music') {
          newMusic = doc.data()['url'] as String?;
        } else if (doc.id.startsWith('sfx_')) {
          final assetPath = doc.data()['assetPath'] as String;
          newSfx[assetPath] = doc.data()['url'] as String;
        }
      }

      state = state.copyWith(
        sfxOverrides: newSfx,
        musicOverrideUrl: newMusic,
      );
    });
  }

  Future<void> updateSettings(GlobalSettings newSettings) async {
    final batch = FirebaseFirestore.instance.batch();
    
    // 1. Update main document (minimal data)
    final mainDoc = FirebaseFirestore.instance.collection('settings').doc('global');
    batch.set(mainDoc, {
      'defaultTurnTimer': newSettings.defaultTurnTimer,
      'defaultTargetScore': newSettings.defaultTargetScore,
    }, SetOptions(merge: true));

    // 2. Update Music override in its own document
    if (newSettings.musicOverrideUrl != null) {
       final musicDoc = mainDoc.collection('overrides').doc('music');
       batch.set(musicDoc, {'url': newSettings.musicOverrideUrl});
    }

    // 3. Update SFX overrides (each in its own document)
    for (var entry in newSettings.sfxOverrides.entries) {
      final sfxId = 'sfx_${entry.key.replaceAll('/', '_')}';
      final sfxDoc = mainDoc.collection('overrides').doc(sfxId);
      batch.set(sfxDoc, {
        'assetPath': entry.key,
        'url': entry.value,
      });
    }

    await batch.commit();
  }
}

final globalSettingsProvider = StateNotifierProvider<GlobalSettingsNotifier, GlobalSettings>((ref) {
  return GlobalSettingsNotifier();
});
