import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import '../providers/auth_providers.dart';
import '../../../home/presentation/providers/store_provider.dart';

class AvatarPicker extends ConsumerStatefulWidget {
  const AvatarPicker({super.key});

  @override
  ConsumerState<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends ConsumerState<AvatarPicker> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;


  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      final user = ref.read(currentUserProvider);
      if (user == null) return;

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('avatars')
          .child('${user.uid}.jpg');

      await storageRef.putData(await image.readAsBytes());
      final downloadUrl = await storageRef.getDownloadURL();

      await ref.read(authRepositoryProvider).updateProfile(avatarUrl: downloadUrl);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('profile_updated_success'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_general'.tr(args: [e.toString()]))),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _selectBuiltIn(String assetPath) async {
    try {
      await ref.read(authRepositoryProvider).updateProfile(avatarUrl: assetPath);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('profile_updated_success'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_general'.tr(args: [e.toString()]))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarItems = ref.watch(storeProvider.notifier).allItems
        .where((i) => i.type == ShopItemType.avatar)
        .toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: ThemeConfig.darkBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'choose_avatar_title'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: ThemeConfig.fontHeading,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 240, // Fixed height for the grid
            child: GridView.builder(
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: avatarItems.length,
              itemBuilder: (context, index) {
                final item = avatarItems[index];
                return GestureDetector(
                  onTap: () => _selectBuiltIn(item.assetPath),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ClipOval(
                      child: item.assetPath.startsWith('http')
                        ? Image.network(
                            item.assetPath,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: ThemeConfig.cardDarkBg,
                              child: const Icon(Icons.person, color: ThemeConfig.goldAccent, size: 36),
                            ),
                          )
                        : Image.asset(
                            item.assetPath,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: ThemeConfig.cardDarkBg,
                              child: const Icon(Icons.person, color: ThemeConfig.goldAccent, size: 36),
                            ),
                          ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _isUploading ? null : _pickAndUploadImage,
            icon: _isUploading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(_isUploading ? 'loading'.tr() : 'upload_custom_avatar'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeConfig.primaryTeal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr(), style: const TextStyle(color: Colors.white54)),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}
