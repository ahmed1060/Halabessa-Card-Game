import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/app_user.dart';
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
final userProfileProvider = FutureProvider.family<AppUser?, String>((ref, uid) async {
  final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  if (doc.exists) {
    return AppUser.fromJson(doc.data()!, uid);
  }
  return null;
});

// 6. Leaderboard Category Enum & Provider
enum LeaderboardCategory { stars, wins, bestScore }

final leaderboardProvider = FutureProvider.family<List<AppUser>, LeaderboardCategory>((ref, category) async {
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

  try {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .orderBy(field, descending: true)
        .limit(50)
        .get();

    users = query.docs.map((doc) => AppUser.fromJson(doc.data(), doc.id)).toList();
  } catch (_) {
    // Graceful offline fallback
  }

  if (users.isEmpty) {
    users = _getFallbackLeaderboard(category);
  }

  // Include current user if not already in list
  final current = ref.watch(currentUserProvider);
  if (current != null && !users.any((u) => u.uid == current.uid)) {
    users.add(current);
  }

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

List<AppUser> _getFallbackLeaderboard(LeaderboardCategory category) {
  return [
    AppUser(uid: 'bot_champ_1', email: '', displayName: 'حريف الحلبسة', username: 'hareef_masr', points: 3450, wins: 85, bestScore: 68, gamesPlayed: 110),
    AppUser(uid: 'bot_champ_2', email: '', displayName: 'سلطان البصرة', username: 'sultan_basra', points: 2890, wins: 72, bestScore: 62, gamesPlayed: 95),
    AppUser(uid: 'bot_champ_3', email: '', displayName: 'معلم الكوتشينة', username: 'moalem_ahwa', points: 2340, wins: 59, bestScore: 57, gamesPlayed: 80),
    AppUser(uid: 'bot_champ_4', email: '', displayName: 'أسطورة التفويت', username: 'tafweet_legend', points: 1980, wins: 48, bestScore: 51, gamesPlayed: 65),
    AppUser(uid: 'bot_champ_5', email: '', displayName: 'ملك الصالون', username: 'salon_king', points: 1650, wins: 41, bestScore: 46, gamesPlayed: 55),
    AppUser(uid: 'bot_champ_6', email: '', displayName: 'شاطر الإسكندرية', username: 'alex_sharp', points: 1420, wins: 36, bestScore: 44, gamesPlayed: 50),
    AppUser(uid: 'bot_champ_7', email: '', displayName: 'قناص الأوراق', username: 'card_sniper', points: 1210, wins: 31, bestScore: 42, gamesPlayed: 44),
    AppUser(uid: 'bot_champ_8', email: '', displayName: 'كابتن حلبسة', username: 'capt_halabessa', points: 1050, wins: 27, bestScore: 40, gamesPlayed: 38),
  ];
}
