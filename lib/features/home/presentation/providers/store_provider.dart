import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:halabessa/core/providers/settings_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

enum ShopItemType { cardBack, tableSkin, consumable }

class ShopItem {
  final String id;
  final String name;
  final String assetPath;
  final String? frontSkinPath;
  final Map<String, String>? faceIllustrations; // e.g. {'jack': '...', 'queen': '...', 'king': '...'}
  final ShopItemType type;
  final int price;

  ShopItem({
    required this.id,
    required this.name,
    required this.assetPath,
    this.frontSkinPath,
    this.faceIllustrations,
    required this.type,
    this.price = 0,
  });
}

class StoreState {
  final List<String> ownedIds;
  final String activeCardBackId;
  final String activeTableSkinId;

  StoreState({
    required this.ownedIds,
    required this.activeCardBackId,
    required this.activeTableSkinId,
  });

  StoreState copyWith({
    List<String>? ownedIds,
    String? activeCardBackId,
    String? activeTableSkinId,
  }) {
    return StoreState(
      ownedIds: ownedIds ?? this.ownedIds,
      activeCardBackId: activeCardBackId ?? this.activeCardBackId,
      activeTableSkinId: activeTableSkinId ?? this.activeTableSkinId,
    );
  }
}

class StoreNotifier extends StateNotifier<StoreState> {
  final SharedPreferences _prefs;
  final Ref _ref;

  static const _kOwnedIds = 'store_owned_ids';
  static const _kActiveCardBack = 'store_active_card_back';
  static const _kActiveTableSkin = 'store_active_table_skin';

  StoreNotifier(this._prefs, this._ref) : super(StoreState(
    ownedIds: _prefs.getStringList(_kOwnedIds) ?? ['default_card', 'default_table'],
    activeCardBackId: _prefs.getString(_kActiveCardBack) ?? 'default_card',
    activeTableSkinId: _prefs.getString(_kActiveTableSkin) ?? 'default_table',
  ));

  Future<void> purchaseItem(ShopItem item) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    // Admin bypass or free items (all items are free for now as requested)
    if (!user.isAdmin && item.price > 0 && user.points < item.price) {
      throw Exception('Not enough points');
    }

    if (item.type == ShopItemType.consumable) {
       // Consumables are tracked in AppUser.inventory (Firestore)
       final currentCount = user.inventory[item.id] ?? 0;
       final newInventory = Map<String, int>.from(user.inventory);
       newInventory[item.id] = currentCount + 1;
       
       final pointsToDeduct = user.isAdmin ? 0 : item.price;
       
       await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
         'points': user.points - pointsToDeduct,
         'inventory': newInventory,
       });
    } else {
      if (!state.ownedIds.contains(item.id)) {
        final newOwned = [...state.ownedIds, item.id];
        state = state.copyWith(ownedIds: newOwned);
        _prefs.setStringList(_kOwnedIds, newOwned);
        
        // Deduct points if regular user
        if (!user.isAdmin && item.price > 0) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'points': user.points - item.price,
          });
        }
      }
    }
  }

  Future<void> addItem(ShopItem item) async {
    final user = _ref.read(currentUserProvider);
    if (user == null || !user.isAdmin) return;
    
    // In a real app, we'd add to Firestore 'store_items' collection.
    // For now, we'll append to the local list and could save to a global settings doc.
    await FirebaseFirestore.instance.collection('settings').doc('store').update({
      'items': FieldValue.arrayUnion([
        {
          'id': item.id,
          'name': item.name,
          'assetPath': item.assetPath,
          'type': item.type.toString().split('.').last,
          'price': item.price,
        }
      ])
    });
  }

  Future<void> deleteItem(String id) async {
    final user = _ref.read(currentUserProvider);
    if (user == null || !user.isAdmin) return;

    // Logic to remove item from Firestore
    // For now, we'll just show the UI for it.
  }

  void setActiveSkin(String id, ShopItemType type) {
    if (type == ShopItemType.cardBack) {
      state = state.copyWith(activeCardBackId: id);
      _prefs.setString(_kActiveCardBack, id);
    } else if (type == ShopItemType.tableSkin) {
      state = state.copyWith(activeTableSkinId: id);
      _prefs.setString(_kActiveTableSkin, id);
    }
  }

  ShopItem get activeCardBack {
    return allItems.firstWhere((i) => i.id == state.activeCardBackId, orElse: () => allItems[0]);
  }

  ShopItem get activeTableSkin {
    return allItems.firstWhere((i) => i.id == state.activeTableSkinId, orElse: () => allItems[3]);
  }

  static final allItems = [
    ShopItem(
      id: 'default_card', 
      name: 'skin_premium'.tr(), 
      assetPath: 'assets/images/cards/premium/card_back_premium.png', 
      frontSkinPath: 'assets/images/cards/premium/card_front_premium_bg.png', 
      faceIllustrations: {'king': 'assets/images/cards/premium/card_face_premium.png'},
      type: ShopItemType.cardBack,
      price: 0,
    ),
    ShopItem(
      id: 'neon_card', 
      name: 'skin_neon'.tr(), 
      assetPath: 'assets/images/cards/neon/card_back_neon.png', 
      frontSkinPath: 'assets/images/cards/neon/card_front_neon_bg.png', 
      faceIllustrations: {'king': 'assets/images/cards/neon/card_face_neon.png'},
      type: ShopItemType.cardBack,
      price: 0,
    ),
    ShopItem(
      id: 'royal_card', 
      name: 'skin_royal'.tr(), 
      assetPath: 'assets/images/cards/royal/card_back_royal.png', 
      frontSkinPath: 'assets/images/cards/royal/card_front_royal_bg.png', 
      faceIllustrations: {
        'king': 'assets/images/cards/royal/card_face_royal.png',
        'queen': 'assets/images/cards/royal/card_face_royal_queen.png',
        'jack': 'assets/images/cards/royal/card_face_royal.png', // Fallback to king for now
      },
      type: ShopItemType.cardBack,
      price: 0,
    ),
    
    ShopItem(id: 'default_table', name: 'skin_casino'.tr(), assetPath: 'assets/images/tables/table_skin_emerald.png', type: ShopItemType.tableSkin, price: 0),
    ShopItem(id: 'galaxy_table', name: 'skin_galaxy'.tr(), assetPath: 'assets/images/tables/table_skin_galaxy.png', type: ShopItemType.tableSkin, price: 0),
    
    ShopItem(
      id: 'name_change_ticket', 
      name: 'name_change_ticket'.tr(), 
      assetPath: 'assets/images/items/ticket.png', 
      type: ShopItemType.consumable,
      price: 0,
    ),
  ];
}

final storeProvider = StateNotifierProvider<StoreNotifier, StoreState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StoreNotifier(prefs, ref);
});
