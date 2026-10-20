// Local design-review entry point. Never initialize cloud clients or create
// online accounts/rooms here. Production continues to use lib/main.dart.
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/core/providers/settings_provider.dart';
import 'package:halabessa/core/services/multimedia_service.dart';
import 'package:halabessa/core/routes/app_routes.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import 'package:halabessa/core/utils/web_registry.dart';
import 'package:halabessa/core/widgets/lantern_page_frame.dart';
import 'package:halabessa/core/widgets/lantern_help_screen.dart';
import 'package:halabessa/core/widgets/web_orientation_gate.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';
import 'package:halabessa/features/game/domain/models/bot_difficulty.dart';
import 'package:halabessa/features/game/domain/providers/game_providers.dart';
import 'package:halabessa/features/game/presentation/pages/offline_practice_app.dart';
import 'package:halabessa/features/game/presentation/pages/game_board_screen.dart';
import 'package:halabessa/features/game/presentation/providers/unity_layer_provider.dart';
import 'package:halabessa/features/game/presentation/widgets/unity_persistent_overlay.dart';

const _playerUid = 'LOCAL_design_preview';

// Query parameters affect this isolated preview only. The existing settings
// menu remains usable; production preference defaults and entry points do not
// change. Use ?renderer=flutter to compare on the same build, or choose the
// renderer on the local restart hub after leaving the match.
class _PreviewSettings extends SettingsNotifier {
  _PreviewSettings(super.preferences, {required bool useUnity}) {
    state = state.copyWith(is3DModeEnabled: useUnity);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerWebUnityView();
  await EasyLocalization.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final useUnity = Uri.base.queryParameters['renderer'] != 'flutter';
  final locale = Uri.base.queryParameters['lang'] == 'en'
      ? const Locale('en', 'US')
      : const Locale('ar', 'EG');
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      if (Uri.base.queryParameters['mobileWeb'] == '1')
        mobileWebOrientationGateProvider.overrideWithValue(true),
      ...offlinePlayOverrides(
        preferences,
        AppUser(uid: _playerUid, email: '', displayName: 'You'),
      ),
      settingsProvider.overrideWith(
        (ref) => _PreviewSettings(preferences, useUnity: useUnity),
      ),
    ],
  );
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: EasyLocalization(
        supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
        startLocale: locale,
        fallbackLocale: const Locale('en', 'US'),
        saveLocale: false,
        path: 'assets/translations',
        child: Builder(
          builder: (context) => MaterialApp(
            title: 'Halabessa — Local Playable Preview',
            debugShowCheckedModeBanner: false,
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            theme: ThemeConfig.lightTheme,
            darkTheme: ThemeConfig.darkTheme,
            themeMode: ThemeMode.dark,
            initialRoute: AppRoutes.game,
            routes: {
              AppRoutes.initial: (_) => const _PreviewLobby(),
              AppRoutes.game: (_) => const _PreviewGame(),
              AppRoutes.help: (_) => const LanternHelpScreen(),
            },
            builder: (context, child) =>
                _PreviewLayers(child: child ?? const SizedBox.shrink()),
          ),
        ),
      ),
    ),
  );
  container
      .read(matchStateProvider.notifier)
      .startOfflinePracticeMatch(
        _playerUid,
        'You',
        difficulty: BotDifficulty.hard,
      );
}

/// Mount the production renderer and real audio hooks without any account,
/// presence, auth, database, or network-room initialization.
class _PreviewLayers extends ConsumerWidget {
  const _PreviewLayers({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations:
            settings.reducedMotion || MediaQuery.disableAnimationsOf(context),
      ),
      child: WebOrientationGate(
        child: ColoredBox(
          color: ThemeConfig.darkBg,
          child: Stack(
            children: [
              const UnityPersistentOverlay(),
              Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) =>
                    ref.read(multimediaServiceProvider).handleInteraction(),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The shipped offline entry deliberately excludes Unity. Only this QA wrapper
/// opts the local, cloud-fenced match into the actual renderer for comparison.
/// Do not weaken offlineSessionProvider or replace the match/domain provider.
class _PreviewGame extends ConsumerStatefulWidget {
  const _PreviewGame();

  @override
  ConsumerState<_PreviewGame> createState() => _PreviewGameState();
}

class _PreviewGameState extends ConsumerState<_PreviewGame> {
  bool _syncScheduled = false;

  void _syncRenderer() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted) return;
      final desired =
          ref.read(settingsProvider).is3DModeEnabled &&
          !ref.read(unityFailedProvider);
      if (ref.read(unityLayerVisibilityProvider) != desired) {
        ref.read(unityLayerVisibilityProvider.notifier).state = desired;
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsProvider, (_, __) => _syncRenderer());
    ref.listen(unityLayerVisibilityProvider, (_, __) => _syncRenderer());
    ref.listen(unityFailedProvider, (_, __) => _syncRenderer());
    _syncRenderer();
    return const GameBoardScreen();
  }
}

/// Leaving a local match returns here, never to production's auth or lobby.
class _PreviewLobby extends ConsumerWidget {
  const _PreviewLobby();

  @override
  Widget build(BuildContext context, WidgetRef ref) => LanternPageFrame(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Halabessa — Local preview'),
              const SizedBox(height: 16),
              const Text('Offline practice. No online accounts or rooms.'),
              const SizedBox(height: 24),
              SegmentedButton<bool>(
                segments: [
                  const ButtonSegment(
                    value: false,
                    label: Text('Flutter'),
                    icon: Icon(Icons.layers_outlined),
                  ),
                  ButtonSegment(
                    value: true,
                    label: const Text('Unity'),
                    icon: const Icon(Icons.view_in_ar_outlined),
                    enabled: !ref.watch(unityFailedProvider),
                  ),
                ],
                selected: {ref.watch(settingsProvider).is3DModeEnabled},
                onSelectionChanged: (selection) => ref
                    .read(settingsProvider.notifier)
                    .toggle3DMode(selection.single),
              ),
              if (ref.watch(unityFailedProvider)) ...[
                const SizedBox(height: 12),
                const Text('Unity unavailable. Flutter remains playable.'),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  ref
                      .read(matchStateProvider.notifier)
                      .startOfflinePracticeMatch(
                        _playerUid,
                        'You',
                        difficulty: BotDifficulty.hard,
                      );
                  Navigator.of(context).pushNamed(AppRoutes.game);
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start local preview'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
