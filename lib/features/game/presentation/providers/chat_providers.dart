import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/providers/game_providers.dart';
import 'dart:async';
import '../../domain/logic/online_match_clock.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import 'package:easy_localization/easy_localization.dart';

final chatChannelProvider = StateProvider.autoDispose<ChatChannel>(
  (ref) => ChatChannel.public,
);

final chatMessagesProvider = StreamProvider.autoDispose<List<ChatMessage>>((
  ref,
) {
  // Use select to only watch the ID, preventing stream recreation on every score/state change
  final matchId = ref.watch(matchStateProvider.select((s) => s?.id));
  if (matchId == null) return Stream.value([]);
  final channel = ref.watch(chatChannelProvider);
  if (channel == ChatChannel.game) {
    final state = ref.watch(matchStateProvider);
    final history = state?.playHistory ?? [];
    const suits = {'hearts': '♥', 'diamonds': '♦', 'clubs': '♣', 'spades': '♠'};
    final time =
        state?.phaseStartedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return Stream.value(
      history
          .asMap()
          .entries
          .map(
            (entry) => ChatMessage(
              id: 'game-${state?.roundCount}-${entry.key}',
              senderId: 'system',
              senderName: 'ui_chat_game'.tr(),
              text: 'ui_game_card_played'.tr(
                args: [
                  '${{11: 'J', 12: 'Q', 13: 'K', 14: 'A'}[entry.value.rank.value] ?? entry.value.rank.value}${suits[entry.value.suit.name]}',
                ],
              ),
              timestamp: time,
            ),
          )
          .toList(),
    );
  }
  return ref
      .watch(roomChatMessagesProvider)
      .when(
        data: (messages) => Stream.value(messages),
        loading: () => const Stream.empty(),
        error: (error, stack) => Stream.error(error, stack),
      );
});

// Room messages remain subscribed when the player looks at the game log.
final roomChatMessagesProvider = StreamProvider.autoDispose<List<ChatMessage>>((
  ref,
) {
  final room = ref.watch(
    matchStateProvider.select((s) => (s?.id, s?.protocolVersion ?? 0)),
  );
  final uid = ref.watch(currentUserProvider.select((u) => u?.uid));
  if (room.$1 == null ||
      room.$1!.startsWith('OFFLINE_') ||
      room.$2 == 0 ||
      uid == null ||
      !(ref.watch(
        matchStateProvider.select((s) => s?.playerIds.contains(uid) ?? false),
      ))) {
    return Stream.value([]);
  }
  return ref.read(multiplayerSyncServiceProvider).watchChatMessages(room.$1!);
});

class ChatState {
  final bool isOverlayOpen;
  final DateTime lastSeenTimestamp;

  ChatState({this.isOverlayOpen = false, DateTime? lastSeenTimestamp})
    : lastSeenTimestamp = lastSeenTimestamp ?? OnlineMatchClock.instance.now();

  ChatState copyWith({bool? isOverlayOpen, DateTime? lastSeenTimestamp}) {
    return ChatState(
      isOverlayOpen: isOverlayOpen ?? this.isOverlayOpen,
      lastSeenTimestamp: lastSeenTimestamp ?? this.lastSeenTimestamp,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier() : super(ChatState());

  void toggleOverlay() {
    final newOpen = !state.isOverlayOpen;
    if (newOpen) {
      markAllSeen();
    }
    state = state.copyWith(isOverlayOpen: newOpen);
  }

  void setOverlayOpen(bool open) {
    if (open) {
      markAllSeen();
    }
    state = state.copyWith(isOverlayOpen: open);
  }

  void markAllSeen() {
    state = state.copyWith(lastSeenTimestamp: OnlineMatchClock.instance.now());
  }
}

final chatStateProvider =
    StateNotifierProvider.autoDispose<ChatNotifier, ChatState>((ref) {
      return ChatNotifier();
    });

// Map of userId -> latest ChatMessage that should be shown in a bubble
class ChatBubblesState {
  final Map<String, ChatMessage> bubbles;
  ChatBubblesState({this.bubbles = const {}});

  ChatBubblesState copyWith({Map<String, ChatMessage>? bubbles}) {
    return ChatBubblesState(bubbles: bubbles ?? this.bubbles);
  }
}

class ChatBubblesNotifier extends StateNotifier<ChatBubblesState> {
  final Ref ref;
  final Map<String, Timer> _timers = {};
  Set<String>? _seen;

  ChatBubblesNotifier(this.ref) : super(ChatBubblesState()) {
    ref.listen<AsyncValue<List<ChatMessage>>>(roomChatMessagesProvider, (
      prev,
      next,
    ) {
      next.whenData((messages) {
        final ids = messages.map((m) => m.id).toSet();
        final before = _seen;
        _seen = ids;
        if (before == null) return; // Never replay a transcript on subscribe.
        for (final message in messages) {
          if (!before.contains(message.id) &&
              OnlineMatchClock.instance
                      .now()
                      .difference(message.timestamp)
                      .abs() <
                  const Duration(seconds: 5)) {
            _updateBubble(message);
          }
        }
      });
    });
  }

  void _updateBubble(ChatMessage message) {
    final userId = message.senderId;

    // Cancel existing timer for this user
    _timers[userId]?.cancel();

    // Update state
    final newBubbles = Map<String, ChatMessage>.from(state.bubbles);
    newBubbles[userId] = message;
    state = state.copyWith(bubbles: newBubbles);

    // Set new timer to clear
    _timers[userId] = Timer(const Duration(milliseconds: 3180), () {
      final updatedBubbles = Map<String, ChatMessage>.from(state.bubbles);
      updatedBubbles.remove(userId);
      state = state.copyWith(bubbles: updatedBubbles);
      _timers.remove(userId);
    });
  }

  @override
  void dispose() {
    for (var timer in _timers.values) {
      timer.cancel();
    }
    super.dispose();
  }
}

final chatBubblesProvider =
    StateNotifierProvider.autoDispose<ChatBubblesNotifier, ChatBubblesState>((
      ref,
    ) {
      ref.watch(matchStateProvider.select((s) => s?.id));
      ref.watch(currentUserProvider.select((u) => u?.uid));
      return ChatBubblesNotifier(ref);
    });

// Deprecated: keeping for compatibility but redirects to chatBubblesProvider
final lastMessageForUserProvider = Provider.family<ChatMessage?, String>((
  ref,
  userId,
) {
  final bubbles = ref.watch(chatBubblesProvider).bubbles;
  return bubbles[userId];
});

// Robust unread count based on lastSeenTimestamp and current user filtering
final unreadMessagesCountProvider = Provider.autoDispose<int>((ref) {
  final messagesAsync = ref.watch(roomChatMessagesProvider);
  final chatState = ref.watch(chatStateProvider);
  final currentUser = ref.read(currentUserProvider);

  if (chatState.isOverlayOpen) return 0;

  return messagesAsync.when(
    data: (messages) {
      if (messages.isEmpty) return 0;
      final myUid = currentUser?.uid;

      // We only count messages sent by OTHERS that arrived AFTER we started/last saw the chat
      return messages.where((m) {
        final isFromMe = myUid != null && m.senderId == myUid;
        final isNew = m.timestamp.isAfter(chatState.lastSeenTimestamp);
        return !isFromMe && isNew;
      }).length;
    },
    loading: () => 0,
    error: (_, __) => 0,
  );
});
