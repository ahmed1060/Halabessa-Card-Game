import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/core/providers/settings_provider.dart';
import 'package:halabessa/core/widgets/app_orientation_scope.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late List<List<dynamic>> requests;

  setUp(() {
    requests = [];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          requests.add(List<dynamic>.from(call.arguments as List));
        }
        return null;
      },
    );
  });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  Future<ProviderContainer> mount(WidgetTester tester, {String? saved}) async {
    SharedPreferences.setMockInitialValues({
      if (saved != null) 'gameOrientation': saved,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: AppOrientationScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const Scaffold(body: Text('Another screen')),
                    ),
                  ),
                  child: const Text('Open another screen'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets(
    'native app starts landscape even outside a match',
    (tester) async {
      await mount(tester);
      expect(requests.single, [
        'DeviceOrientation.landscapeLeft',
        'DeviceOrientation.landscapeRight',
      ]);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'saved portrait is restored before any match route',
    (tester) async {
      await mount(tester, saved: 'portrait');
      expect(requests.single, ['DeviceOrientation.portraitUp']);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'settings apply globally and navigation never unlocks them',
    (tester) async {
      final container = await mount(tester);
      await container
          .read(settingsProvider.notifier)
          .setGameOrientation(GameOrientation.portrait);
      await tester.pump();
      expect(requests.last, ['DeviceOrientation.portraitUp']);
      final count = requests.length;
      await tester.tap(find.text('Open another screen'));
      await tester.pumpAndSettle();
      expect(find.text('Another screen'), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(requests.length, count);
      await tester.pumpWidget(const SizedBox());
      expect(requests.length, count);
      expect(requests.every((value) => value.isNotEmpty), isTrue);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'resume reapplies the current preference without resetting it',
    (tester) async {
      final container = await mount(tester, saved: 'portrait');
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await container
          .read(settingsProvider.notifier)
          .setGameOrientation(GameOrientation.landscape);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(requests.last, [
        'DeviceOrientation.landscapeLeft',
        'DeviceOrientation.landscapeRight',
      ]);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'desktop does not send mobile orientation commands',
    (tester) async {
      await mount(tester);
      expect(requests, isEmpty);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.macOS,
      TargetPlatform.linux,
    }),
  );
}
