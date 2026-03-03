import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/providers/game_providers.dart';
import 'dart:async';

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

// Provider to get the latest message for a specific user to show in a bubble
final lastMessageForUserProvider = Provider.family<ChatMessage?, String>((ref, userId) {
  final messagesAsync = ref.watch(chatMessagesProvider);
  return messagesAsync.when(
    data: (messages) {
      if (messages.isEmpty) return null;
      // Filter for user and get most recent within a reasonable time window (e.g. 5 seconds)
      try {
        final userMessages = messages.where((m) => m.senderId == userId).toList();
        if (userMessages.isEmpty) return null;
        
        final latest = userMessages.last;
        final now = DateTime.now();
        if (now.difference(latest.timestamp).inSeconds < 5) {
          return latest;
        }
      } catch (e) {
        return null;
      }
      return null;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

// Corrected unread count based on lastSeenTimestamp
final unreadMessagesCountProvider = Provider.autoDispose<int>((ref) {
  final messagesAsync = ref.watch(chatMessagesProvider);
  final chatState = ref.watch(chatStateProvider);
  
  return messagesAsync.when(
    data: (messages) {
      if (chatState.isOverlayOpen) return 0;
      return messages.where((m) => m.timestamp.isAfter(chatState.lastSeenTimestamp)).length;
    },
    loading: () => 0,
    error: (_, __) => 0,
  );
});
