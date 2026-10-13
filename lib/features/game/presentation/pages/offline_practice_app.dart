import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/native_play_provider.dart';
import '../../../../core/providers/global_settings_provider.dart';
import '../../../../core/services/multimedia_service.dart';
import '../../../../core/widgets/lantern_page_frame.dart';
import '../../../../core/widgets/lantern_help_screen.dart';
import '../../../../core/widgets/settings_overlay.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../home/presentation/providers/store_provider.dart';
import '../../../home/presentation/widgets/practice_difficulty_dialog.dart';
import '../../domain/models/bot_difficulty.dart';
import '../../domain/providers/game_providers.dart';
import '../providers/chat_providers.dart';
import '../widgets/table_style.dart';
import 'game_board_screen.dart';

// A separate container makes fresh signed-out Practice independent of Firebase
// initialization. Fail fast if an accidental cloud dependency is introduced.
offlinePlayOverrides(
  SharedPreferences preferences,
  AppUser player, {
  MultimediaService Function(Ref)? audioFactory,
}) => [
  offlineSessionProvider.overrideWithValue(true),
  currentUserProvider.overrideWithValue(player),
  authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
  sessionUidProvider.overrideWithValue(null),
  firebaseAuthProvider.overrideWith(
    (ref) => throw StateError('offline_cloud_forbidden'),
  ),
  authRepositoryProvider.overrideWith(
    (ref) => throw StateError('offline_cloud_forbidden'),
  ),
  backendCallProvider.overrideWithValue(
    (String action, {Map<String, dynamic>? data, Duration? timeout}) async =>
        throw StateError('offline_cloud_forbidden'),
  ),
  userProfileProvider.overrideWith(
    (ref, uid) async => uid == player.uid ? player : null,
  ),
  multiplayerSyncServiceProvider.overrideWith(
    (ref) => throw StateError('offline_cloud_forbidden'),
  ),
  globalSettingsProvider.overrideWith(
    (ref) => GlobalSettingsNotifier(listenRemote: false),
  ),
  storeProvider.overrideWith(
    (ref) => StoreNotifier(preferences, ref, listenRemote: false),
  ),
  activeTableSkinProvider.overrideWithValue(defaultTableSkin()),
  activeCardBackProvider.overrideWithValue(
    StoreNotifier.builtinItems.firstWhere((item) => item.id == 'default_card'),
  ),
  multimediaServiceProvider.overrideWith(
    (ref) => (audioFactory ?? MultimediaService.new)(ref),
  ),
  matchStateProvider.overrideWith((ref) => MatchStateNotifier(ref)),
  chatMessagesProvider.overrideWith((ref) => Stream.value([])),
  chatStateProvider.overrideWith((ref) => ChatNotifier()),
  chatBubblesProvider.overrideWith((ref) => ChatBubblesNotifier(ref)),
  lastMessageForUserProvider.overrideWith((ref, uid) => null),
  unreadMessagesCountProvider.overrideWithValue(0),
];

class OfflinePracticeApp extends StatelessWidget {
  final SharedPreferences preferences;
  final AppUser player;
  final VoidCallback onExit;
  const OfflinePracticeApp({
    super.key,
    required this.preferences,
    required this.player,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: offlinePlayOverrides(preferences, player),
    child: Consumer(
      builder: (context, ref, _) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) =>
            ref.read(multimediaServiceProvider).handleInteraction(),
        child: Navigator(
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => switch (settings.name) {
              '/game' => const GameBoardScreen(),
              '/help' => const LanternHelpScreen(),
              _ => OfflinePracticeHub(onExit: onExit),
            },
          ),
        ),
      ),
    ),
  );
}

class OfflinePracticeHub extends ConsumerWidget {
  final VoidCallback onExit;
  const OfflinePracticeHub({super.key, required this.onExit});

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final level = await showDialog<BotDifficulty>(
      context: context,
      builder: (_) => const PracticeDifficultyDialog(),
    );
    if (level == null || !context.mounted) return;
    final player = ref.read(currentUserProvider)!;
    ref
        .read(matchStateProvider.notifier)
        .startOfflinePracticeMatch(
          player.uid,
          player.displayName,
          difficulty: level,
        );
    Navigator.of(context).pushNamed('/game');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => LanternPageFrame(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('offline_practice_title'.tr()),
        leading: IconButton(
          onPressed: onExit,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const SettingsOverlay(),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.offline_bolt_outlined,
                    color: TableStyle.brass,
                    size: 56,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'offline_practice_title'.tr(),
                    textAlign: TextAlign.center,
                    style: TableStyle.label.copyWith(fontSize: 28),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'offline_practice_description'.tr(),
                    textAlign: TextAlign.center,
                    style: TableStyle.label,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const ValueKey('start-offline-practice'),
                    onPressed: () => _start(context, ref),
                    icon: const Icon(Icons.play_arrow),
                    label: Text('solo_training'.tr()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
