import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/core/services/default_audio_assets.dart';

void main() {
  test('interaction sound slots have labels in each supported locale', () {
    final admin = File(
      'lib/features/home/presentation/pages/admin_sfx_management_screen.dart',
    ).readAsStringSync();
    for (final locale in ['ar-EG', 'ar-SA', 'en-US']) {
      final labels =
          jsonDecode(
                File('assets/translations/$locale.json').readAsStringSync(),
              )
              as Map;
      for (final name in [
        'pick',
        'return',
        'reveal',
        'slam_0',
        'slam_1',
        'slam_2',
      ]) {
        expect(labels['${name}_sfx'], isA<String>());
        expect(admin, contains("'path': 'sfx/$name.mp3'"));
      }
    }
  });
  test(
    'all new interaction sounds have small, valid cached local WAV fallbacks',
    () {
      final variants = <String>[];
      for (final name in [
        'pick',
        'return',
        'reveal',
        'slam_0',
        'slam_1',
        'slam_2',
      ]) {
        final path = 'sfx/$name.mp3',
            sound = DefaultAudioAssets.getSfx('sfx/$name.mp3');
        expect(sound, startsWith('data:audio/wav;base64,'));
        expect(DefaultAudioAssets.getSfx(path), same(sound));
        final bytes = base64Decode(sound!.split(',').last);
        expect(ascii.decode(bytes.take(4).toList()), 'RIFF');
        expect(
          ByteData.sublistView(bytes).getUint32(40, Endian.little),
          bytes.length - 44,
        );
        expect(bytes.length, lessThan(7000));
        if (name.startsWith('slam')) variants.add(sound);
      }
      expect(variants.toSet(), hasLength(3));
    },
  );
}
