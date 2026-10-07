import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

// 5. Fetches any user's profile from Firestore
final userProfileProvider = FutureProvider.family<AppUser?, String>((
  ref,
  uid,
) async {
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();
  if (doc.exists) {
    return AppUser.fromJson(doc.data()!, uid);
  }
  return null;
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
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where(
            'weeklyRanking.week',
            isEqualTo: RankingPeriod.key(DateTime.now()),
          )
          .orderBy('weeklyRanking.$field', descending: true)
          .limit(50)
          .get();
      return query.docs.map((doc) {
        final data = doc.data();
        final weekly = Map<String, dynamic>.from(data['weeklyRanking'] as Map);
        return AppUser.fromJson(data, doc.id).copyWith(
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

      final query = await FirebaseFirestore.instance
          .collection('users')
          .orderBy(field, descending: true)
          .limit(50)
          .get();

      users = query.docs
          .map((doc) => AppUser.fromJson(doc.data(), doc.id))
          .toList();

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
