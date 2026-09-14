import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:halabessa/core/services/multimedia_service.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import '../../domain/providers/game_providers.dart';

class AhwaEmoteItem {
  final String emoji;
  final String titleKey;
  final Color accentColor;

  const AhwaEmoteItem({
    required this.emoji,
    required this.titleKey,
    required this.accentColor,
  });
}

class EmoteWheelOverlay extends ConsumerWidget {
  final String myUid;
  final VoidCallback onDismiss;

  const EmoteWheelOverlay({
    super.key,
    required this.myUid,
    required this.onDismiss,
  });

  static const List<AhwaEmoteItem> emotes = [
    AhwaEmoteItem(
      emoji: '👑',
      titleKey: 'emote_basra_master',
      accentColor: ThemeConfig.goldAccent,
    ),
    AhwaEmoteItem(
      emoji: '😎',
      titleKey: 'emote_who_are_you_kidding',
      accentColor: Color(0xFF64B5F6),
    ),
    AhwaEmoteItem(
      emoji: '🔥',
      titleKey: 'emote_oh_beauty',
      accentColor: Color(0xFFFF7043),
    ),
    AhwaEmoteItem(
      emoji: '💪',
      titleKey: 'emote_bring_it_on',
      accentColor: Color(0xFF81C784),
    ),
    AhwaEmoteItem(
      emoji: '😂',
      titleKey: 'emote_pure_comedy',
      accentColor: Color(0xFFFFD54F),
    ),
    AhwaEmoteItem(
      emoji: '🤔',
      titleKey: 'emote_what_plotting',
      accentColor: Color(0xFFBA68C8),
    ),
    AhwaEmoteItem(
      emoji: '😱',
      titleKey: 'emote_good_heavens',
      accentColor: Color(0xFFE57373),
    ),
    AhwaEmoteItem(
      emoji: '👋',
      titleKey: 'emote_peace_out',
      accentColor: Color(0xFF4DD0E1),
    ),
  ];

  void _selectEmote(BuildContext context, WidgetRef ref, AhwaEmoteItem item) {
    HapticFeedback.heavyImpact();
    ref.read(multimediaServiceProvider).playSfx('sfx/play.mp3');
    ref.read(matchStateProvider.notifier).sendEmoji(myUid, item.emoji);
    onDismiss();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 450;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: isCompact ? size.width * 0.92 : 400,
          decoration: BoxDecoration(
            color: const Color(0xFF1B263B).withOpacity(0.96),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: ThemeConfig.goldAccent.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: ThemeConfig.goldAccent.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('☕', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Text(
                        'emote_wheel_title'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: ThemeConfig.fontHeading,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white60),
                    onPressed: onDismiss,
                  ),
                ],
              ),

              const Divider(color: Colors.white12, height: 20),

              // 8-item Emote Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: emotes.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.7,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  final item = emotes[index];
                  return GestureDetector(
                    onTap: () => _selectEmote(context, ref, item),
                    child: Container(
                      decoration: BoxDecoration(
                        color: item.accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: item.accentColor.withOpacity(0.35),
                          width: 1.2,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Text(item.emoji, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.titleKey.tr(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.95),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
