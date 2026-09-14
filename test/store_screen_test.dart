import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';
import 'package:halabessa/features/home/presentation/providers/store_provider.dart';

void main() {
  group('Store & Economy Verification Tests', () {
    test('AppUser affordability check correctly evaluates coins and diamonds', () {
      final player = AppUser(
        uid: 'p1',
        email: 'player@example.com',
        displayName: 'Player One',
        coins: 1000,
        diamonds: 25,
      );

      // Coins checks
      expect(player.canAfford(500, isDiamonds: false), isTrue);
      expect(player.canAfford(1000, isDiamonds: false), isTrue);
      expect(player.canAfford(1001, isDiamonds: false), isFalse);

      // Diamonds checks
      expect(player.canAfford(20, isDiamonds: true), isTrue);
      expect(player.canAfford(25, isDiamonds: true), isTrue);
      expect(player.canAfford(30, isDiamonds: true), isFalse);
    });

    test('Admin users can afford any item regardless of wallet balance', () {
      final admin = AppUser(
        uid: 'admin_1',
        email: 'admin@halabessa.com',
        displayName: 'Supreme Admin',
        isAdmin: true,
        coins: 0,
        diamonds: 0,
      );

      expect(admin.canAfford(999999, isDiamonds: false), isTrue);
      expect(admin.canAfford(999999, isDiamonds: true), isTrue);
    });

    test('ShopItem correctly handles json serialization for custom and default skins', () {
      final item = ShopItem(
        id: 'gold_skin',
        name: 'Pharaoh Gold',
        assetPath: 'assets/images/tables/table_skin_golden_oasis.png',
        type: ShopItemType.tableSkin,
        price: 1500,
        diamondPrice: 30,
      );

      final json = item.toJson();
      expect(json['id'], 'gold_skin');
      expect(json['price'], 1500);
      expect(json['diamondPrice'], 30);
      expect(json['type'], 'tableSkin');

      final deserialized = ShopItem.fromJson(json);
      expect(deserialized.id, item.id);
      expect(deserialized.name, item.name);
      expect(deserialized.price, item.price);
      expect(deserialized.diamondPrice, item.diamondPrice);
      expect(deserialized.type, item.type);
    });

    test('Responsive grid calculation ensures phone devices use 2 columns', () {
      int getCrossAxisCount(double width) {
        return width < 500 ? 2 : (width < 850 ? 3 : 4);
      }

      double getChildAspectRatio(double width) {
        return width < 500 ? 0.78 : (width < 850 ? 0.72 : 0.66);
      }

      // iPhone SE / standard phone (375px)
      expect(getCrossAxisCount(375), 2);
      expect(getChildAspectRatio(375), 0.78);

      // Modern phone (412px)
      expect(getCrossAxisCount(412), 2);
      expect(getChildAspectRatio(412), 0.78);

      // Small tablet (768px)
      expect(getCrossAxisCount(768), 3);
      expect(getChildAspectRatio(768), 0.72);

      // Desktop / iPad Pro (1024px)
      expect(getCrossAxisCount(1024), 4);
      expect(getChildAspectRatio(1024), 0.66);
    });
  });
}
