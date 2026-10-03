import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/core/providers/settings_provider.dart';

void main() {
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
