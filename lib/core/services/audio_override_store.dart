import 'package:cloud_firestore/cloud_firestore.dart';
import 'selected_audio_defaults.dart';

String audioDocumentId(String path, String type) {
  if (!SelectedAudioDefaults.files.containsKey(path)) {
    throw ArgumentError('Unknown audio slot');
  }
  if (type == 'music' && path == 'music/bg_music.mp3') return 'music';
  if (type == 'room_music' && path == 'music/room_music.mp3') {
    return 'room_music';
  }
  if (type == 'sfx' && path.startsWith('sfx/')) {
    return 'sfx_${path.replaceAll('/', '_')}';
  }
  throw ArgumentError('Audio type does not match slot');
}

abstract class AudioOverrideStore {
  Future<void> write(String id, Map<String, dynamic> data);
  Future<void> delete(String id);

  /// Atomically copy the committed URL/metadata; optionally reset a missing backup.
  Future<bool> copy(
    String sourceId,
    String targetId, {
    required bool backup,
    bool deleteTargetWhenMissing = false,
  });
}

class FirestoreAudioOverrideStore implements AudioOverrideStore {
  final FirebaseFirestore _firestore;
  FirestoreAudioOverrideStore({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _overrides =>
      _firestore.collection('settings').doc('global').collection('overrides');
  @override
  Future<void> write(String id, Map<String, dynamic> data) =>
      _overrides.doc(id).set(data);
  @override
  Future<void> delete(String id) => _overrides.doc(id).delete();
  @override
  Future<bool> copy(
    String sourceId,
    String targetId, {
    required bool backup,
    bool deleteTargetWhenMissing = false,
  }) => _firestore.runTransaction((transaction) async {
    final source = await transaction.get(_overrides.doc(sourceId));
    final data = source.data();
    final url = data?['url'];
    if (url is! String || url.isEmpty) {
      if (deleteTargetWhenMissing) transaction.delete(_overrides.doc(targetId));
      return false;
    }
    transaction.set(_overrides.doc(targetId), {...data!, 'isBackup': backup});
    return true;
  });
}
