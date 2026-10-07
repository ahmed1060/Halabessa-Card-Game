import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_backend_service.dart';

import '../../domain/models/app_user.dart';
import '../../domain/models/ranking_period.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/firebase_auth_repository.dart';

// 1. Provides the FirebaseAuth instance
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

// 2. Provides the AuthRepository implementation
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository(ref.watch(firebaseAuthProvider));
});

// 3. Streams the User Authentication State
final authStateChangesProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// 4. Provides the current logged in user directly if available
final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authStateChangesProvider).value;
});

// 5. Discovery receives the server's allowlisted public view, never email/wallets.
final userProfileProvider = FutureProvider.family<AppUser?, String>((
  ref,
  uid,
) async {
  final result = await SupabaseBackendService.call(
    'getPublicProfile',
    data: {'uid': uid},
  );
  final profile = result['profile'];
  return profile is Map
      ? AppUser.fromJson(Map<String, dynamic>.from(profile), uid)
      : null;
});

// 6. Leaderboard Category Enum & Provider
enum LeaderboardCategory { stars, wins, bestScore }

final weeklyLeaderboardProvider =
    FutureProvider.family<List<AppUser>, LeaderboardCategory>((
      ref,
      category,
    ) async {
      final field = switch (category) {
        LeaderboardCategory.stars => 'points',
        LeaderboardCategory.wins => 'wins',
        LeaderboardCategory.bestScore => 'bestScore',
      };
      final result = await SupabaseBackendService.call(
        'queryPublicProfiles',
        data: {'category': field, 'week': RankingPeriod.key(DateTime.now())},
      );
      return (result['profiles'] as List).map((raw) {
        final data = Map<String, dynamic>.from(raw as Map);
        final weekly = Map<String, dynamic>.from(data['weeklyRanking'] as Map);
        return AppUser.fromJson(data, data['uid'] as String).copyWith(
          points: weekly['points'] as int? ?? 0,
          wins: weekly['wins'] as int? ?? 0,
          losses: weekly['losses'] as int? ?? 0,
          bestScore: weekly['bestScore'] as int? ?? 0,
          gamesPlayed: weekly['gamesPlayed'] as int? ?? 0,
        );
      }).toList();
    });

final leaderboardProvider =
    FutureProvider.family<List<AppUser>, LeaderboardCategory>((
      ref,
      category,
    ) async {
      String field;
      switch (category) {
        case LeaderboardCategory.stars:
          field = 'points';
          break;
        case LeaderboardCategory.wins:
          field = 'wins';
          break;
        case LeaderboardCategory.bestScore:
          field = 'bestScore';
          break;
      }

      List<AppUser> users = [];

      final result = await SupabaseBackendService.call(
        'queryPublicProfiles',
        data: {'category': field},
      );
      users = (result['profiles'] as List).map((raw) {
        final data = Map<String, dynamic>.from(raw as Map);
        return AppUser.fromJson(data, data['uid'] as String);
      }).toList();

      // Re-sort based on category
      users.sort((a, b) {
        switch (category) {
          case LeaderboardCategory.stars:
            return b.points.compareTo(a.points);
          case LeaderboardCategory.wins:
            return b.wins.compareTo(a.wins);
          case LeaderboardCategory.bestScore:
            return b.bestScore.compareTo(a.bestScore);
        }
      });

      return users;
    });
