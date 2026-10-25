// Local-only social review fixture. Imported only by option_b_preview.dart.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:halabessa/features/game/domain/models/chat_message.dart';
import 'package:halabessa/features/game/domain/models/quick_chat_phrase.dart';
import 'package:halabessa/features/game/presentation/widgets/chat_overlay.dart';
import 'package:halabessa/features/game/presentation/widgets/table_style.dart';
import 'package:halabessa/features/home/presentation/pages/admin_quick_chat_screen.dart';

const reviewCatalog = QuickChatCatalog(
  items: [
    QuickChatPhrase(id: 'gg', en: 'GG!', ar: 'ماتش حلو!'),
    QuickChatPhrase(id: 'nice_play', en: 'Nice play!', ar: 'لعبة حلوة!'),
    QuickChatPhrase(id: 'your_turn', en: 'Your turn', ar: 'دورك'),
    QuickChatPhrase(id: 'halabessa', en: 'Halabessa!', ar: 'حلبسة!'),
    QuickChatPhrase(id: 'oops', en: 'Oops!', ar: 'يا نهار!'),
  ],
);
final reviewRoomMessages = StreamController<List<ChatMessage>>.broadcast();
final _messages = <ChatMessage>[
  ChatMessage(
    id: 'history_1',
    senderId: 'fixture_omar',
    senderName: 'Omar',
    text: 'Nice play!',
    timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
  ),
  ChatMessage(
    id: 'history_2',
    senderId: 'fixture_mariam',
    senderName: 'Mariam',
    text: 'Your turn',
    timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
  ),
];
Stream<List<ChatMessage>> socialReviewStream() async* {
  yield [..._messages];
  yield* reviewRoomMessages.stream;
}

class SocialReviewPanels extends StatefulWidget {
  const SocialReviewPanels({super.key, required this.mode, required this.uid});
  final String mode, uid;
  @override
  State<SocialReviewPanels> createState() => _SocialReviewPanelsState();
}

class _SocialReviewPanelsState extends State<SocialReviewPanels> {
  late String mode = widget.mode;
  final controller = TextEditingController();
  ChatChannel channel = ChatChannel.public;
  QuickChatCatalog catalog = reviewCatalog;
  bool open = true;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void send(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(
        ChatMessage(
          id: 'local_${DateTime.now().microsecondsSinceEpoch}',
          senderId: widget.uid,
          senderName: 'You',
          text: text.trim(),
          timestamp: DateTime.now(),
        ),
      );
    });
    reviewRoomMessages.add([..._messages]);
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context),
        insets = MediaQuery.viewInsetsOf(context);
    final available = math.max(0.0, size.height - insets.bottom - 90);
    return Stack(
      children: [
        Positioned(
          top: 8,
          left: 10,
          right: 10,
          child: Align(
            alignment: Alignment.topLeft,
            child: Wrap(
              spacing: 8,
              children: [
                for (final (id, label) in [
                  ('friends', 'Friends'),
                  ('locked', 'Locked'),
                  ('admin', 'Quick Chat manager'),
                ])
                  ActionChip(
                    label: Text(label),
                    onPressed: () => setState(() {
                      mode = id;
                      open = true;
                    }),
                  ),
              ],
            ),
          ),
        ),
        if (open && mode == 'admin')
          Positioned.fill(
            top: 64,
            child: Material(
              color: TableStyle.ink.withValues(alpha: .94),
              child: QuickChatManager(
                catalog: catalog,
                onChange: (body) async {
                  final rows = [...catalog.items];
                  final id = body['presetId'];
                  rows.removeWhere((p) => p.id == id);
                  if (body['operation'] == 'save') {
                    final phrase = body['phrase'] as Map;
                    rows.add(
                      QuickChatPhrase(
                        id: id as String,
                        en: phrase['en'] as String,
                        ar: phrase['ar'] as String,
                      ),
                    );
                  }
                  return catalog = QuickChatCatalog(
                    revision: catalog.revision + 1,
                    items: rows,
                  );
                },
              ),
            ),
          ),
        if (open && mode != 'admin')
          PositionedDirectional(
            start: 16,
            bottom: insets.bottom + 16,
            width: math.min(360.0, size.width - 32),
            height: math.min(
              size.width > size.height ? 340.0 : 460.0,
              available * .82,
            ),
            child: TableChatPanel(
              controller: controller,
              avatarUrls: const {
                'fixture_omar':
                    'assets/images/avatars/lantern_rival_man_v1.png',
                'fixture_mariam':
                    'assets/images/avatars/lantern_partner_v1.png',
              },
              channel: channel,
              policy: TableChatPolicy(
                available: true,
                canType: mode == 'friends',
                catalog: catalog,
              ),
              messages: channel == ChatChannel.game ? const [] : _messages,
              onClose: () => setState(() => open = false),
              onChannel: (value) => setState(() => channel = value),
              onSend: () => send(controller.text),
              onQuick: (p) => send(p.label(context.locale.languageCode)),
              onRetry: () {},
            ),
          ),
      ],
    );
  }
}
