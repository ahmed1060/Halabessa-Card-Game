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
  final ShopItem? initialItem;

  const AdminAddItemDialog({super.key, required this.type, this.initialItem});

  @override
  State<AdminAddItemDialog> createState() => _AdminAddItemDialogState();
}

class _AdminAddItemDialogState extends State<AdminAddItemDialog> {
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _starPriceController = TextEditingController(text: '0');
  final _diamondPriceController = TextEditingController(text: '0');
  
  String? _mainAssetUrl;
  String? _frontSkinUrl;
  String? _kingIllustUrl;
  String? _queenIllustUrl;
  String? _jackIllustUrl;
  String? _aceSkinUrl;
  String? _sevenDiamondSkinUrl;
  
  Map<String, String> _suitIcons = {};
  
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.initialItem != null) {
      final item = widget.initialItem!;
      _idController.text = item.id;
      _nameController.text = item.name;
      _starPriceController.text = item.price.toString();
      _diamondPriceController.text = item.diamondPrice.toString();
      _mainAssetUrl = item.assetPath;
      _frontSkinUrl = item.frontSkinPath;
      _kingIllustUrl = item.faceIllustrations?['king'];
      _queenIllustUrl = item.faceIllustrations?['queen'];
      _jackIllustUrl = item.faceIllustrations?['jack'];
      _aceSkinUrl = item.aceSkinPath;
      _sevenDiamondSkinUrl = item.sevenDiamondSkinPath;
      _suitIcons = Map.from(item.suitIcons ?? {});
    }
  }

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
        } else if (fieldType == 'queen') {
          _queenIllustUrl = downloadUrl;
        } else if (fieldType == 'jack') {
          _jackIllustUrl = downloadUrl;
        } else if (fieldType == 'ace') {
          _aceSkinUrl = downloadUrl;
        } else if (fieldType == 'seven') {
          _sevenDiamondSkinUrl = downloadUrl;
        } else if (fieldType.startsWith('suit_')) {
          _suitIcons[fieldType.replaceFirst('suit_', '')] = downloadUrl;
        }
        _isUploading = false;
      });
    } catch (e) {
      debugPrint("Upload failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('upload_failed'.tr(args: [e.toString()])))
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
      title: Text(
        widget.initialItem != null ? 'edit_item'.tr() : 'add_new_title'.tr(args: [widget.type.name]), 
        style: const TextStyle(color: Colors.white, fontFamily: ThemeConfig.fontHeading, fontSize: 18)
      ),
      content: SizedBox(
        width: 300,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.initialItem != null)
                _buildTextField(_idController, 'item_id_label'.tr(), Icons.fingerprint, enabled: false),
              if (widget.initialItem != null) const SizedBox(height: 12),
              const SizedBox(height: 12),
              _buildTextField(_nameController, 'display_name_label'.tr(), Icons.title),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildTextField(_starPriceController, 'coins'.tr(), Icons.monetization_on, keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTextField(_diamondPriceController, 'diamonds'.tr(), Icons.diamond, keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 20),
              
              _buildUploadSection('display_name_label'.tr(), _mainAssetUrl, () => _pickAndUpload('main')),
              
              if (isSkin) ...[
                const SizedBox(height: 12),
                _buildUploadSection('Front Skin (Opt)', _frontSkinUrl, () => _pickAndUpload('front')),
                const SizedBox(height: 12),
                _buildUploadSection('King Illust (Opt)', _kingIllustUrl, () => _pickAndUpload('king')),
                const SizedBox(height: 12),
                _buildUploadSection('Queen Illust (Opt)', _queenIllustUrl, () => _pickAndUpload('queen')),
                const SizedBox(height: 12),
                _buildUploadSection('Jack Illust (Opt)', _jackIllustUrl, () => _pickAndUpload('jack')),
                const SizedBox(height: 12),
                _buildUploadSection('Ace Skin (Opt)', _aceSkinUrl, () => _pickAndUpload('ace')),
                const SizedBox(height: 12),
                _buildUploadSection('7-Diamond Skin (Opt)', _sevenDiamondSkinUrl, () => _pickAndUpload('seven')),
                const SizedBox(height: 20),
                Text('suit_icons'.tr(), style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildUploadSection('Hearts', _suitIcons['hearts'], () => _pickAndUpload('suit_hearts'), mini: true)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildUploadSection('Diamonds', _suitIcons['diamonds'], () => _pickAndUpload('suit_diamonds'), mini: true)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildUploadSection('Trifle', _suitIcons['trifle'], () => _pickAndUpload('suit_trifle'), mini: true)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildUploadSection('Spades', _suitIcons['spades'], () => _pickAndUpload('suit_spades'), mini: true)),
                  ],
                ),
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
            Map<String, String>? faceIllusts;
            if (_kingIllustUrl != null || _queenIllustUrl != null || _jackIllustUrl != null) {
              faceIllusts = {};
              if (_kingIllustUrl != null) faceIllusts['king'] = _kingIllustUrl!;
              if (_queenIllustUrl != null) faceIllusts['queen'] = _queenIllustUrl!;
              if (_jackIllustUrl != null) faceIllusts['jack'] = _jackIllustUrl!;
            }

            String id = widget.initialItem?.id ?? _idController.text.trim();
            if (id.isEmpty) {
              id = 'item_${DateTime.now().millisecondsSinceEpoch}';
            }

            final item = ShopItem(
              id: id,
              name: _nameController.text.trim(),
              assetPath: _mainAssetUrl!,
              frontSkinPath: _frontSkinUrl,
              faceIllustrations: faceIllusts,
              type: widget.type,
              price: int.tryParse(_starPriceController.text) ?? 0,
              diamondPrice: int.tryParse(_diamondPriceController.text) ?? 0,
              aceSkinPath: _aceSkinUrl,
              sevenDiamondSkinPath: _sevenDiamondSkinUrl,
              suitIcons: _suitIcons.isEmpty ? null : _suitIcons,
            );

            Navigator.pop(context, item);
          },
          child: Text(widget.initialItem != null ? 'update_item'.tr() : 'add'.tr()),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType keyboardType = TextInputType.text, bool enabled = true}) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      style: TextStyle(color: enabled ? Colors.white : Colors.white30, fontSize: 14),
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

  Widget _buildUploadSection(String label, String? url, VoidCallback onPick, {bool mini = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        InkWell(
          onTap: _isUploading ? null : onPick,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: mini ? 40 : 60,
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
                      child: url.startsWith('http')
                        ? Image.network(url, height: mini ? 24 : 44, width: mini ? 24 : 44, fit: BoxFit.cover)
                        : Image.asset(url, height: mini ? 24 : 44, width: mini ? 24 : 44, fit: BoxFit.cover),
                    ),
                    if (!mini) ...[
                      const SizedBox(width: 12),
                      Expanded(child: Text('image_uploaded'.tr(), style: const TextStyle(color: Colors.white70, fontSize: 12))),
                      const Icon(Icons.check_circle, color: ThemeConfig.primaryTeal, size: 20),
                      const SizedBox(width: 12),
                    ] else
                      const Expanded(child: Center(child: Icon(Icons.check_circle, color: ThemeConfig.primaryTeal, size: 16))),
                  ],
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, color: Colors.white.withOpacity(0.3), size: mini ? 18 : 24),
                      if (!mini) Text('pick_image'.tr(), style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
                    ],
                  ),
                ),
          ),
        ),
      ],
    );
  }
}
