// Read-only review of the real screens with local fakes. Never initializes cloud
// services, opens a file picker, uploads, saves or deletes a live setting.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:halabessa/core/services/admin_audio_upload_service.dart';
import 'package:halabessa/core/models/global_settings.dart';
import 'package:halabessa/core/providers/global_settings_provider.dart';
import 'package:halabessa/core/services/default_audio_assets.dart';
import 'package:halabessa/core/services/admin_audio_preview_service.dart';
import 'package:halabessa/core/providers/settings_provider.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import 'package:halabessa/features/home/presentation/pages/admin_sfx_management_screen.dart';
import 'package:halabessa/features/home/presentation/pages/admin_music_management_screen.dart';

class _Settings extends GlobalSettingsNotifier {
  final restored = <String>[];
  _Settings(GlobalSettings fixture) : super(listenRemote: false) {
    state = fixture;
  }
  @override
  Future<void> updateSettings(GlobalSettings value) async =>
      throw StateError('Review cannot save');
  @override
  Future<void> markAsDefault(String path, String type) async =>
      throw StateError('Review cannot save');
  @override
  Future<bool> clearOverride(String path, String type) async =>
      throw StateError('Review cannot reset');
  @override
  Future<void> restoreBundledAudio(String path, String type) async {
    restored.add(path);
    state = state.copyWith(sfxOverrides: {...state.sfxOverrides}..remove(path));
  }
}

class _Audio extends ChangeNotifier implements AdminAudioPreviewService {
  final played = <String>[];
  @override
  String? activePath;
  @override
  bool isPlaying = false;
  @override
  Future<void> play(
    String path, {
    String? overrideUrl,
    required double volume,
  }) async {
    played.add(path);
    activePath = path;
    isPlaying = true;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    activePath = null;
    isPlaying = false;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Translations extends AssetLoader {
  final Map<String, dynamic> data;
  const _Translations(this.data);
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => data;
}

void main() {
  final observations = <Map<String, Object>>[];
  late Map<String, dynamic> en, ar;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    en =
        jsonDecode(File('assets/translations/en-US.json').readAsStringSync())
            as Map<String, dynamic>;
    ar =
        jsonDecode(File('assets/translations/ar-EG.json').readAsStringSync())
            as Map<String, dynamic>;
  });
  tearDownAll(() {
    final file = File(
      'build/selected-audio-review-2026-10-24/ui-observations.json',
    );
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(observations),
    );
  });

  Future<(ProviderContainer, _Audio, GlobalKey)> mount(
    WidgetTester tester, {
    bool music = false,
    bool arabic = false,
    bool custom = false,
    AdminAudioUploadService? upload,
    FilePickerResult? pickedFile,
    Size size = const Size(390, 844),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final audio = _Audio(), key = GlobalKey();
    final fixture = GlobalSettings(
      sfxOverrides: custom
          ? {
              'sfx/capture.mp3': 'https://example.invalid/current.wav',
              'sfx/deal.mp3': 'https://example.invalid/deal.wav',
            }
          : {},
      sfxBackups: custom
          ? {'sfx/capture.mp3': 'https://example.invalid/current.wav'}
          : {},
    );
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        globalSettingsProvider.overrideWith((ref) => _Settings(fixture)),
        adminAudioPreviewProvider.overrideWith((ref) => audio),
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (upload != null) adminAudioUploadProvider.overrideWithValue(upload),
        adminAudioFilePickerProvider.overrideWithValue(() async => pickedFile),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      final font = FontLoader('LanternText')
        ..addFont(rootBundle.load('assets/fonts/Cairo.ttf'));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: EasyLocalization(
          supportedLocales: const [Locale('en', 'US'), Locale('ar', 'EG')],
          path: 'assets/translations',
          startLocale: arabic
              ? const Locale('ar', 'EG')
              : const Locale('en', 'US'),
          saveLocale: false,
          assetLoader: _Translations(arabic ? ar : en),
          child: Builder(
            builder: (context) => MaterialApp(
              theme: ThemeConfig.darkTheme,
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: RepaintBoundary(
                key: key,
                child: music
                    ? const AdminMusicManagementScreen()
                    : const AdminSfxManagementScreen(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (container, audio, key);
  }

  for (final example in [
    ('admin-sfx-en-empty', false, false, false, const Size(390, 844)),
    ('admin-sfx-ar-custom', false, true, true, const Size(390, 844)),
    ('admin-music-en-empty', true, false, false, const Size(390, 844)),
    ('admin-sfx-ar-narrow', false, true, true, const Size(320, 640)),
    ('admin-sfx-en-landscape', false, false, true, const Size(844, 390)),
    ('admin-music-ar-narrow', true, true, false, const Size(320, 640)),
  ]) {
    testWidgets('render existing ${example.$1} without cloud access', (
      tester,
    ) async {
      final issues = <String>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) =>
          issues.add(details.exceptionAsString());
      late GlobalKey key;
      try {
        final result = await mount(
          tester,
          music: example.$2,
          arabic: example.$3,
          custom: example.$4,
          size: example.$5,
        );
        key = result.$3;
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/selected-audio-review-2026-10-24/${example.$1}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        observations.add({
          'fixture': example.$1,
          'viewport': '${example.$5.width}x${example.$5.height}',
          'layoutIssues': issues,
        });
        expect(
          issues,
          isEmpty,
          reason: 'Selected audio controls must fit in English and Arabic',
        );
      } finally {
        FlutterError.onError = oldHandler;
      }
    });
  }
  testWidgets(
    'shows selected bundled defaults instead of a false no-sound status',
    (tester) async {
      await mount(tester);
      expect(DefaultAudioAssets.getSfx('sfx/capture.mp3'), isNotNull);
      expect(find.text(en['no_sound_set']! as String), findsNothing);
      expect(find.text(en['audio_selected_default']! as String), findsWidgets);
    },
  );
  testWidgets(
    'only the active preview row shows Stop; another row replaces it',
    (tester) async {
      final (_, audio, _) = await mount(tester);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded).first);
      await tester.pump();
      expect(audio.played, ['sfx/capture.mp3']);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded).first);
      await tester.pump();
      expect(audio.played, ['sfx/capture.mp3', 'sfx/deal.mp3']);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    },
  );
  testWidgets('explicit bundled restore bypasses the saved remote URL', (
    tester,
  ) async {
    final (container, _, _) = await mount(tester, custom: true);
    await tester.tap(find.byIcon(Icons.settings_backup_restore_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(en['audio_restore_selected']! as String));
    await tester.pumpAndSettle();
    final settings =
        container.read(globalSettingsProvider.notifier) as _Settings;
    expect(settings.restored, ['sfx/capture.mp3']);
    expect(
      container
          .read(globalSettingsProvider)
          .sfxOverrides
          .containsKey('sfx/capture.mp3'),
      isFalse,
    );
  });
  for (final example in [
    (false, 0, 'sfx/capture.mp3', 'sfx'),
    (true, 0, 'music/bg_music.mp3', 'music'),
    (true, 1, 'music/room_music.mp3', 'room_music'),
  ]) {
    testWidgets(
      'real upload control routes ${example.$3} through storage then field-only save',
      (tester) async {
        final calls = <String>[];
        final data = File(
          'assets/audio/defaults/2026-10-24/play-d-b2250eaa.wav',
        ).readAsBytesSync();
        final upload = AdminAudioUploadService(
          upload:
              ({
                required kind,
                required fileName,
                required contentType,
                required bytes,
                assetKey,
              }) async {
                calls.add('upload:$kind:$assetKey');
                expect(contentType, 'audio/wav');
                expect(bytes, data);
                return 'https://storage.invalid/versioned.wav';
              },
          save: (path, type, url) async {
            calls.add('save:$type:$path');
            expect(url, 'https://storage.invalid/versioned.wav');
          },
        );
        await mount(
          tester,
          music: example.$1,
          upload: upload,
          pickedFile: FilePickerResult([
            PlatformFile(name: 'custom.wav', size: data.length, bytes: data),
          ]),
        );
        await tester.tap(
          find.byTooltip(en['audio_replace'] as String).at(example.$2),
        );
        await tester.pumpAndSettle();
        expect(calls, [
          'upload:${example.$4 == 'sfx' ? 'sfx' : 'music'}:${example.$3}',
          'save:${example.$4}:${example.$3}',
        ]);
        expect(find.text(en['upload_success'] as String), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('failed upload shows an error and never saves an override', (
    tester,
  ) async {
    var saves = 0;
    final data = File(
      'assets/audio/defaults/2026-10-24/play-d-b2250eaa.wav',
    ).readAsBytesSync();
    final upload = AdminAudioUploadService(
      upload:
          ({
            required kind,
            required fileName,
            required contentType,
            required bytes,
            assetKey,
          }) async => throw StateError('storage unavailable'),
      save: (a, b, c) async {
        saves++;
      },
    );
    await mount(
      tester,
      upload: upload,
      pickedFile: FilePickerResult([
        PlatformFile(name: 'custom.wav', size: data.length, bytes: data),
      ]),
    );
    await tester.tap(find.byTooltip(en['audio_replace'] as String).first);
    await tester.pumpAndSettle();
    expect(saves, 0);
    expect(find.text(en['upload_success'] as String), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
  test('nullable settings clear an override received in a null snapshot', () {
    final old = GlobalSettings(
      musicOverrideUrl: 'https://example.invalid/old.wav',
    );
    expect(old.copyWith(musicOverrideUrl: null).musicOverrideUrl, isNull);
  });
}
