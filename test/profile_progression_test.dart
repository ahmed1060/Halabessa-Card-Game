import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';

void main() {
  group('Profile Progression & Level Tests', () {
    test('standard user level scales per 1,000 points', () {
      final userLevel1 = AppUser(
        uid: 'u1',
        email: 'test@example.com',
        displayName: 'Player 1',
        points: 450,
      );
      expect(userLevel1.level, 1);

      final userLevel2 = AppUser(
        uid: 'u2',
        email: 'test@example.com',
        displayName: 'Player 2',
        points: 1000,
      );
      expect(userLevel2.level, 2);

      final userLevel5 = AppUser(
        uid: 'u3',
        email: 'test@example.com',
        displayName: 'Player 3',
        points: 4800,
      );
      expect(userLevel5.level, 5);
    });

    test('admin always has max level 999', () {
      final admin = AppUser(
        uid: 'admin_1',
        email: 'admin@halabessa.com',
        displayName: 'Grand Admin',
        isAdmin: true,
        points: 0,
      );
      expect(admin.level, 999);
    });

    test('win rate calculation handles 0 games safely and calculates correctly', () {
      final newUser = AppUser(
        uid: 'newbie',
        email: 'newbie@test.com',
        displayName: 'Newbie',
        gamesPlayed: 0,
        wins: 0,
      );
      expect(newUser.winRate, 0.0);

      final veteran = AppUser(
        uid: 'vet',
        email: 'vet@test.com',
        displayName: 'Veteran',
        gamesPlayed: 20,
        wins: 15,
      );
      expect(veteran.winRate, 0.75);
    });
  });
}
