import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import '../providers/store_provider.dart';

class AdminAddItemDialog extends StatefulWidget {
  final ShopItemType type;

  const AdminAddItemDialog({super.key, required this.type});

  @override
  State<AdminAddItemDialog> createState() => _AdminAddItemDialogState();
}

class _AdminAddItemDialogState extends State<AdminAddItemDialog> {
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController(text: '0');
  
  String? _mainAssetUrl;
  String? _frontSkinUrl;
  String? _kingIllustUrl;
  
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndUpload(String fieldType) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isUploading = true);

      final storageRef = FirebaseStorage.instance.ref();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final itemRef = storageRef.child('store_items/${widget.type.name}/$fileName');

      late final TaskSnapshot uploadTask;
      if (kIsWeb) {
        uploadTask = await itemRef.putData(await image.readAsBytes());
      } else {
        uploadTask = await itemRef.putFile(File(image.path));
      }

      final downloadUrl = await uploadTask.ref.getDownloadURL();

      setState(() {
        if (fieldType == 'main') {
          _mainAssetUrl = downloadUrl;
        } else if (fieldType == 'front') {
          _frontSkinUrl = downloadUrl;
        } else if (fieldType == 'king') {
          _kingIllustUrl = downloadUrl;
        }
        _isUploading = false;
      });
    } catch (e) {
      debugPrint("Upload failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'))
        );
      }
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isSkin = widget.type == ShopItemType.cardBack;

    return AlertDialog(
      backgroundColor: ThemeConfig.darkBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('add_new_title'.tr(args: [widget.type.name]), 
        style: const TextStyle(color: Colors.white, fontFamily: ThemeConfig.fontHeading, fontSize: 18)
      ),
      content: SizedBox(
        width: 300,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(_idController, 'item_id_label'.tr(), Icons.fingerprint),
              const SizedBox(height: 12),
              _buildTextField(_nameController, 'display_name_label'.tr(), Icons.title),
              const SizedBox(height: 12),
              _buildTextField(_priceController, 'price_label'.tr(), Icons.stars, keyboardType: TextInputType.number),
              const SizedBox(height: 20),
              
              _buildUploadSection('Main Asset', _mainAssetUrl, () => _pickAndUpload('main')),
              
              if (isSkin) ...[
                const SizedBox(height: 12),
                _buildUploadSection('Front Skin (Opt)', _frontSkinUrl, () => _pickAndUpload('front')),
                const SizedBox(height: 12),
                _buildUploadSection('King Illust (Opt)', _kingIllustUrl, () => _pickAndUpload('king')),
              ],
              
              if (_isUploading)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: LinearProgressIndicator(color: ThemeConfig.primaryTeal),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.pop(context), 
          child: Text('cancel'.tr(), style: TextStyle(color: Colors.white.withOpacity(0.5)))
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: ThemeConfig.primaryTeal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isUploading || _mainAssetUrl == null ? null : () {
            final id = _idController.text.trim();
            final name = _nameController.text.trim();
            final price = int.tryParse(_priceController.text) ?? 0;

            if (id.isEmpty || name.isEmpty) return;

            Map<String, String>? faceIllusts;
            if (_kingIllustUrl != null) {
              faceIllusts = {'king': _kingIllustUrl!};
            }

            final item = ShopItem(
              id: id,
              name: name,
              assetPath: _mainAssetUrl!,
              frontSkinPath: _frontSkinUrl,
              faceIllustrations: faceIllusts,
              type: widget.type,
              price: price,
            );

            Navigator.pop(context, item);
          },
          child: Text('add'.tr()),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
        prefixIcon: Icon(icon, color: ThemeConfig.primaryTeal, size: 18),
        isDense: true,
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _buildUploadSection(String label, String? url, VoidCallback onPick) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        InkWell(
          onTap: _isUploading ? null : onPick,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: url != null ? ThemeConfig.primaryTeal : Colors.white10,
                width: 1,
              ),
            ),
            child: url != null 
              ? Row(
                  children: [
                    const SizedBox(width: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(url, height: 44, width: 44, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Image Uploaded', style: TextStyle(color: Colors.white70, fontSize: 12))),
                    const Icon(Icons.check_circle, color: ThemeConfig.primaryTeal, size: 20),
                    const SizedBox(width: 12),
                  ],
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, color: Colors.white.withOpacity(0.3), size: 24),
                      Text('Pick Image', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
                    ],
                  ),
                ),
          ),
        ),
      ],
    );
  }
}
