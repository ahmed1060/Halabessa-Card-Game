import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/providers/game_providers.dart';
import 'dart:async';
import '../../../auth/presentation/providers/auth_providers.dart';

final chatMessagesProvider = StreamProvider.autoDispose<List<ChatMessage>>((ref) {
  // Use select to only watch the ID, preventing stream recreation on every score/state change
  final matchId = ref.watch(matchStateProvider.select((s) => s?.id));
  if (matchId == null) return Stream.value([]);
  
  return ref.read(multiplayerSyncServiceProvider).watchChatMessages(matchId);
});

class ChatState {
  final bool isOverlayOpen;
  final DateTime lastSeenTimestamp;

  ChatState({
    this.isOverlayOpen = false, 
    DateTime? lastSeenTimestamp
  }) : lastSeenTimestamp = lastSeenTimestamp ?? DateTime.now();

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
    state = state.copyWith(lastSeenTimestamp: DateTime.now());
  }
}

final chatStateProvider = StateNotifierProvider.autoDispose<ChatNotifier, ChatState>((ref) {
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

  ChatBubblesNotifier(this.ref) : super(ChatBubblesState()) {
    // Listen to new messages and update bubbles
    ref.listen<AsyncValue<List<ChatMessage>>>(chatMessagesProvider, (prev, next) {
      next.whenData((messages) {
        if (messages.isEmpty) return;
        final latest = messages.last;
        
        // Only show bubbles for messages sent in the last 2 seconds to avoid old messages popping up on load
        if (DateTime.now().difference(latest.timestamp).inSeconds.abs() < 2) {
          _updateBubble(latest);
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
    _timers[userId] = Timer(const Duration(seconds: 5), () {
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

final chatBubblesProvider = StateNotifierProvider.autoDispose<ChatBubblesNotifier, ChatBubblesState>((ref) {
  return ChatBubblesNotifier(ref);
});

// Deprecated: keeping for compatibility but redirects to chatBubblesProvider
final lastMessageForUserProvider = Provider.family<ChatMessage?, String>((ref, userId) {
  final bubbles = ref.watch(chatBubblesProvider).bubbles;
  return bubbles[userId];
});

// Robust unread count based on lastSeenTimestamp and current user filtering
final unreadMessagesCountProvider = Provider.autoDispose<int>((ref) {
  final messagesAsync = ref.watch(chatMessagesProvider);
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
