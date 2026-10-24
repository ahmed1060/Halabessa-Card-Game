import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/core/models/global_settings.dart';
import 'package:halabessa/core/providers/global_settings_provider.dart';
import 'package:halabessa/core/services/admin_audio_upload_service.dart';
import 'package:halabessa/core/services/audio_override_store.dart';

class _Store implements AudioOverrideStore {
  final documents = <String, Map<String, dynamic>>{};
  final writes = <String>[];
  bool reject = false;
  @override
  Future<void> write(String id, Map<String, dynamic> data) async {
    if (reject) throw StateError('permission-denied');
    writes.add(id);
    documents[id] = {...data};
  }

  @override
  Future<void> delete(String id) async {
    if (reject) throw StateError('permission-denied');
    writes.add(id);
    documents.remove(id);
  }

  @override
  Future<bool> copy(
    String sourceId,
    String targetId, {
    required bool backup,
    bool deleteTargetWhenMissing = false,
  }) async {
    if (reject) throw StateError('permission-denied');
    final source = documents[sourceId];
    if (source?['url'] is! String || (source!['url'] as String).isEmpty) {
      if (deleteTargetWhenMissing) await delete(targetId);
      return false;
    }
    await write(targetId, {...source, 'isBackup': backup});
    return true;
  }
}

class _Settings extends GlobalSettingsNotifier {
  _Settings(_Store store) : super(listenRemote: false, audioStore: store) {
    // Intentionally stale screen state must never choose the backup URL.
    state = GlobalSettings(
      musicOverrideUrl: 'old-ui',
      roomMusicOverrideUrl: 'old-room',
      defaultTurnTimer: 15,
      defaultTargetScore: 61,
    );
  }
}

void main() {
  for (final slot in [
    ('sfx/play.mp3', 'sfx'),
    ('music/bg_music.mp3', 'music'),
    ('music/room_music.mp3', 'room_music'),
  ]) {
    test(
      'replace/save/restore/bundled reset changes only ${slot.$1}',
      () async {
        final store = _Store();
        final notifier = _Settings(store);
        addTearDown(notifier.dispose);
        store.documents['unrelated'] = {'url': 'keep'};
        final id = audioDocumentId(slot.$1, slot.$2);
        await notifier.updateAudioOverride(
          slot.$1,
          slot.$2,
          'https://local.invalid/A.wav',
        );
        await notifier.markAsDefault(slot.$1, slot.$2);
        expect(
          store.documents['${id}_backup']!['url'],
          'https://local.invalid/A.wav',
        );
        await notifier.updateAudioOverride(
          slot.$1,
          slot.$2,
          'https://local.invalid/B.wav',
        );
        expect(await notifier.clearOverride(slot.$1, slot.$2), isTrue);
        expect(store.documents[id]!['url'], 'https://local.invalid/A.wav');
        expect(store.documents[id]!['isBackup'], isFalse);
        await notifier.restoreBundledAudio(slot.$1, slot.$2);
        expect(store.documents.containsKey(id), isFalse);
        expect(
          store.documents['${id}_backup']!['url'],
          'https://local.invalid/A.wav',
        );
        expect(store.documents['unrelated'], {'url': 'keep'});
        expect(
          store.writes.every((key) => key == id || key == '${id}_backup'),
          isTrue,
        );
      },
    );
  }
  test(
    'missing override never replaces a saved default; missing backup removes only override',
    () async {
      final store = _Store();
      final notifier = _Settings(store);
      addTearDown(notifier.dispose);
      const id = 'music';
      store.documents['music_backup'] = {'url': 'saved'};
      await expectLater(
        notifier.markAsDefault('music/bg_music.mp3', 'music'),
        throwsStateError,
      );
      expect(store.documents['music_backup']!['url'], 'saved');
      store.documents.remove('music_backup');
      store.documents[id] = {'url': 'current'};
      expect(
        await notifier.clearOverride('music/bg_music.mp3', 'music'),
        isFalse,
      );
      expect(store.documents.containsKey(id), isFalse);
    },
  );
  test(
    'upload failure does not publish; settings failure does not overwrite old selection',
    () async {
      final store = _Store();
      final notifier = _Settings(store);
      addTearDown(notifier.dispose);
      const path = 'sfx/play.mp3';
      final id = audioDocumentId(path, 'sfx');
      store.documents[id] = {'url': 'saved-before'};
      final flow = AdminAudioUploadService(
        upload:
            ({
              required kind,
              required fileName,
              required contentType,
              required bytes,
              assetKey,
            }) async => throw StateError('storage failed'),
        save: notifier.updateAudioOverride,
      );
      final bytes = Uint8List.fromList([1, 2, 3]);
      await expectLater(
        flow.replace(
          path: path,
          type: 'sfx',
          fileName: 'clip.wav',
          contentType: 'audio/wav',
          bytes: bytes,
        ),
        throwsStateError,
      );
      expect(store.writes, isEmpty);
      expect(store.documents[id]!['url'], 'saved-before');
      final successful = AdminAudioUploadService(
        upload:
            ({
              required kind,
              required fileName,
              required contentType,
              required bytes,
              assetKey,
            }) async => 'new-immutable-file',
        save: notifier.updateAudioOverride,
      );
      store.reject = true;
      await expectLater(
        successful.replace(
          path: path,
          type: 'sfx',
          fileName: 'clip.wav',
          contentType: 'audio/wav',
          bytes: bytes,
        ),
        throwsStateError,
      );
      expect(store.documents[id]!['url'], 'saved-before');
      store.reject = false;
      await successful.replace(
        path: path,
        type: 'sfx',
        fileName: 'clip.wav',
        contentType: 'audio/wav',
        bytes: bytes,
      );
      expect(store.documents[id]!['url'], 'new-immutable-file');
    },
  );
  test(
    'invalid slot/type/data is rejected before storage or config writes',
    () async {
      var calls = 0;
      final flow = AdminAudioUploadService(
        upload:
            ({
              required kind,
              required fileName,
              required contentType,
              required bytes,
              assetKey,
            }) async {
              calls++;
              return 'url';
            },
        save: (a, b, c) async {
          calls++;
        },
      );
      for (final arguments in [
        ('sfx/unknown.mp3', 'sfx', 'audio/wav', Uint8List(1)),
        ('sfx/play.mp3', 'music', 'audio/wav', Uint8List(1)),
        ('sfx/play.mp3', 'sfx', 'image/png', Uint8List(1)),
        ('sfx/play.mp3', 'sfx', 'audio/wav', Uint8List(0)),
        ('sfx/play.mp3', 'sfx', 'audio/wav', Uint8List(4 * 1024 * 1024 + 1)),
      ]) {
        await expectLater(
          flow.replace(
            path: arguments.$1,
            type: arguments.$2,
            fileName: 'clip.wav',
            contentType: arguments.$3,
            bytes: arguments.$4,
          ),
          throwsArgumentError,
        );
      }
      expect(calls, 0);
    },
  );
}
