import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import '../widgets/admin_audio_item.dart';
import 'package:halabessa/core/services/admin_audio_upload_service.dart';

class AdminSfxManagementScreen extends ConsumerStatefulWidget {
  const AdminSfxManagementScreen({super.key});

  @override
  ConsumerState<AdminSfxManagementScreen> createState() =>
      _AdminSfxManagementScreenState();
}

class _AdminSfxManagementScreenState
    extends ConsumerState<AdminSfxManagementScreen> {
  bool _isUploading = false;

  final List<Map<String, String>> _audioItems = [
    {'label': 'capture_sfx', 'path': 'sfx/capture.mp3', 'type': 'sfx'},
    {'label': 'deal_sfx', 'path': 'sfx/deal.mp3', 'type': 'sfx'},
    {'label': 'play_sfx', 'path': 'sfx/play.mp3', 'type': 'sfx'},
    {'label': 'pick_sfx', 'path': 'sfx/pick.mp3', 'type': 'sfx'},
    {'label': 'return_sfx', 'path': 'sfx/return.mp3', 'type': 'sfx'},
    {'label': 'reveal_sfx', 'path': 'sfx/reveal.mp3', 'type': 'sfx'},
    {'label': 'slam_0_sfx', 'path': 'sfx/slam_0.mp3', 'type': 'sfx'},
    {'label': 'slam_1_sfx', 'path': 'sfx/slam_1.mp3', 'type': 'sfx'},
    {'label': 'slam_2_sfx', 'path': 'sfx/slam_2.mp3', 'type': 'sfx'},
    {'label': 'shuffle_sfx', 'path': 'sfx/shuffle.mp3', 'type': 'sfx'},
    {'label': 'cut_sfx', 'path': 'sfx/cut.mp3', 'type': 'sfx'},
    {'label': 'win_sfx', 'path': 'sfx/win.mp3', 'type': 'sfx'},
    {'label': 'lose_sfx', 'path': 'sfx/lose.mp3', 'type': 'sfx'},
    {'label': 'purchase_sfx', 'path': 'sfx/purchase.mp3', 'type': 'sfx'},
  ];

  Future<void> _pickAndUpload(String assetPath, String type) async {
    if (_isUploading) return;
    setState(() => _isUploading = true);
    try {
      final result = await ref.read(adminAudioFilePickerProvider)();
      if (!mounted) return;

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;

        if (bytes.length > 4 * 1024 * 1024) {
          throw Exception('file_too_large');
        }

        final extension = result.files.single.extension ?? 'mp3';
        final mimeType = switch (extension.toLowerCase()) {
          'wav' => 'audio/wav',
          'm4a' => 'audio/mp4',
          _ => 'audio/mpeg',
        };
        await ref
            .read(adminAudioUploadProvider)
            .replace(
              path: assetPath,
              type: type,
              fileName: result.files.single.name,
              contentType: mimeType,
              bytes: bytes,
            );

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('upload_success'.tr())));
        }
      }
    } catch (e) {
      debugPrint('Error uploading audio: $e');
      String errorMessage = e.toString();

      if (errorMessage.contains('file_too_large')) {
        errorMessage =
            'File too large (max 4 MB). Please compress the audio first.';
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

  @override
  Widget build(BuildContext context) {
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
              return AdminAudioItem(
                title: item['label']!,
                path: assetPath,
                type: type,
                onUpload: () => _pickAndUpload(assetPath, type),
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
