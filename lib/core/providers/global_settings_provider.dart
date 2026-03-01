import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/global_settings.dart';

class GlobalSettingsNotifier extends StateNotifier<GlobalSettings> {
  GlobalSettingsNotifier() : super(GlobalSettings()) {
    _listenToSettings();
  }

  void _listenToSettings() {
    FirebaseFirestore.instance
        .collection('settings')
        .doc('global')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        state = GlobalSettings.fromJson(snapshot.data()!);
      }
    });
  }

  Future<void> updateSettings(GlobalSettings newSettings) async {
    await FirebaseFirestore.instance
        .collection('settings')
        .doc('global')
        .set(newSettings.toJson(), SetOptions(merge: true));
  }
}

final globalSettingsProvider = StateNotifierProvider<GlobalSettingsNotifier, GlobalSettings>((ref) {
  return GlobalSettingsNotifier();
});
