import 'dart:io';
import 'dart:convert';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _DiskBundle extends CachingAssetBundle {
  final Directory directory;
  _DiskBundle(this.directory);
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(await File('${directory.path}/$key').readAsBytes());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'fingerprinted manifest is decoded and resolved by the actual Flutter SDK',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'halabessa-art-codec-',
      );
      try {
        const logical = 'assets/images/حلبسه.png';
        const retina = 'assets/images/2.0x/حلبسه.png';
        final assets = Directory('${directory.path}/assets');
        await Directory(
          '${assets.path}/assets/images/2.0x',
        ).create(recursive: true);
        final original = const StandardMessageCodec().encodeMessage({
          logical: [
            {'asset': logical},
            {'asset': retina, 'dpr': 2.0},
          ],
        })!;
        await File('${assets.path}/AssetManifest.bin').writeAsBytes(
          original.buffer.asUint8List(
            original.offsetInBytes,
            original.lengthInBytes,
          ),
        );
        await File('${assets.path}/$logical').writeAsString('image bytes');
        await File('${assets.path}/$retina').writeAsString('retina bytes');
        final script = File('scripts/fingerprint-web-artwork.mjs').absolute.uri;
        final result = await Process.run('node', [
          '--input-type=module',
          '-e',
          'import {fingerprintWebArtwork} from ${jsonEncode(script.toString())}; '
              'await fingerprintWebArtwork(process.argv[1]);',
          directory.path,
        ]);
        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        final decoded =
            const StandardMessageCodec().decodeMessage(
                  ByteData.sublistView(
                    await File(
                      '${assets.path}/AssetManifest.bin',
                    ).readAsBytes(),
                  ),
                )
                as Map;
        expect((decoded[logical] as List)[1]['dpr'], 2.0);
        final bundle = _DiskBundle(assets);
        final manifest = await AssetManifest.loadFromAssetBundle(bundle);
        expect(manifest.listAssets(), [logical]);
        final selected = await AssetImage(
          logical,
          bundle: bundle,
        ).obtainKey(ImageConfiguration(bundle: bundle, devicePixelRatio: 2));
        expect(
          selected.name,
          matches(r'^_immutable/[a-f0-9]{64}/assets/images/2.0x/'),
        );
        expect(selected.scale, 2.0);
        expect(
          await File('${assets.path}/${selected.name}').readAsString(),
          'retina bytes',
        );
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}
