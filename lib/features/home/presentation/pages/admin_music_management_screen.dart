import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:halabessa/core/providers/global_settings_provider.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import 'package:halabessa/core/services/multimedia_service.dart';

class AdminMusicManagementScreen extends ConsumerStatefulWidget {
  const AdminMusicManagementScreen({super.key});

  @override
  ConsumerState<AdminMusicManagementScreen> createState() => _AdminMusicManagementScreenState();
}

class _AdminMusicManagementScreenState extends ConsumerState<AdminMusicManagementScreen> {
  bool _isUploading = false;

  final List<Map<String, String>> _audioItems = [
    {'label': 'background_music', 'path': 'music/bg_music.mp3', 'type': 'music'},
  ];

  Future<void> _pickAndUpload(String assetPath, String type) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a'],
        withData: true, // Crucial for web and some mobile scenarios
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() => _isUploading = true);
        
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
        final storageRef = FirebaseStorage.instance.ref().child('audio/$fileName');
        
        final uploadTask = storageRef.putData(
          result.files.single.bytes!,
          SettableMetadata(contentType: 'audio/mpeg'),
        );
        
        // Use a timeout to prevent "forever loading"
        final snapshot = await uploadTask.timeout(const Duration(seconds: 30));
        final downloadUrl = await snapshot.ref.getDownloadURL();
        
        final currentSettings = ref.read(globalSettingsProvider);
        if (type == 'music') {
          await ref.read(globalSettingsProvider.notifier).updateSettings(
            currentSettings.copyWith(musicOverrideUrl: downloadUrl),
          );
        } else {
          final newSfx = Map<String, String>.from(currentSettings.sfxOverrides);
          newSfx[assetPath] = downloadUrl;
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
      if (e is FirebaseException) {
        errorMessage = 'Firebase Error: ${e.code} - ${e.message}';
      } else if (e is StateError) {
        errorMessage = 'Upload failed or timed out. Please try again.';
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
    final currentSettings = ref.read(globalSettingsProvider);
    if (type == 'music') {
      await ref.read(globalSettingsProvider.notifier).updateSettings(
        currentSettings.copyWith(musicOverrideUrl: null),
      );
    } else {
      final newSfx = Map<String, String>.from(currentSettings.sfxOverrides);
      newSfx.remove(assetPath);
      await ref.read(globalSettingsProvider.notifier).updateSettings(
        currentSettings.copyWith(sfxOverrides: newSfx),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final globalSettings = ref.watch(globalSettingsProvider);

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
                  : globalSettings.sfxOverrides.containsKey(assetPath);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isOverridden ? ThemeConfig.goldAccent.withOpacity(0.3) : Colors.white10),
                ),
                child: ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text(item['label']!.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(
                    isOverridden ? 'status_custom'.tr() : 'status_default'.tr(),
                    style: TextStyle(color: isOverridden ? ThemeConfig.goldAccent : Colors.white54, fontSize: 10),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        iconSize: 18,
                        icon: const Icon(Icons.play_arrow_rounded, color: Colors.white70),
                        onPressed: () {
                          if (type == 'music') {
                            ref.read(multimediaServiceProvider).playMusic(assetPath);
                          } else {
                            ref.read(multimediaServiceProvider).playSfx(assetPath);
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
