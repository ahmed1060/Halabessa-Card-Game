import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/models/quick_chat_phrase.dart';
import '../../domain/providers/game_providers.dart';
import 'chat_providers.dart';

final quickChatAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  if (ref.watch(sessionUidProvider) == null) return false;
  final result = await ref.read(backendCallProvider)('getQuickChatAdminStatus');
  return result['canManage'] == true;
});

final quickChatCatalogProvider = FutureProvider.autoDispose<QuickChatCatalog>((
  ref,
) async {
  if (ref.watch(sessionUidProvider) == null ||
      !await ref.watch(quickChatAdminProvider.future)) {
    throw StateError('superadmin_required');
  }
  return QuickChatCatalog.fromJson(
    await ref.read(backendCallProvider)('getQuickChatPresets'),
  );
});

/// No cloud client/subscription is constructed for practice or a closed panel.
/// Server checks every send again; this read only controls the visible composer.
final tableChatPolicyProvider = StreamProvider.autoDispose<TableChatPolicy>((
  ref,
) {
  final room = ref.watch(
    matchStateProvider.select((m) => (m?.id, m?.playerIds.join('|'))),
  );
  final uid = ref.watch(currentUserProvider.select((u) => u?.uid));
  final open = ref.watch(chatStateProvider.select((s) => s.isOverlayOpen));
  if (!open ||
      room.$1 == null ||
      room.$1!.startsWith('OFFLINE_') ||
      uid == null ||
      !(ref.read(matchStateProvider)?.playerIds.contains(uid) ?? false)) {
    return Stream.value(const TableChatPolicy());
  }
  final call = ref.read(backendCallProvider);
  final controller = StreamController<TableChatPolicy>();
  Timer? refresh;
  var stopped = false, busy = false;
  Future<void> load() async {
    if (stopped || busy) return;
    busy = true;
    try {
      final result = await call(
        'getTableChatPolicy',
        data: {'roomId': room.$1},
      );
      if (!stopped) controller.add(TableChatPolicy.fromJson(result));
    } catch (error, stack) {
      if (!stopped) controller.addError(error, stack);
    } finally {
      busy = false;
    }
  }

  controller.onListen = () {
    unawaited(load());
    refresh = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(load()),
    );
  };
  controller.onCancel = () {
    stopped = true;
    refresh?.cancel();
  };
  ref.onDispose(() {
    stopped = true;
    refresh?.cancel();
  });
  return controller.stream;
});
