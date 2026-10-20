import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/core/providers/settings_provider.dart';
import 'package:halabessa/core/services/multimedia_service.dart';
import 'package:halabessa/features/game/presentation/providers/card_feedback.dart';

class _FeedbackAudio extends ChangeNotifier implements MultimediaService {
  final played = <String>[];
  int releases = 0;
  @override
  void Function() ownCardPresentationAudio(Object owner) =>
      () => releases++;
  @override
  Future<void> playPresentationSfx(String path) async => played.add(path);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'contact feedback deduplicates, respects settings and releases ownership',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final audio = _FeedbackAudio(), haptics = <String>[];
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          multimediaServiceProvider.overrideWith((_) => audio),
        ],
      );
      final listener = container.listen(cardFeedbackProvider, (_, __) {});
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
        listener.close();
        container.dispose();
      });
      final feedback = container.read(cardFeedbackProvider);
      feedback.bind('room:1', ownsAudio: true);
      feedback.contact('play');
      feedback.contact('play');
      await tester.pump();
      expect(audio.played, ['sfx/play.mp3']);
      expect(haptics, ['HapticFeedbackType.mediumImpact']);
      await container.read(settingsProvider.notifier).toggleSound(false);
      await container.read(settingsProvider.notifier).toggleHaptics(false);
      feedback.contact('capture', slam: true);
      await tester.pump();
      expect(audio.played, hasLength(1));
      expect(haptics, hasLength(1));
      feedback.bind('room:2', ownsAudio: true);
      expect(audio.releases, 1);
      feedback.dispose();
      feedback.contact('never');
      feedback.pick();
      await tester.pump();
      expect(audio.releases, 2);
      expect(audio.played, hasLength(1));
    },
  );

  testWidgets('queued haptics are cancelled by room change and backgrounding', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final audio = _FeedbackAudio(), haptics = <String>[];
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        multimediaServiceProvider.overrideWith((_) => audio),
      ],
    );
    final listener = container.listen(cardFeedbackProvider, (_, __) {});
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      listener.close();
      container.dispose();
    });
    final feedback = container.read(cardFeedbackProvider);
    feedback.bind('old', ownsAudio: true);
    feedback.pick();
    feedback.bind('new', ownsAudio: true);
    await tester.pump();
    expect(haptics, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    feedback.contact('background', slam: true);
    await tester.pump();
    expect(haptics, isEmpty);
    expect(audio.played, isEmpty);
  });
}
