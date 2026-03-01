import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/chat_providers.dart';
import '../../domain/providers/game_providers.dart';
import '../../domain/models/chat_message.dart';
import '../../../../core/theme/theme_config.dart';

class ChatOverlay extends ConsumerStatefulWidget {
  const ChatOverlay({super.key});

  @override
  ConsumerState<ChatOverlay> createState() => _ChatOverlayState();
}

class _ChatOverlayState extends ConsumerState<ChatOverlay> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _sendMessage(String text, {bool isQuickChat = false}) {
    if (text.trim().isEmpty) return;

    final matchState = ref.read(matchStateProvider);
    final currentUser = ref.read(currentUserProvider);
    
    if (matchState == null || currentUser == null) return;

    final message = ChatMessage(
      id: '', // Will be set by Firebase push()
      senderId: currentUser.uid,
      senderName: currentUser.displayName,
      text: text.trim(),
      timestamp: DateTime.now(),
      isQuickChat: isQuickChat,
    );

    ref.read(multiplayerSyncServiceProvider).sendChatMessage(matchState.id, message);
    _controller.clear();
    
    // Auto-close overlay if it was a quick chat
    if (isQuickChat) {
      ref.read(chatStateProvider.notifier).setOverlayOpen(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatStateProvider);
    final messagesAsync = ref.watch(chatMessagesProvider);
    final size = MediaQuery.of(context).size;
    final panelWidth = size.width * 0.8 > 350 ? 350.0 : size.width * 0.8;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      left: chatState.isOverlayOpen ? 0 : -panelWidth,
      top: 0,
      bottom: 0,
      child: Container(
        width: panelWidth,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          boxShadow: [
            BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5)
          ],
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, color: ThemeConfig.primaryTeal),
                    const SizedBox(width: 12),
                    Text(
                      'chat'.tr(),
                      style: const TextStyle(
                        fontFamily: ThemeConfig.fontHeading,
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => ref.read(chatStateProvider.notifier).setOverlayOpen(false),
                    ),
                  ],
                ),
              ),
              
              const Divider(color: Colors.white10),

              // Quick Chat Presets
              SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    _buildQuickChatChip('msg_gg'.tr()),
                    _buildQuickChatChip('msg_nice_play'.tr()),
                    _buildQuickChatChip('msg_your_turn'.tr()),
                    _buildQuickChatChip('msg_hala8essa'.tr()),
                    _buildQuickChatChip('msg_oops'.tr()),
                  ],
                ),
              ),

              const Divider(color: Colors.white10),

              // Message List
              Expanded(
                child: messagesAsync.when(
                  data: (messages) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                        );
                      }
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = msg.senderId == ref.read(currentUserProvider)?.uid;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.senderName,
                                style: TextStyle(color: isMe ? ThemeConfig.primaryTeal : Colors.white54, fontSize: 11),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isMe ? ThemeConfig.primaryTeal.withOpacity(0.2) : Colors.white10,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isMe ? ThemeConfig.primaryTeal.withOpacity(0.3) : Colors.white12,
                                  ),
                                ),
                                child: Text(
                                  msg.text,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('chat_error'.tr(), style: const TextStyle(color: Colors.red))),
                ),
              ),

              // Input Field
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: TextField(
                          controller: _controller,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'tap_to_type'.tr(),
                            hintStyle: const TextStyle(color: Colors.white30),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (val) => _sendMessage(val),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: ThemeConfig.primaryTeal),
                      onPressed: () => _sendMessage(_controller.text),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChatChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        backgroundColor: Colors.white10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white24)),
        onPressed: () => _sendMessage(label, isQuickChat: true),
      ),
    );
  }
}
