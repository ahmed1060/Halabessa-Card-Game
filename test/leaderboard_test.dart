import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';

void main() {
  group('Leaderboard Sorting & Category Tests', () {
    final playerA = AppUser(
      uid: 'pA',
      email: 'a@test.com',
      displayName: 'Player A',
      points: 2500,
      wins: 30,
      bestScore: 45,
    );
    final playerB = AppUser(
      uid: 'pB',
      email: 'b@test.com',
      displayName: 'Player B',
      points: 1200,
      wins: 50,
      bestScore: 35,
    );
    final playerC = AppUser(
      uid: 'pC',
      email: 'c@test.com',
      displayName: 'Player C',
      points: 1800,
      wins: 20,
      bestScore: 65,
    );

    test('sorts descending by stars (points)', () {
      final list = [playerA, playerB, playerC];
      list.sort((a, b) => b.points.compareTo(a.points));

      expect(list[0].uid, 'pA'); // 2500
      expect(list[1].uid, 'pC'); // 1800
      expect(list[2].uid, 'pB'); // 1200
    });

    test('sorts descending by wins', () {
      final list = [playerA, playerB, playerC];
      list.sort((a, b) => b.wins.compareTo(a.wins));

      expect(list[0].uid, 'pB'); // 50
      expect(list[1].uid, 'pA'); // 30
      expect(list[2].uid, 'pC'); // 20
    });

    test('sorts descending by bestScore', () {
      final list = [playerA, playerB, playerC];
      list.sort((a, b) => b.bestScore.compareTo(a.bestScore));

      expect(list[0].uid, 'pC'); // 65
      expect(list[1].uid, 'pA'); // 45
      expect(list[2].uid, 'pB'); // 35
    });

    test('correctly identifies rank of a specific user', () {
      final list = [playerA, playerB, playerC];
      list.sort((a, b) => b.points.compareTo(a.points));

      final rankOfB = list.indexWhere((u) => u.uid == 'pB') + 1;
      expect(rankOfB, 3);
    });
  });
}
