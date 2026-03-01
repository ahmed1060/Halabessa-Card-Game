import 'package:flutter/material.dart';
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
  final _assetController = TextEditingController();
  final _priceController = TextEditingController(text: '0');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ThemeConfig.darkBg,
      title: Text('Add New ${widget.type.name}', style: const TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _idController,
              decoration: const InputDecoration(labelText: 'Item ID (unique)'),
              style: const TextStyle(color: Colors.white),
            ),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Display Name'),
              style: const TextStyle(color: Colors.white),
            ),
            TextField(
              controller: _assetController,
              decoration: const InputDecoration(labelText: 'Asset Path'),
              style: const TextStyle(color: Colors.white),
            ),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Price (Stars)'),
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
        ElevatedButton(
          onPressed: () {
            final id = _idController.text.trim();
            final name = _nameController.text.trim();
            final asset = _assetController.text.trim();
            final price = int.tryParse(_priceController.text) ?? 0;

            if (id.isEmpty || name.isEmpty || asset.isEmpty) return;

            final item = ShopItem(
              id: id,
              name: name,
              assetPath: asset,
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
}
