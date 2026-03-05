import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:halabessa/core/providers/settings_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/domain/models/app_user.dart';

enum ShopItemType { cardBack, tableSkin, consumable, avatar }

class ShopItem {
  final String id;
  final String name;
  final String assetPath;
  final String? frontSkinPath;
  final Map<String, String>? faceIllustrations; 
  final ShopItemType type;
  final int price;
  final int diamondPrice;
  final String? aceSkinPath;
  final String? sevenDiamondSkinPath;
  final Map<String, String>? suitIcons; 

  ShopItem({
    required this.id,
    required this.name,
    required this.assetPath,
    this.frontSkinPath,
    this.faceIllustrations,
    required this.type,
    this.price = 0,
    this.diamondPrice = 0,
    this.aceSkinPath,
    this.sevenDiamondSkinPath,
    this.suitIcons,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'assetPath': assetPath,
    'frontSkinPath': frontSkinPath,
    'faceIllustrations': faceIllustrations,
    'type': type.name,
    'price': price,
    'diamondPrice': diamondPrice,
    'aceSkinPath': aceSkinPath,
    'sevenDiamondSkinPath': sevenDiamondSkinPath,
    'suitIcons': suitIcons,
  };

  factory ShopItem.fromJson(Map<String, dynamic> json) => ShopItem(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    assetPath: json['assetPath'] ?? '',
    frontSkinPath: json['frontSkinPath'],
    faceIllustrations: json['faceIllustrations'] != null ? Map<String, String>.from(json['faceIllustrations']) : null,
    type: ShopItemType.values.firstWhere((e) => e.name == json['type'], orElse: () => ShopItemType.cardBack),
    price: json['price'] ?? 0,
    diamondPrice: json['diamondPrice'] ?? 0,
    aceSkinPath: json['aceSkinPath'],
    sevenDiamondSkinPath: json['sevenDiamondSkinPath'],
    suitIcons: json['suitIcons'] != null ? Map<String, String>.from(json['suitIcons']) : null,
  );
}

class StoreState {
  final List<String> ownedIds;
  final String activeCardBackId;
  final String activeTableSkinId;
  final List<ShopItem> extraItems;

  StoreState({
    required this.ownedIds,
    required this.activeCardBackId,
    required this.activeTableSkinId,
    this.extraItems = const [],
  });

  StoreState copyWith({
    List<String>? ownedIds,
    String? activeCardBackId,
    String? activeTableSkinId,
    List<ShopItem>? extraItems,
  }) {
    return StoreState(
      ownedIds: ownedIds ?? this.ownedIds,
      activeCardBackId: activeCardBackId ?? this.activeCardBackId,
      activeTableSkinId: activeTableSkinId ?? this.activeTableSkinId,
      extraItems: extraItems ?? this.extraItems,
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
    ownedIds: _prefs.getStringList(_kOwnedIds) ?? ['default_card', 'default_table', 'avatar_1'],
    activeCardBackId: _prefs.getString(_kActiveCardBack) ?? 'default_card',
    activeTableSkinId: _prefs.getString(_kActiveTableSkin) ?? 'default_table',
  )) {
    _initFirestoreSync();
  }

  void _initFirestoreSync() {
    // Sync Store Items from Settings
    FirebaseFirestore.instance.collection('settings').doc('store').snapshots().listen((doc) {
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['items'] is List) {
          final items = (data['items'] as List).map((i) => ShopItem.fromJson(Map<String, dynamic>.from(i))).toList();
          state = state.copyWith(extraItems: items);
        }
      }
    });

    // Sync Owned IDs from User Profile (Persistent Cloud Storage)
    _ref.listen<AppUser?>(currentUserProvider, (prev, next) {
      if (next != null) {
        final cloudOwned = next.ownedSkins;
        final localOwned = state.ownedIds;
        
        // Simple set-based comparison to see if we need to sync from cloud
        if (cloudOwned.isNotEmpty && 
            (cloudOwned.length != localOwned.length || 
             !cloudOwned.every((id) => localOwned.contains(id)))) {
          state = state.copyWith(ownedIds: cloudOwned);
          _prefs.setStringList(_kOwnedIds, cloudOwned);
        }
      }
    });
  }

  List<ShopItem> get allItems => [..._defaultItems, ...state.extraItems];

  Future<void> purchaseItem(ShopItem item) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    final isDiamonds = item.diamondPrice > 0;
    final price = isDiamonds ? item.diamondPrice : item.price;

    if (!user.canAfford(price, isDiamonds: isDiamonds)) {
      throw Exception(isDiamonds ? 'Not enough diamonds' : 'Not enough coins');
    }

    if (item.type == ShopItemType.consumable) {
       final currentCount = user.inventory[item.id] ?? 0;
       final newInventory = Map<String, int>.from(user.inventory);
       newInventory[item.id] = currentCount + 1;
       
       final cost = user.isAdmin ? 0 : price; 
       
       await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
         isDiamonds ? 'diamonds' : 'coins': (isDiamonds ? user.diamonds : user.coins) - cost,
         'inventory': newInventory,
       });
    } else {
      if (!state.ownedIds.contains(item.id)) {
        final newOwned = [...state.ownedIds, item.id];
        state = state.copyWith(ownedIds: newOwned);
        _prefs.setStringList(_kOwnedIds, newOwned);
        
        final cost = user.isAdmin ? 0 : price;
        
        // Persist to Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          isDiamonds ? 'diamonds' : 'coins': (isDiamonds ? user.diamonds : user.coins) - cost,
          'owned_skins': newOwned, 
        });
      }
    }
  }

  Future<void> updateItem(ShopItem updatedItem) async {
    final user = _ref.read(currentUserProvider);
    if (user == null || !user.isAdmin) return;

    final List<ShopItem> currentExtra = List.from(state.extraItems);
    final index = currentExtra.indexWhere((i) => i.id == updatedItem.id);
    
    if (index != -1) {
      currentExtra[index] = updatedItem;
    } else {
      currentExtra.add(updatedItem);
    }

    await FirebaseFirestore.instance.collection('settings').doc('store').set({
      'items': currentExtra.map((e) => e.toJson()).toList()
    });
  }

  Future<void> addItem(ShopItem item) async {
    final user = _ref.read(currentUserProvider);
    if (user == null || !user.isAdmin) return;
    
    await FirebaseFirestore.instance.collection('settings').doc('store').set({
      'items': FieldValue.arrayUnion([item.toJson()])
    }, SetOptions(merge: true));
  }

  Future<void> deleteItem(String id) async {
    final user = _ref.read(currentUserProvider);
    if (user == null || !user.isAdmin) return;

    final itemToDelete = state.extraItems.firstWhere((i) => i.id == id);
    await FirebaseFirestore.instance.collection('settings').doc('store').update({
      'items': FieldValue.arrayRemove([itemToDelete.toJson()])
    });
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

  static final _defaultItems = [
    ShopItem(
      id: 'default_card', 
      name: 'skin_premium'.tr(), 
      assetPath: 'assets/images/cards/premium/card_back_premium.png', 
      frontSkinPath: 'assets/images/cards/premium/card_front_premium_bg.png', 
      faceIllustrations: {
        'king': 'assets/images/cards/premium/card_face_premium.png',
        'queen': 'assets/images/cards/premium/card_face_premium_queen.png',
        'jack': 'assets/images/cards/premium/card_face_premium_jack.png',
      },
      aceSkinPath: 'assets/images/cards/premium/card_ace_premium.png',
      sevenDiamondSkinPath: 'assets/images/cards/premium/card_seven_premium.png',
      suitIcons: {
        'hearts': 'assets/images/cards/premium/suit_hearts.png',
        'diamonds': 'assets/images/cards/premium/suit_diamonds.png',
        'trifle': 'assets/images/cards/premium/suit_trifle.png',
        'spades': 'assets/images/cards/premium/suit_spades.png',
      },
      type: ShopItemType.cardBack,
      price: 0,
    ),
    ShopItem(
      id: 'neon_card', 
      name: 'skin_neon'.tr(), 
      assetPath: 'assets/images/cards/neon/card_back_neon.png', 
      frontSkinPath: 'assets/images/cards/neon/card_front_neon_bg.png', 
      faceIllustrations: {
        'king': 'assets/images/cards/neon/card_face_neon.png',
        'queen': 'assets/images/cards/neon/card_face_neon_queen.png',
        'jack': 'assets/images/cards/neon/card_face_neon_jack.png',
      },
      aceSkinPath: 'assets/images/cards/neon/card_ace_neon.png',
      sevenDiamondSkinPath: 'assets/images/cards/neon/card_seven_neon.png',
      suitIcons: {
        'hearts': 'assets/images/cards/neon/suit_hearts.png',
        'diamonds': 'assets/images/cards/neon/suit_diamonds.png',
        'trifle': 'assets/images/cards/neon/suit_trifle.png',
        'spades': 'assets/images/cards/neon/suit_spades.png',
      },
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
        'jack': 'assets/images/cards/royal/card_face_royal.png', // Fallback
      },
      sevenDiamondSkinPath: 'assets/images/cards/royal/card_seven_royal.png',
      suitIcons: {
        'hearts': 'assets/images/cards/royal/suit_hearts.png',
        'diamonds': 'assets/images/cards/royal/suit_diamonds.png',
        'trifle': 'assets/images/cards/royal/suit_trifle.png',
        'spades': 'assets/images/cards/royal/suit_spades.png',
      },
      type: ShopItemType.cardBack,
      price: 0,
    ),
    
    ShopItem(id: 'default_table', name: 'skin_casino'.tr(), assetPath: 'assets/images/tables/table_skin_emerald.png', type: ShopItemType.tableSkin, price: 0),
    ShopItem(id: 'galaxy_table', name: 'skin_galaxy'.tr(), assetPath: 'assets/images/tables/table_skin_galaxy.png', type: ShopItemType.tableSkin, price: 0),
    ShopItem(id: 'midnight_table', name: 'skin_midnight_cyber'.tr(), assetPath: 'assets/images/tables/table_skin_midnight_cyber.png', type: ShopItemType.tableSkin, price: 500),
    ShopItem(id: 'royal_velvet_table', name: 'skin_royal_velvet'.tr(), assetPath: 'assets/images/tables/table_skin_royal_velvet.png', type: ShopItemType.tableSkin, price: 1500, diamondPrice: 50),
    ShopItem(id: 'golden_oasis_table', name: 'skin_golden_oasis'.tr(), assetPath: 'assets/images/tables/table_skin_golden_oasis.png', type: ShopItemType.tableSkin, price: 1000, diamondPrice: 20),
    ShopItem(id: 'oceanic_depths_table', name: 'skin_oceanic_depths'.tr(), assetPath: 'assets/images/tables/table_skin_oceanic_depths.png', type: ShopItemType.tableSkin, price: 1200, diamondPrice: 25),
    ShopItem(id: 'ancient_marble_table', name: 'skin_ancient_marble'.tr(), assetPath: 'assets/images/tables/table_skin_ancient_marble.png', type: ShopItemType.tableSkin, price: 2000, diamondPrice: 60),
    
    ShopItem(
      id: 'username_change_ticket', 
      name: 'username_change_ticket'.tr(), 
      assetPath: 'assets/images/items/ticket.png', 
      type: ShopItemType.consumable,
      price: 500,
    ),
    
    // Default Avatars
    ShopItem(id: 'avatar_1', name: 'avatar_1'.tr(), assetPath: 'assets/images/avatars/avatar1.png', type: ShopItemType.avatar, price: 0),
    ShopItem(id: 'avatar_2', name: 'avatar_2'.tr(), assetPath: 'assets/images/avatars/avatar2.png', type: ShopItemType.avatar, price: 0),
    ShopItem(id: 'avatar_3', name: 'avatar_3'.tr(), assetPath: 'assets/images/avatars/avatar3.png', type: ShopItemType.avatar, price: 0),
    ShopItem(id: 'avatar_4', name: 'avatar_4'.tr(), assetPath: 'assets/images/avatars/avatar4.png', type: ShopItemType.avatar, price: 0),
    ShopItem(id: 'avatar_5', name: 'avatar_5'.tr(), assetPath: 'assets/images/avatars/avatar5.png', type: ShopItemType.avatar, price: 0),
    ShopItem(id: 'avatar_6', name: 'avatar_6'.tr(), assetPath: 'assets/images/avatars/avatar6.png', type: ShopItemType.avatar, price: 0),
  ];
}

final storeProvider = StateNotifierProvider<StoreNotifier, StoreState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StoreNotifier(prefs, ref);
});

final activeTableSkinProvider = Provider<ShopItem>((ref) {
  final store = ref.watch(storeProvider);
  return ref.watch(storeProvider.notifier).allItems.firstWhere((i) => i.id == store.activeTableSkinId, orElse: () => ref.watch(storeProvider.notifier).allItems[3]);
});

final activeCardBackProvider = Provider<ShopItem>((ref) {
  final store = ref.watch(storeProvider);
  return ref.watch(storeProvider.notifier).allItems.firstWhere((i) => i.id == store.activeCardBackId, orElse: () => ref.watch(storeProvider.notifier).allItems[0]);
});
