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

// Social/privilege requests depend only on the session UID, not balances or
// inventory. Auto-dispose prevents another account inheriting cached state.
final sessionUidProvider = Provider<String?>(
  (ref) =>
      ref.watch(authStateChangesProvider.select((value) => value.value?.uid)),
);

final backendCallProvider = Provider((ref) => SupabaseBackendService.call);

class SessionSocialGraph {
  final String uid;
  final Map<String, dynamic> data;
  const SessionSocialGraph(this.uid, this.data);
}

final socialGraphProvider = FutureProvider.autoDispose<SessionSocialGraph?>((
  ref,
) async {
  final uid = ref.watch(sessionUidProvider);
  if (uid == null) return null;
  return SessionSocialGraph(
    uid,
    await ref.read(backendCallProvider)('getSocialGraph'),
  );
});

final verifiedAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  final uid = ref.watch(sessionUidProvider);
  if (uid == null) return false;
  final result = await ref.read(backendCallProvider)('getAdminStatus');
  return result['admin'] == true;
});

// 4. Publish profile values without waiting for enrichment. Admin is false
// until verified; backend authorization is still checked on every operation.
final currentUserProvider = Provider<AppUser?>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return null;
  final admin = ref.watch(verifiedAdminProvider).asData?.value ?? false;
  // Retain the visible graph during a same-account refresh, but never use a
  // previous account's relationships while its successor is loading.
  final graph = ref.watch(socialGraphProvider).value;
  final social = graph?.uid == user.uid
      ? graph!.data
      : const <String, dynamic>{};
  return user.copyWith(
    isAdmin: admin,
    friends: List<String>.from(social['friends'] as List? ?? const []),
    pendingFriendRequests: List<String>.from(
      social['pendingFriendRequests'] as List? ?? const [],
    ),
    sentFriendRequests: List<String>.from(
      social['sentFriendRequests'] as List? ?? const [],
    ),
    friendInvites: Map<String, String>.from(
      social['friendInvites'] as Map? ?? const {},
    ),
  );
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
