import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/core/providers/settings_provider.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';
import 'package:halabessa/features/game/domain/providers/game_providers.dart';
import 'package:halabessa/features/game/presentation/pages/offline_practice_app.dart';
import 'package:halabessa/features/lan/presentation/lan_match_adapter.dart';
import '../tool/lan_review_fixtures.dart';

class _Audio extends ReviewLanAudio {
  final cues = <String>[];
  @override
  Future<void> playSfx(String assetPath) async {
    cues.add(assetPath);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'replica emits existing fallback cues once and skips reconnect catch-up sounds',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final connection = ReviewLanConnection(), audio = _Audio();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ...offlinePlayOverrides(
            prefs,
            AppUser(uid: connection.uid, email: '', displayName: 'Host'),
            audioFactory: (_) => audio,
            matchFactory: (ref) => LanReplicaNotifier(ref, connection),
          ),
        ],
      );
      final subscription = container.listen(matchStateProvider, (_, __) {});
      connection.table();
      expect(audio.cues, isEmpty);
      var match = Map<String, dynamic>.from(
        connection.snapshot!['match'] as Map,
      );
      void publish(Map<String, dynamic> changes) {
        match = {...match, ...changes};
        connection.publish({'match': match});
      }

      publish({
        'board': [
          ...(match['board'] as List),
          {'suit': 'hearts', 'rank': 'two'},
        ],
      });
      connection.notifyListeners();
      publish({'phase': 'capturing', 'capturingStage': 0});
      publish({'phase': 'capturing', 'capturingStage': 1});
      expect(audio.cues, ['sfx/play.mp3', 'sfx/capture.mp3']);
      connection.status = 'reconnecting';
      connection.notifyListeners();
      connection.status = 'connected';
      publish({'phase': 'playing', 'board': []});
      expect(audio.cues.length, 2);
      publish({
        'roundCount': 2,
        'handInRound': 0,
        'phase': 'preRoundCut',
        'roundsSinceLastShuffle': 0,
      });
      publish({'phase': 'dealingFasha'});
      publish({'phase': 'dealingCards', 'handInRound': 1});
      expect(audio.cues, [
        'sfx/play.mp3',
        'sfx/capture.mp3',
        'sfx/shuffle.mp3',
        'sfx/cut.mp3',
        'sfx/deal.mp3',
      ]);
      subscription.close();
      container.dispose();
      connection.dispose();
      await Future<void>.delayed(Duration.zero);
    },
  );
}
