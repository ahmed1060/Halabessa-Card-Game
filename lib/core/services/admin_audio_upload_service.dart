import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/global_settings_provider.dart';
import 'audio_override_store.dart';
import 'supabase_backend_service.dart';

typedef AudioAssetUpload =
    Future<String> Function({
      required String kind,
      required String fileName,
      required String contentType,
      required Uint8List bytes,
      String? assetKey,
    });
typedef AudioOverrideSave =
    Future<void> Function(String path, String type, String url);

// Keep OS file picking separate from cloud writes so the complete screen flow
// can be exercised locally without opening dialogs or contacting a real account.
final adminAudioFilePickerProvider =
    Provider<Future<FilePickerResult?> Function()>(
      (ref) =>
          () => FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['mp3', 'wav', 'm4a'],
            withData: true,
          ),
    );

/// Upload first; publish a field-specific override only after storage succeeds.
/// Failed config saves leave an unreferenced immutable file, not a broken default.
class AdminAudioUploadService {
  final AudioAssetUpload upload;
  final AudioOverrideSave save;
  AdminAudioUploadService({required this.upload, required this.save});
  Future<void> replace({
    required String path,
    required String type,
    required String fileName,
    required String contentType,
    required Uint8List bytes,
  }) async {
    audioDocumentId(path, type); // Validate before any external write.
    if (!['audio/wav', 'audio/mpeg', 'audio/mp4'].contains(contentType) ||
        bytes.isEmpty ||
        bytes.length > 4 * 1024 * 1024) {
      throw ArgumentError('invalid_asset');
    }
    final url = await upload(
      kind: type == 'sfx' ? 'sfx' : 'music',
      fileName: fileName,
      contentType: contentType,
      bytes: bytes,
      assetKey: path,
    );
    await save(path, type, url);
  }
}

final adminAudioUploadProvider = Provider<AdminAudioUploadService>(
  (ref) => AdminAudioUploadService(
    upload: SupabaseBackendService.uploadAsset,
    save: (path, type, url) => ref
        .read(globalSettingsProvider.notifier)
        .updateAudioOverride(path, type, url),
  ),
);
