import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/core/providers/settings_provider.dart';

enum ShopItemType { cardBack, tableSkin }

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

  static const _kOwnedIds = 'store_owned_ids';
  static const _kActiveCardBack = 'store_active_card_back';
  static const _kActiveTableSkin = 'store_active_table_skin';

  StoreNotifier(this._prefs) : super(StoreState(
    ownedIds: _prefs.getStringList(_kOwnedIds) ?? ['default_card', 'default_table'],
    activeCardBackId: _prefs.getString(_kActiveCardBack) ?? 'default_card',
    activeTableSkinId: _prefs.getString(_kActiveTableSkin) ?? 'default_table',
  ));

  void purchaseItem(String id) {
    if (!state.ownedIds.contains(id)) {
      final newOwned = [...state.ownedIds, id];
      state = state.copyWith(ownedIds: newOwned);
      _prefs.setStringList(_kOwnedIds, newOwned);
    }
  }

  void setActiveSkin(String id, ShopItemType type) {
    if (type == ShopItemType.cardBack) {
      state = state.copyWith(activeCardBackId: id);
      _prefs.setString(_kActiveCardBack, id);
    } else {
      state = state.copyWith(activeTableSkinId: id);
      _prefs.setString(_kActiveTableSkin, id);
    }
  }

  ShopItem get activeCardBack {
    return allItems.firstWhere((i) => i.id == state.activeCardBackId, orElse: () => allItems[0]);
  }

  ShopItem get activeTableSkin {
    return allItems.firstWhere((i) => i.id == state.activeTableSkinId, orElse: () => allItems[2]);
  }

  static final allItems = [
    ShopItem(
      id: 'default_card', 
      name: 'Classic Premium', 
      assetPath: 'assets/images/cards/premium/card_back_premium.png', 
      frontSkinPath: 'assets/images/cards/premium/card_front_premium_bg.png', 
      faceIllustrations: {'king': 'assets/images/cards/premium/card_face_premium.png'},
      type: ShopItemType.cardBack,
    ),
    ShopItem(
      id: 'neon_card', 
      name: 'Neon Cyber', 
      assetPath: 'assets/images/cards/neon/card_back_neon.png', 
      frontSkinPath: 'assets/images/cards/neon/card_front_neon_bg.png', 
      faceIllustrations: {'king': 'assets/images/cards/neon/card_face_neon.png'},
      type: ShopItemType.cardBack,
    ),
    ShopItem(
      id: 'royal_card', 
      name: 'Royal Velvet', 
      assetPath: 'assets/images/cards/royal/card_back_royal.png', 
      frontSkinPath: 'assets/images/cards/royal/card_front_royal_bg.png', 
      faceIllustrations: {
        'king': 'assets/images/cards/royal/card_face_royal.png',
        'queen': 'assets/images/cards/royal/card_face_royal_queen.png',
        'jack': 'assets/images/cards/royal/card_face_royal.png', // Fallback to king for now
      },
      type: ShopItemType.cardBack,
    ),
    
    ShopItem(id: 'default_table', name: 'Casino Felt', assetPath: 'assets/images/tables/table_skin_emerald.png', type: ShopItemType.tableSkin),
    ShopItem(id: 'galaxy_table', name: 'Cosmic Galaxy', assetPath: 'assets/images/tables/table_skin_galaxy.png', type: ShopItemType.tableSkin),
  ];
}

final storeProvider = StateNotifierProvider<StoreNotifier, StoreState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StoreNotifier(prefs);
});
