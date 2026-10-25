import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/core/services/audio_override_store.dart';
import 'package:halabessa/core/services/backend_audio_override_store.dart';
import 'package:halabessa/core/services/selected_audio_defaults.dart';

void main() {
  test(
    'all 16 slots route through the authenticated backend without arbitrary paths',
    () async {
      final calls = <Map<String, dynamic>>[];
      final store = BackendAudioOverrideStore(
        call: (data) async {
          calls.add(data);
          return {'ok': true, 'copied': true};
        },
      );
      for (final path in SelectedAudioDefaults.files.keys) {
        final kind = path.startsWith('sfx/')
            ? 'sfx'
            : path.contains('room_music')
            ? 'room_music'
            : 'music';
        final id = audioDocumentId(path, kind);
        await store.write(id, {
          'url': 'https://test.invalid/existing.wav',
          if (kind == 'sfx') 'assetPath': path,
        });
        expect(calls.last, {
          'assetKey': path,
          'kind': kind,
          'operation': 'replace',
          'url': 'https://test.invalid/existing.wav',
        });
        expect(await store.copy(id, '${id}_backup', backup: true), isTrue);
        expect(calls.last, {
          'assetKey': path,
          'kind': kind,
          'operation': 'saveDefault',
        });
        expect(
          await store.copy(
            '${id}_backup',
            id,
            backup: false,
            deleteTargetWhenMissing: true,
          ),
          isTrue,
        );
        expect(calls.last, {
          'assetKey': path,
          'kind': kind,
          'operation': 'restoreSaved',
        });
        await store.delete(id);
        expect(calls.last, {
          'assetKey': path,
          'kind': kind,
          'operation': 'restoreBundled',
        });
      }
      expect(calls.length, 64);
    },
  );

  test(
    'invalid ids, cross-slot copies and arbitrary metadata are rejected before calls',
    () async {
      var calls = 0;
      final store = BackendAudioOverrideStore(
        call: (data) async {
          calls++;
          return {'ok': true, 'copied': true};
        },
      );
      const id = 'sfx_sfx_capture.mp3';
      await expectLater(
        store.write('../users/admin', {'url': 'x'}),
        throwsArgumentError,
      );
      await expectLater(store.delete('${id}_backup'), throwsArgumentError);
      for (final data in <Map<String, dynamic>>[
        {'url': ''},
        {'url': 5},
        {'url': 'x', 'isAdmin': true},
        {'url': 'x', 'assetPath': 'sfx/play.mp3'},
      ]) {
        await expectLater(store.write(id, data), throwsArgumentError);
      }
      await expectLater(
        store.copy(id, 'music_backup', backup: true),
        throwsArgumentError,
      );
      await expectLater(
        store.copy('${id}_backup', id, backup: false),
        throwsArgumentError,
      );
      await expectLater(
        store.copy(
          id,
          '${id}_backup',
          backup: true,
          deleteTargetWhenMissing: true,
        ),
        throwsArgumentError,
      );
      expect(calls, 0);
    },
  );

  test(
    'denials, malformed responses and missing backups do not report success',
    () async {
      const id = 'music';
      final denied = BackendAudioOverrideStore(
        call: (_) async => throw StateError('admin_required'),
      );
      await expectLater(denied.write(id, {'url': 'x'}), throwsStateError);
      await expectLater(denied.delete(id), throwsStateError);
      final failed = BackendAudioOverrideStore(
        call: (_) async => {'ok': false},
      );
      await expectLater(failed.delete(id), throwsStateError);
      final malformed = BackendAudioOverrideStore(
        call: (_) async => {'ok': true},
      );
      await expectLater(
        malformed.copy(id, '${id}_backup', backup: true),
        throwsStateError,
      );
      final missing = BackendAudioOverrideStore(
        call: (_) async => {'ok': true, 'copied': false},
      );
      expect(
        await missing.copy(
          '${id}_backup',
          id,
          backup: false,
          deleteTargetWhenMissing: true,
        ),
        isFalse,
      );
    },
  );

  test(
    'production notifier defaults to backend writes while retaining Firestore reads',
    () {
      final source = File(
        'lib/core/providers/global_settings_provider.dart',
      ).readAsStringSync();
      expect(source, contains('_audioStore ??= BackendAudioOverrideStore()'));
      expect(source, contains(".collection('overrides')"));
      expect(source, contains('.snapshots()'));
    },
  );
}
