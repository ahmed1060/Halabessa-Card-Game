import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/providers/game_providers.dart';
import 'dart:async';

final chatMessagesProvider = StreamProvider.autoDispose<List<ChatMessage>>((ref) {
  final matchState = ref.watch(matchStateProvider);
  if (matchState == null) return Stream.value([]);
  
  return ref.read(multiplayerSyncServiceProvider).watchChatMessages(matchState.id);
});

class ChatState {
  final bool isOverlayOpen;
  final String? lastMessageId; // To track which message was last "seen" or handled

  ChatState({this.isOverlayOpen = false, this.lastMessageId});

  ChatState copyWith({bool? isOverlayOpen, String? lastMessageId}) {
    return ChatState(
      isOverlayOpen: isOverlayOpen ?? this.isOverlayOpen,
      lastMessageId: lastMessageId ?? this.lastMessageId,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier() : super(ChatState());

  void toggleOverlay() {
    state = state.copyWith(isOverlayOpen: !state.isOverlayOpen);
  }

  void setOverlayOpen(bool open) {
    state = state.copyWith(isOverlayOpen: open);
  }
}

final chatStateProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
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

// Simplified unread count based on total messages
final unreadMessagesCountProvider = Provider.autoDispose<int>((ref) {
  final messagesAsync = ref.watch(chatMessagesProvider);
  return messagesAsync.when(
    data: (messages) => messages.length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});
