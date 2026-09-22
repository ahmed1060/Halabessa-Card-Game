import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:halabessa/core/providers/global_settings_provider.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import 'package:halabessa/core/services/multimedia_service.dart';
import 'package:halabessa/core/services/supabase_backend_service.dart';

class AdminSfxManagementScreen extends ConsumerStatefulWidget {
  const AdminSfxManagementScreen({super.key});

  @override
  ConsumerState<AdminSfxManagementScreen> createState() => _AdminSfxManagementScreenState();
}

class _AdminSfxManagementScreenState extends ConsumerState<AdminSfxManagementScreen> {
  bool _isUploading = false;

  final List<Map<String, String>> _audioItems = [
    {'label': 'capture_sfx', 'path': 'sfx/capture.mp3', 'type': 'sfx'},
    {'label': 'deal_sfx', 'path': 'sfx/deal.mp3', 'type': 'sfx'},
    {'label': 'play_sfx', 'path': 'sfx/play.mp3', 'type': 'sfx'},
    {'label': 'shuffle_sfx', 'path': 'sfx/shuffle.mp3', 'type': 'sfx'},
    {'label': 'cut_sfx', 'path': 'sfx/cut.mp3', 'type': 'sfx'},
    {'label': 'win_sfx', 'path': 'sfx/win.mp3', 'type': 'sfx'},
    {'label': 'lose_sfx', 'path': 'sfx/lose.mp3', 'type': 'sfx'},
    {'label': 'purchase_sfx', 'path': 'sfx/purchase.mp3', 'type': 'sfx'},
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
          kind: 'sfx',
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
        title: Text('manage_sfx'.tr()),
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
                  : globalSettings.sfxOverrides.containsKey(assetPath);
              final isDefault = type == 'music'
                  ? globalSettings.musicOverrideUrl == globalSettings.musicBackupUrl && globalSettings.musicBackupUrl != null
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
                  ) : const Icon(Icons.volume_up_rounded, color: Colors.white24, size: 20),
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
                          (multimedia.sfxState == PlayerState.playing)
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white70,
                        ),
                        onPressed: () {
                          if (multimedia.sfxState == PlayerState.playing) {
                            multimedia.stopSfx();
                          } else {
                            multimedia.playSfx(assetPath);
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
