import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/chat_providers.dart';
import '../providers/quick_chat_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/providers/game_providers.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/models/quick_chat_phrase.dart';
import 'table_style.dart';

class ChatOverlay extends ConsumerStatefulWidget {
  const ChatOverlay({super.key});
  @override
  ConsumerState<ChatOverlay> createState() => _ChatOverlayState();
}

class _ChatOverlayState extends ConsumerState<ChatOverlay> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _error, _pendingKey, _pendingId;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send({QuickChatPhrase? phrase}) async {
    final policy = ref.read(tableChatPolicyProvider).asData?.value;
    final match = ref.read(matchStateProvider);
    final user = ref.read(currentUserProvider);
    if (_sending ||
        match == null ||
        user == null ||
        match.id.startsWith('OFFLINE_') ||
        !match.playerIds.contains(user.uid) ||
        policy?.available != true ||
        (phrase == null && policy?.canType != true))
      return;
    final text = _controller.text.trim();
    if (phrase == null && (text.isEmpty || text.length > 60)) return;
    final body = <String, dynamic>{
      'roomId': match.id,
      'channel': 'public',
      if (phrase != null) ...{
        'presetId': phrase.id,
        'locale': context.locale.languageCode,
      } else
        'text': text,
    };
    final key = jsonEncode([user.uid, body]);
    if (_pendingKey != key) {
      _pendingKey = key;
      _pendingId =
          '${DateTime.now().microsecondsSinceEpoch}_${math.Random.secure().nextInt(1 << 32)}';
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(backendCallProvider)(
        'sendTableChat',
        data: {...body, 'messageId': _pendingId},
      );
      if (!mounted ||
          ref.read(matchStateProvider)?.id != match.id ||
          ref.read(currentUserProvider)?.uid != user.uid)
        return;
      _pendingKey = null;
      _pendingId = null;
      if (phrase == null) _controller.clear();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'ui_chat_send_failed'.tr());
        ref.invalidate(tableChatPolicyProvider);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = ref.watch(chatStateProvider).isOverlayOpen;
    ref.listen<AsyncValue<List<ChatMessage>>>(roomChatMessagesProvider, (
      _,
      next,
    ) {
      if (open &&
          ref.read(chatChannelProvider) == ChatChannel.public &&
          next.hasValue) {
        ref.read(chatStateProvider.notifier).markAllSeen();
      }
    });
    final policyAsync = ref.watch(tableChatPolicyProvider);
    final policy = policyAsync.asData?.value ?? const TableChatPolicy();
    final messages = ref.watch(chatMessagesProvider);
    final channel = ref.watch(chatChannelProvider);
    final match = ref.watch(matchStateProvider);
    final offline = match == null || match.id.startsWith('OFFLINE_');
    final avatars = <String, String>{};
    if (open && !offline) {
      for (final uid in match.playerIds.where(
        (id) => !id.startsWith('bot_') && !id.startsWith('waiting_'),
      )) {
        final profile = ref.watch(userProfileProvider(uid)).asData?.value;
        final url = profile?.avatarUrl;
        if (url != null && url.isNotEmpty) avatars[uid] = url;
      }
    }
    final media = MediaQuery.of(context);
    final width = math.min(360.0, math.max(0.0, media.size.width - 32));
    final available = math.max(
      0.0,
      media.size.height - media.padding.vertical - media.viewInsets.bottom - 32,
    );
    return AnimatedPositionedDirectional(
      duration: media.disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      start: open ? 16 : -width - 24,
      bottom: media.viewInsets.bottom + media.padding.bottom + 16,
      width: width,
      height: math.min(
        media.size.width > media.size.height ? 340.0 : 460.0,
        available * .82,
      ),
      child: IgnorePointer(
        ignoring: !open,
        child: ExcludeSemantics(
          excluding: !open,
          child: TableChatPanel(
            controller: _controller,
            avatarUrls: avatars,
            channel: channel,
            policy: policy,
            offline: offline,
            sending: _sending,
            loading: policyAsync.isLoading,
            error:
                _error ??
                (policyAsync.hasError ? 'table_chat_unavailable'.tr() : null),
            messages: messages.asData?.value ?? const [],
            messagesError: messages.hasError,
            onClose: () =>
                ref.read(chatStateProvider.notifier).setOverlayOpen(false),
            onChannel: (value) {
              ref.read(chatChannelProvider.notifier).state = value;
              ref.read(chatStateProvider.notifier).markAllSeen();
            },
            onSend: () => _send(),
            onQuick: (phrase) => _send(phrase: phrase),
            onRetry: () => ref.invalidate(tableChatPolicyProvider),
          ),
        ),
      ),
    );
  }
}

/// Stateless presentation also used by isolated fixtures and widget tests.
class TableChatPanel extends StatelessWidget {
  const TableChatPanel({
    super.key,
    required this.controller,
    required this.channel,
    required this.policy,
    required this.messages,
    required this.onClose,
    required this.onChannel,
    required this.onSend,
    required this.onQuick,
    required this.onRetry,
    this.offline = false,
    this.sending = false,
    this.loading = false,
    this.messagesError = false,
    this.avatarUrls = const {},
    this.error,
  });
  final TextEditingController controller;
  final ChatChannel channel;
  final TableChatPolicy policy;
  final List<ChatMessage> messages;
  final Map<String, String> avatarUrls;
  final VoidCallback onClose, onSend, onRetry;
  final ValueChanged<ChatChannel> onChannel;
  final ValueChanged<QuickChatPhrase> onQuick;
  final bool offline, sending, loading, messagesError;
  final String? error;
  Widget _avatar(ChatMessage message, bool log) {
    final url = log ? null : avatarUrls[message.senderId];
    return CircleAvatar(
      radius: 16,
      backgroundColor: TableStyle.mint.withValues(alpha: .18),
      backgroundImage: url == null
          ? null
          : url.startsWith('assets/')
          ? AssetImage(url)
          : NetworkImage(url),
      onBackgroundImageError: url == null ? null : (_, _) {},
      child: url != null
          ? null
          : log
          ? const Icon(Icons.style_outlined, size: 19, color: TableStyle.mint)
          : Text(
              message.senderName.isEmpty
                  ? '?'
                  : message.senderName.characters.first.toUpperCase(),
              style: TableStyle.detail.copyWith(color: TableStyle.mint),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final log = channel == ChatChannel.game;
    final canType = policy.available && policy.canType && !offline;
    final status = offline
        ? 'table_chat_practice'
        : loading
        ? 'table_chat_checking'
        : canType
        ? 'table_chat_all_friends'
        : 'table_chat_quick_only';
    return Material(
      color: Colors.transparent,
      child: Container(
        key: const ValueKey('table-chat-panel'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF10283A), Color(0xFF091724)],
          ),
          border: Border.all(color: TableStyle.brass, width: 1.5),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 300;
            final history = messagesError
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('chat_error'.tr(), style: TableStyle.detail),
                  )
                : messages.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      (log ? 'table_chat_log_empty' : 'table_chat_empty').tr(),
                      style: TableStyle.detail,
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    reverse: !compact,
                    physics: compact
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    itemCount: compact
                        ? math.min(3, messages.length).toInt()
                        : messages.length,
                    itemBuilder: (context, index) {
                      final msg = compact
                          ? messages[messages.length -
                                math.min(3, messages.length).toInt() +
                                index]
                          : messages[messages.length - 1 - index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _avatar(msg, log),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg.senderName,
                                    style: TableStyle.detail.copyWith(
                                      color: TableStyle.ivory,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(msg.text, style: TableStyle.label),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat.Hm(
                                context.locale.toString(),
                              ).format(msg.timestamp),
                              style: TableStyle.detail.copyWith(fontSize: 10),
                            ),
                          ],
                        ),
                      );
                    },
                  );
            final children = <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      color: TableStyle.mint,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'table_chat_title'.tr(),
                        style: TableStyle.label.copyWith(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'close'.tr(),
                      onPressed: onClose,
                      icon: const Icon(Icons.close, color: TableStyle.muted),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      canType ? Icons.people_outline : Icons.lock_outline,
                      size: 15,
                      color: canType ? TableStyle.mint : TableStyle.brass,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        status.tr(),
                        style: TableStyle.detail.copyWith(
                          color: canType ? TableStyle.mint : TableStyle.brass,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    for (final item in ChatChannel.values) ...[
                      Expanded(
                        child: ChoiceChip(
                          label: Text(
                            (item == ChatChannel.game
                                    ? 'table_chat_game_log'
                                    : 'table_chat_room')
                                .tr(),
                          ),
                          selected: channel == item,
                          onSelected: (_) => onChannel(item),
                          selectedColor: TableStyle.mint.withValues(alpha: .25),
                          labelStyle: TableStyle.detail.copyWith(
                            color: TableStyle.ivory,
                          ),
                        ),
                      ),
                      if (item != ChatChannel.values.last)
                        const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              if (compact)
                history
              else
                Expanded(
                  child: Align(alignment: Alignment.topCenter, child: history),
                ),
              if (!log && !offline) ...[
                if (policy.catalog.items.isNotEmpty)
                  SizedBox(
                    height: 52,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      scrollDirection: Axis.horizontal,
                      itemCount: policy.catalog.items.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final phrase = policy.catalog.items[index];
                        return ActionChip(
                          label: Text(
                            phrase.label(context.locale.languageCode),
                          ),
                          labelStyle: TableStyle.detail.copyWith(
                            color: TableStyle.ivory,
                          ),
                          backgroundColor: TableStyle.ink,
                          onPressed: sending || !policy.available
                              ? null
                              : () => onQuick(phrase),
                        );
                      },
                    ),
                  ),
                if (!canType && !loading)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Text(
                      'table_chat_friends_hint'.tr(),
                      style: TableStyle.detail,
                    ),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            error!,
                            style: TableStyle.detail.copyWith(
                              color: TableStyle.red,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'retry'.tr(),
                          onPressed: sending ? null : onRetry,
                          icon: const Icon(
                            Icons.refresh,
                            color: TableStyle.mint,
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 6, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('table-chat-composer'),
                          controller: controller,
                          enabled: canType && !sending,
                          maxLength: 60,
                          maxLines: 1,
                          style: TableStyle.label,
                          onSubmitted: (_) => onSend(),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white10,
                            prefixIcon: canType
                                ? null
                                : const Icon(
                                    Icons.lock_outline,
                                    size: 18,
                                    color: TableStyle.muted,
                                  ),
                            hintText:
                                (canType
                                        ? 'table_chat_type'
                                        : 'table_chat_locked')
                                    .tr(),
                            hintStyle: TableStyle.detail,
                            counterText: '',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: const BorderSide(
                                color: Colors.white24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'table_chat_send'.tr(),
                        onPressed: canType && !sending ? onSend : null,
                        icon: sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                Icons.send_rounded,
                                color: canType
                                    ? TableStyle.mint
                                    : TableStyle.muted,
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ];
            return compact
                ? SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: children,
                    ),
                  )
                : Column(children: children);
          },
        ),
      ),
    );
  }
}
