import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/core/providers/settings_provider.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';
import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';
import 'package:halabessa/features/game/domain/providers/game_providers.dart';
import 'package:halabessa/features/game/domain/models/chat_message.dart';
import 'package:halabessa/features/game/presentation/pages/offline_practice_app.dart';
import 'package:halabessa/features/game/presentation/providers/chat_providers.dart';
import 'package:halabessa/features/game/presentation/providers/quick_chat_providers.dart';

void main() {
  testWidgets(
    'bubbles ignore initial history, remain live in game log and do not replay duplicates',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final messages = StreamController<List<ChatMessage>>();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ...offlinePlayOverrides(
            prefs,
            AppUser(uid: 'LOCAL_qa', email: '', displayName: 'You'),
          ),
          roomChatMessagesProvider.overrideWith((ref) => messages.stream),
        ],
      );
      final subscription = container.listen(chatBubblesProvider, (_, _) {});
      final old = ChatMessage(
        id: 'old',
        senderId: 'bob',
        senderName: 'Bob',
        text: 'Past',
        timestamp: DateTime.now(),
      );
      messages.add([old]);
      await tester.pump();
      expect(container.read(chatBubblesProvider).bubbles, isEmpty);
      final fresh = ChatMessage(
        id: 'new',
        senderId: 'bob',
        senderName: 'Bob',
        text: 'Nice play!',
        timestamp: DateTime.now(),
      );
      messages.add([old, fresh]);
      await tester.pump();
      expect(container.read(chatBubblesProvider).bubbles['bob']?.id, 'new');
      container.read(chatChannelProvider.notifier).state = ChatChannel.game;
      await tester.pump();
      expect(container.read(chatBubblesProvider).bubbles['bob']?.id, 'new');
      await tester.pump(const Duration(milliseconds: 2000));
      messages.add([old, fresh]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1180));
      expect(container.read(chatBubblesProvider).bubbles, isEmpty);
      subscription.close();
      container.dispose();
      unawaited(messages.close());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
  testWidgets(
    'opening chat in practice stays fail-closed without constructing a backend',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ...offlinePlayOverrides(
            prefs,
            AppUser(uid: 'LOCAL_qa', email: '', displayName: 'You'),
          ),
          backendCallProvider.overrideWith(
            (ref) => throw StateError('cloud dependency constructed'),
          ),
        ],
      );
      container.read(chatStateProvider.notifier).setOverlayOpen(true);
      final sub = container.listen(tableChatPolicyProvider, (_, _) {});
      await tester.pump();
      final policy = container.read(tableChatPolicyProvider).asData!.value;
      expect(policy.canType, false);
      expect(policy.available, false);
      sub.close();
      container.dispose();
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}
