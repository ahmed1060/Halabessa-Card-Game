import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:halabessa/core/providers/global_settings_provider.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import 'package:halabessa/core/services/multimedia_service.dart';
import 'package:halabessa/core/services/supabase_backend_service.dart';

class AdminMusicManagementScreen extends ConsumerStatefulWidget {
  const AdminMusicManagementScreen({super.key});

  @override
  ConsumerState<AdminMusicManagementScreen> createState() => _AdminMusicManagementScreenState();
}

class _AdminMusicManagementScreenState extends ConsumerState<AdminMusicManagementScreen> {
  bool _isUploading = false;

  final List<Map<String, String>> _audioItems = [
    {'label': 'background_music', 'path': 'music/bg_music.mp3', 'type': 'music'},
    {'label': 'room_music', 'path': 'music/room_music.mp3', 'type': 'room_music'},
  ];

  Future<void> _pickAndUpload(String assetPath, String type) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        
        if (bytes.length > 4 * 1024 * 1024) {
          throw Exception('file_too_large');
        }

        setState(() => _isUploading = true);
        
        final extension = result.files.single.extension ?? 'mp3';
        final mimeType = switch (extension.toLowerCase()) {
          'wav' => 'audio/wav',
          'm4a' => 'audio/mp4',
          _ => 'audio/mpeg',
        };
        final publicUrl = await SupabaseBackendService.uploadAsset(
          kind: 'music',
          fileName: result.files.single.name,
          contentType: mimeType,
          bytes: bytes,
          assetKey: assetPath,
        );
        
        final currentSettings = ref.read(globalSettingsProvider);
        if (type == 'music') {
          await ref.read(globalSettingsProvider.notifier).updateSettings(
            currentSettings.copyWith(musicOverrideUrl: publicUrl),
          );
        } else if (type == 'room_music') {
          await ref.read(globalSettingsProvider.notifier).updateSettings(
            currentSettings.copyWith(roomMusicOverrideUrl: publicUrl),
          );
        } else {
          final newSfx = Map<String, String>.from(currentSettings.sfxOverrides);
          newSfx[assetPath] = publicUrl;
          await ref.read(globalSettingsProvider.notifier).updateSettings(
            currentSettings.copyWith(sfxOverrides: newSfx),
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('upload_success'.tr())),
          );
        }
      }
    } catch (e) {
      debugPrint('Error uploading audio: $e');
      String errorMessage = e.toString();
      
      if (errorMessage.contains('file_too_large')) {
        errorMessage = 'File too large (max 4 MB). Please compress the audio first.';
      } else if (e is StateError) {
        errorMessage = 'Upload failed. Please try again.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('upload_failed'.tr(args: [errorMessage])),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _resetToDefault(String assetPath, String type) async {
    final success = await ref.read(globalSettingsProvider.notifier).clearOverride(assetPath, type);
    
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('no_default_yet'.tr()),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final globalSettings = ref.watch(globalSettingsProvider);
    final multimedia = ref.watch(multimediaServiceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: Text('manage_music'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _audioItems.length,
            itemBuilder: (context, index) {
              final item = _audioItems[index];
              final assetPath = item['path']!;
              final type = item['type']!;
              final isOverridden = type == 'music' 
                  ? globalSettings.musicOverrideUrl != null 
                  : type == 'room_music'
                      ? globalSettings.roomMusicOverrideUrl != null
                      : globalSettings.sfxOverrides.containsKey(assetPath);
              final isDefault = type == 'music'
                  ? globalSettings.musicOverrideUrl == globalSettings.musicBackupUrl && globalSettings.musicBackupUrl != null
                  : type == 'room_music'
                      ? globalSettings.roomMusicOverrideUrl == globalSettings.roomMusicBackupUrl && globalSettings.roomMusicBackupUrl != null
                      : globalSettings.sfxOverrides[assetPath] == globalSettings.sfxBackups[assetPath] && globalSettings.sfxBackups.containsKey(assetPath);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isOverridden ? ThemeConfig.goldAccent.withOpacity(0.3) : Colors.white10),
                ),
                child: ListTile(
                  leading: isOverridden ? IconButton(
                    iconSize: 20,
                    tooltip: isDefault ? 'is_default_label'.tr() : 'mark_as_default'.tr(),
                    icon: Icon(
                      isDefault ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: isDefault ? ThemeConfig.goldAccent : Colors.blueAccent,
                    ),
                    onPressed: isDefault ? null : () => ref.read(globalSettingsProvider.notifier).markAsDefault(assetPath, type),
                  ) : const Icon(Icons.audiotrack_rounded, color: Colors.white24, size: 20),
                  title: Text(item['label']!.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Row(
                    children: [
                      Text(
                        isOverridden ? 'status_custom'.tr() : 'no_sound_set'.tr(),
                        style: TextStyle(color: isOverridden ? ThemeConfig.goldAccent : Colors.white24, fontSize: 10),
                      ),
                      if (isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: ThemeConfig.goldAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'is_default_label'.tr(),
                            style: const TextStyle(color: ThemeConfig.goldAccent, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        iconSize: 18,
                        icon: Icon(
                          (multimedia.currentMusicPath == assetPath && multimedia.musicState == PlayerState.playing)
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white70,
                        ),
                        onPressed: () {
                          if (multimedia.currentMusicPath == assetPath && multimedia.musicState == PlayerState.playing) {
                            multimedia.stopMusic();
                          } else {
                            if (type == 'music') {
                              multimedia.playMusic(assetPath, loop: false);
                            } else if (type == 'room_music') {
                              multimedia.playRoomMusic(assetPath, loop: false);
                            }
                          }
                        },
                      ),
                      IconButton(
                        iconSize: 18,
                        icon: const Icon(Icons.upload_file_rounded, color: ThemeConfig.goldAccent),
                        onPressed: () => _pickAndUpload(assetPath, type),
                      ),
                      if (isOverridden)
                        IconButton(
                          iconSize: 18,
                          icon: const Icon(Icons.history_rounded, color: Colors.redAccent),
                          onPressed: () => _resetToDefault(assetPath, type),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (_isUploading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: ThemeConfig.goldAccent),
              ),
            ),
        ],
      ),
    );
  }
}
