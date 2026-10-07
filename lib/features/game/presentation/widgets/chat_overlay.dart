import 'package:flutter/material.dart';
import 'package:halabessa/features/game/presentation/widgets/table_style.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/chat_providers.dart';
import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';
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
  bool _sending = false;
  String? _sendError;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text, {bool isQuickChat = false}) async {
    if (_sending || ref.read(chatChannelProvider) == ChatChannel.game) return;
    final safeText = text.trim();
    if (safeText.isEmpty) return;
    final limitedText = safeText.length > 60
        ? safeText.substring(0, 60)
        : safeText;

    final matchState = ref.read(matchStateProvider);
    final currentUser = ref.read(currentUserProvider);

    if (matchState == null ||
        currentUser == null ||
        matchState.id.startsWith('OFFLINE_'))
      return;
    final seat = matchState.playerIds.indexOf(currentUser.uid);
    if (seat < 0) return;
    final channel = ref.read(chatChannelProvider) == ChatChannel.team
        ? (seat.isEven ? 'teamA' : 'teamB')
        : 'public';

    final message = ChatMessage(
      id: '', // Will be set by Firebase push()
      senderId: currentUser.uid,
      senderName: currentUser.displayName,
      text: limitedText,
      timestamp: DateTime.now(),
      isQuickChat: isQuickChat,
    );

    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      await ref
          .read(multiplayerSyncServiceProvider)
          .sendChatMessage(
            matchState.id,
            message,
            channel: channel,
            legacy: !matchState.usesServerCommands,
          );
      if (!mounted) return;
      _controller.clear();

      // Auto-close overlay if it was a quick chat
      if (isQuickChat) {
        ref.read(chatStateProvider.notifier).setOverlayOpen(false);
      }
    } catch (_) {
      if (mounted) setState(() => _sendError = 'ui_chat_send_failed'.tr());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatStateProvider);
    final messagesAsync = ref.watch(chatMessagesProvider);
    final channel = ref.watch(chatChannelProvider);
    final match = ref.watch(matchStateProvider);
    final offline = match == null || match.id.startsWith('OFFLINE_');
    final size = MediaQuery.of(context).size;
    final panelWidth = size.width * 0.8 > 350 ? 350.0 : size.width * 0.8;

    return AnimatedPositionedDirectional(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      start: chatState.isOverlayOpen ? 0 : -panelWidth,
      top: 0,
      bottom: 0,
      child: Container(
        width: panelWidth,
        decoration: const BoxDecoration(
          color: TableStyle.ink,
          boxShadow: [
            BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5),
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
                    const Icon(
                      Icons.chat_bubble_outline,
                      color: TableStyle.mint,
                    ),
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
                      onPressed: () => ref
                          .read(chatStateProvider.notifier)
                          .setOverlayOpen(false),
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white10),
              Wrap(
                spacing: 4,
                children: [
                  for (final option in ChatChannel.values)
                    ChoiceChip(
                      label: Text('ui_chat_${option.name}'.tr()),
                      selected: channel == option,
                      onSelected:
                          _sending ||
                              (option != ChatChannel.game && offline) ||
                              (option == ChatChannel.team &&
                                  !(match?.usesServerCommands ?? false))
                          ? null
                          : (_) =>
                                ref.read(chatChannelProvider.notifier).state =
                                    option,
                    ),
                ],
              ),
              if (_sendError != null)
                Text(
                  _sendError!,
                  style: const TextStyle(color: TableStyle.red),
                ),

              // Quick Chat Presets
              if (channel != ChatChannel.game && !offline)
                SizedBox(
                  height: 50,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
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
                child: ColoredBox(
                  color: const Color(0xFFFFF0D1),
                  child: messagesAsync.when(
                    data: (messages) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        if (_scrollController.hasClients) {
                          _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                          );
                        }

                        // If open, immediately mark everything as seen
                        if (chatState.isOverlayOpen && messages.isNotEmpty) {
                          final latest = messages.last.timestamp;
                          if (latest.isAfter(chatState.lastSeenTimestamp)) {
                            ref.read(chatStateProvider.notifier).markAllSeen();
                          }
                        }
                      });

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMe =
                              msg.senderId ==
                              ref.read(currentUserProvider)?.uid;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg.senderName,
                                  style: const TextStyle(
                                    color: Color(0xFF192638),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? TableStyle.mint
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0x33192638),
                                    ),
                                  ),
                                  child: Text(
                                    msg.text,
                                    style: const TextStyle(
                                      color: Color(0xFF192638),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Text(
                        'chat_error'.tr(),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ),
              ),

              // Input Field
              if (channel != ChatChannel.game && !offline)
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
                            enabled: !_sending,
                            maxLength: 60,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'tap_to_type'.tr(),
                              hintStyle: const TextStyle(color: Colors.white30),
                              border: InputBorder.none,
                              counterText: "",
                            ),
                            onSubmitted: (val) => _sendMessage(val),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send, color: TableStyle.mint),
                        onPressed: _sending
                            ? null
                            : () => _sendMessage(_controller.text),
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
        label: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        backgroundColor: Colors.white10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white24),
        ),
        onPressed: () => _sendMessage(label, isQuickChat: true),
      ),
    );
  }
}
