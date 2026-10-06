import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/core/providers/settings_provider.dart';

void main() {
  test(
    'presentation reset preserves account, inventory and room preferences',
    () async {
      SharedPreferences.setMockInitialValues({
        'isMusicEnabled': false,
        'reducedMotion': true,
        'gameOrientation': 'portrait',
        'languageCode': 'ar',
        'authToken': 'unchanged',
        'ownedItems': ['default_card', 'deck'],
        'activeRoomId': 'unchanged-room',
      });
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsNotifier(prefs);
      await settings.resetPresentationDefaults();
      expect(settings.state.isMusicEnabled, isTrue);
      expect(settings.state.reducedMotion, isFalse);
      expect(settings.state.gameOrientation, GameOrientation.landscape);
      expect(settings.state.languageCode, 'en');
      expect(prefs.getString('authToken'), 'unchanged');
      expect(prefs.getStringList('ownedItems'), ['default_card', 'deck']);
      expect(prefs.getString('activeRoomId'), 'unchanged-room');
      settings.dispose();
    },
  );
  test(
    'game orientation defaults to landscape and persists portrait',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsNotifier(prefs);
      expect(settings.state.gameOrientation, GameOrientation.landscape);
      await settings.setGameOrientation(GameOrientation.portrait);
      final restored = SettingsNotifier(prefs);
      expect(restored.state.gameOrientation, GameOrientation.portrait);
      await restored.setGameOrientation(GameOrientation.landscape);
      expect(prefs.getString('gameOrientation'), 'landscape');
      settings.dispose();
      restored.dispose();
    },
  );
  test('reduced motion persists without changing audio or haptics', () async {
    SharedPreferences.setMockInitialValues({'isMusicEnabled': false});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsNotifier(prefs);
    await settings.setReducedMotion(true);
    expect(settings.state.reducedMotion, isTrue);
    expect(settings.state.isMusicEnabled, isFalse);
    expect(settings.state.isHapticsEnabled, isTrue);
    final restored = SettingsNotifier(prefs);
    expect(restored.state.reducedMotion, isTrue);
    await restored.setReducedMotion(false);
    expect(prefs.getBool('reducedMotion'), isFalse);
    settings.dispose();
    restored.dispose();
  });
}
