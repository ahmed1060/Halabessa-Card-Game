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
  int deckReleases = 0;
  @override
  void Function() ownDeckPresentationAudio(Object owner) =>
      () => deckReleases++;
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
    'hold pulses have no sound and stop with haptics disabled or app paused',
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
          if (call.method == 'HapticFeedback.vibrate')
            haptics.add(call.arguments as String);
          return null;
        },
      );
      addTearDown(() {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
        listener.close();
        container.dispose();
      });
      final feedback = container.read(cardFeedbackProvider)
        ..bind('hold-room', ownsAudio: true);
      feedback.holdPulse();
      await tester.pump();
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      expect(audio.played, isEmpty);
      await container.read(settingsProvider.notifier).toggleHaptics(false);
      feedback.holdPulse();
      await tester.pump();
      expect(haptics, hasLength(1));
      await container.read(settingsProvider.notifier).toggleHaptics(true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      feedback.holdPulse();
      await tester.pump();
      expect(haptics, hasLength(1));
      expect(audio.played, isEmpty);
    },
  );
  testWidgets(
    'deck sensory scope is independent, deduplicated and obeys mute',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final audio = _FeedbackAudio();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          multimediaServiceProvider.overrideWith((_) => audio),
        ],
      );
      final listener = container.listen(cardFeedbackProvider, (_, __) {});
      addTearDown(() {
        listener.close();
        container.dispose();
      });
      final feedback = container.read(cardFeedbackProvider);
      feedback.bind('deck-room:1', ownsAudio: false, ownsDeckAudio: true);
      feedback.deckAction('shuffle:mix1', 'shuffleMix');
      feedback.deckAction('shuffle:mix1', 'shuffleMix');
      feedback.deckAction('shuffle:mix2', 'shuffleMix');
      feedback.deckAction('shuffle:settle', 'shuffleContact');
      await tester.pump();
      expect(audio.played, [
        'sfx/shuffle.mp3',
        'sfx/shuffle.mp3',
        'sfx/cut.mp3',
      ]);
      expect(audio.releases, 0);
      await container.read(settingsProvider.notifier).toggleSound(false);
      feedback.deckAction('cut:separate', 'cutSeparate');
      feedback.deckAction('cut:contact', 'cutContact');
      await tester.pump();
      expect(audio.played, hasLength(3));
      feedback.dispose();
      expect(audio.deckReleases, 1);
    },
  );
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
    // Pick audio is immediate; stale deferred haptics are still cancelled.
    expect(audio.played, ['sfx/pick.mp3']);
    audio.played.clear();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    feedback.contact('background', slam: true);
    await tester.pump();
    expect(haptics, isEmpty);
    expect(audio.played, isEmpty);
  });

  testWidgets(
    'reveal and gesture slam are distinct, deduplicated, and obey mute',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final audio = _FeedbackAudio();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          multimediaServiceProvider.overrideWith((_) => audio),
        ],
      );
      final listener = container.listen(cardFeedbackProvider, (_, __) {});
      addTearDown(() {
        listener.close();
        container.dispose();
      });
      final feedback = container.read(cardFeedbackProvider)
        ..bind('room:1', ownsAudio: true);
      feedback.reveal('show:1');
      feedback.reveal('show:1');
      feedback.gestureSlam('slam:1');
      feedback.gestureSlam('slam:1');
      await tester.pump();
      expect(audio.played, hasLength(2));
      expect(audio.played.first, 'sfx/reveal.mp3');
      expect(audio.played.last, matches(RegExp(r'^sfx/slam_[0-2]\.mp3$')));
      expect(audio.played, isNot(contains('sfx/capture.mp3')));
      await container.read(settingsProvider.notifier).toggleSound(false);
      feedback.reveal('show:2');
      feedback.gestureSlam('slam:2');
      await tester.pump();
      expect(audio.played, hasLength(2));
    },
  );
}
