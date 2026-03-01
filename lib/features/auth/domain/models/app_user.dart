class AppUser {
  final String uid;
  final String email;
  final bool isEmailVerified;
  final String displayName;
  final String? avatarUrl;
  final int points;
  final int rank;
  final List<String> friends;
  final Map<String, String> friendInvites; // matchId -> senderName
  final int wins;
  final int losses;
  final int gamesPlayed;
  final int bestScore;
  final List<String> achievements;
  final bool isAdmin;

  final Map<String, int> inventory;

  AppUser({
    required this.uid,
    required this.email,
    this.isEmailVerified = false,
    required this.displayName,
    this.avatarUrl,
    this.points = 0,
    this.rank = 0,
    this.friends = const [],
    this.friendInvites = const {},
    this.inventory = const {},
    this.wins = 0,
    this.losses = 0,
    this.gamesPlayed = 0,
    this.bestScore = 0,
    this.achievements = const [],
    this.isAdmin = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> json, String uid) {
    List<String> parseFriends(dynamic data) {
      if (data == null) return const [];
      if (data is List) return data.map((e) => e.toString()).toList();
      if (data is Map) {
        return data.values.map((e) => e.toString()).toList();
      }
      return const [];
    }

    Map<String, String> parseInvites(dynamic data) {
      if (data == null || data is! Map) return const {};
      return Map<String, String>.from(data);
    }

    Map<String, int> parseInventory(dynamic data) {
      if (data == null || data is! Map) return const {};
      return Map<String, int>.from(data.map((k, v) => MapEntry(k.toString(), (v as num).toInt())));
    }

    return AppUser(
      uid: uid,
      email: json['email'] ?? '',
      isEmailVerified: json['isEmailVerified'] ?? false,
      displayName: json['displayName'] ?? 'Player',
      avatarUrl: json['avatarUrl'],
      points: json['points'] ?? 0,
      rank: json['rank'] ?? 0,
      friends: parseFriends(json['friends']),
      friendInvites: parseInvites(json['friendInvites']),
      inventory: parseInventory(json['inventory']),
      wins: json['wins'] ?? 0,
      losses: json['losses'] ?? 0,
      gamesPlayed: json['gamesPlayed'] ?? 0,
      bestScore: json['bestScore'] ?? 0,
      achievements: parseFriends(json['achievements']),
      isAdmin: json['isAdmin'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'isEmailVerified': isEmailVerified,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'points': points,
      'rank': rank,
      'friends': friends,
      'friendInvites': friendInvites,
      'inventory': inventory,
      'wins': wins,
      'losses': losses,
      'gamesPlayed': gamesPlayed,
      'bestScore': bestScore,
      'achievements': achievements,
      'isAdmin': isAdmin,
    };
  }

  AppUser copyWith({
    String? uid,
    String? email,
    bool? isEmailVerified,
    String? displayName,
    String? avatarUrl,
    int? points,
    int? rank,
    List<String>? friends,
    Map<String, String>? friendInvites,
    Map<String, int>? inventory,
    int? wins,
    int? losses,
    int? gamesPlayed,
    int? bestScore,
    List<String>? achievements,
    bool? isAdmin,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      points: points ?? this.points,
      rank: rank ?? this.rank,
      friends: friends ?? this.friends,
      friendInvites: friendInvites ?? this.friendInvites,
      inventory: inventory ?? this.inventory,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      bestScore: bestScore ?? this.bestScore,
      achievements: achievements ?? this.achievements,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}
