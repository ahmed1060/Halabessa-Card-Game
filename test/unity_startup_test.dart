import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/presentation/providers/unity_layer_provider.dart';
import 'package:halabessa/features/game/presentation/providers/unity_startup_state.dart';
import 'package:halabessa/features/game/presentation/widgets/unity_persistent_overlay.dart';

void main() {
  test('only the explicit handshake marks the renderer ready', () {
    final startup = UnityStartupState();
    for (final event in [null, 'STATE_CHANGED', 'ANIMATION_COMPLETE', 'PLAY_CARD']) {
      expect(startup.handleEvent(event), isFalse);
      expect(startup.isReady, isFalse);
    }
    expect(startup.handleEvent('UNITY_READY'), isTrue);
    expect(startup.isReady, isTrue);
  });

  test('startup failure or context loss cannot be reversed by a late handshake', () {
    for (final readyFirst in [false, true]) {
      final startup = UnityStartupState();
      if (readyFirst) startup.handleEvent('UNITY_READY');
      startup.handleEvent('UNITY_FAILED');
      expect(startup.isReady, isFalse);
      expect(startup.hasFailed, isTrue);
      expect(startup.handleEvent('UNITY_READY'), isFalse);
      expect(startup.isReady, isFalse);
    }
  });

  testWidgets('renderer mounts lazily, remains hidden until ready, and is reused', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    var mounts = 0;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Stack(children: [
        UnityPersistentOverlay(unityView: _FakeEngine(onMount: () => mounts++)),
      ])),
    ));
    expect(mounts, 0);
    expect(find.byType(_FakeEngine), findsNothing);

    container.read(unityLayerVisibilityProvider.notifier).state = true;
    await tester.pump();
    expect(mounts, 1);
    final opacity = find.descendant(of: find.byType(UnityPersistentOverlay), matching: find.byType(Opacity));
    expect(tester.widget<Opacity>(opacity).opacity, 0);

    container.read(unityInitializedProvider.notifier).state = true;
    await tester.pump();
    expect(tester.widget<Opacity>(opacity).opacity, 1);

    container.read(unityLayerVisibilityProvider.notifier).state = false;
    await tester.pump();
    expect(tester.widget<Opacity>(opacity).opacity, 0);
    container.read(unityLayerVisibilityProvider.notifier).state = true;
    await tester.pump();
    expect(mounts, 1);
    expect(tester.widget<Opacity>(opacity).opacity, 1);

    container.read(unityFailedProvider.notifier).state = true;
    await tester.pump();
    expect(tester.widget<Opacity>(opacity).opacity, 0);
    expect(container.read(unityLayerActiveProvider), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _FakeEngine extends StatefulWidget {
  const _FakeEngine({required this.onMount});
  final VoidCallback onMount;
  @override
  State<_FakeEngine> createState() => _FakeEngineState();
}

class _FakeEngineState extends State<_FakeEngine> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
