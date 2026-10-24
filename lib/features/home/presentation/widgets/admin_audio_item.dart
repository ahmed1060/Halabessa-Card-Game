import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:halabessa/core/providers/global_settings_provider.dart';
import 'package:halabessa/core/providers/settings_provider.dart';
import 'package:halabessa/core/services/admin_audio_preview_service.dart';
import 'package:halabessa/core/services/selected_audio_defaults.dart';
import 'package:halabessa/core/theme/theme_config.dart';

class AdminAudioItem extends ConsumerWidget {
  final String title, path, type;
  final VoidCallback onUpload;
  const AdminAudioItem({
    super.key,
    required this.title,
    required this.path,
    required this.type,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final global = ref.watch(globalSettingsProvider);
    final preview = ref.watch(adminAudioPreviewProvider);
    final url = switch (type) {
      'music' => global.musicOverrideUrl,
      'room_music' => global.roomMusicOverrideUrl,
      _ => global.sfxOverrides[path],
    };
    final backup = switch (type) {
      'music' => global.musicBackupUrl,
      'room_music' => global.roomMusicBackupUrl,
      _ => global.sfxBackups[path],
    };
    final custom = url != null && url.isNotEmpty;
    final saved = custom && url == backup;
    final playing = preview.isPlaying && preview.activePath == path;
    void error() {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('audio_action_failed'.tr())));
      }
    }

    Future<void> action(String value) async {
      try {
        await preview.stop();
        final notifier = ref.read(globalSettingsProvider.notifier);
        if (value == 'bundled') await notifier.restoreBundledAudio(path, type);
        if (value == 'saved') await notifier.clearOverride(path, type);
        if (value == 'mark') await notifier.markAsDefault(path, type);
      } catch (_) {
        error();
      }
    }

    return Container(
      key: ValueKey('audio-item-$path'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: custom
              ? ThemeConfig.goldAccent.withValues(alpha: .3)
              : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            (custom
                    ? (saved ? 'audio_saved_remote' : 'audio_custom')
                    : 'audio_selected_default')
                .tr(),
            style: TextStyle(
              color: custom ? ThemeConfig.goldAccent : const Color(0xFF78D2AF),
              fontSize: 13,
            ),
          ),
          if (!custom)
            Text(
              SelectedAudioDefaults.labels[path] ?? '',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                tooltip: (playing ? 'audio_stop_preview' : 'audio_play_preview')
                    .tr(),
                icon: Icon(
                  playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                ),
                onPressed: () async {
                  try {
                    if (playing) {
                      await preview.stop();
                      return;
                    }
                    final settings = ref.read(settingsProvider);
                    final music = type != 'sfx';
                    if (!(music
                        ? settings.isMusicEnabled
                        : settings.isSoundEnabled)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('audio_preview_muted'.tr())),
                      );
                      return;
                    }
                    await preview.play(
                      path,
                      overrideUrl: url,
                      volume: music
                          ? settings.musicVolume
                          : settings.soundVolume,
                    );
                  } catch (_) {
                    error();
                  }
                },
              ),
              IconButton(
                tooltip: 'audio_replace'.tr(),
                icon: const Icon(
                  Icons.upload_file_rounded,
                  color: ThemeConfig.goldAccent,
                ),
                onPressed: onUpload,
              ),
              if (custom)
                PopupMenuButton<String>(
                  tooltip: 'audio_default_actions'.tr(),
                  icon: const Icon(
                    Icons.settings_backup_restore_rounded,
                    color: Colors.white70,
                  ),
                  onSelected: action,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'bundled',
                      child: Text('audio_restore_selected'.tr()),
                    ),
                    if (backup != null)
                      PopupMenuItem(
                        value: 'saved',
                        child: Text('audio_restore_remote'.tr()),
                      ),
                    if (!saved)
                      PopupMenuItem(
                        value: 'mark',
                        child: Text('mark_as_default'.tr()),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
