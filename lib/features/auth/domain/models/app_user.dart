class AppUser {
  final String uid;
  final String email;
  final bool isEmailVerified;
  final String displayName;
  final String? username; // Unique identifier (e.g., @ahmed)
  final String? avatarUrl;
  final int points;
  final int diamonds;
  final int coins;
  final int rank;
  final List<String> friends;
  final List<String> pendingFriendRequests; 
  final List<String> sentFriendRequests;
  final Map<String, String> friendInvites; // matchId -> senderName
  final int wins;
  final int losses;
  final int gamesPlayed;
  final int bestScore;
  final List<String> achievements;
  final bool isAdmin;
  final List<String> ownedSkins;
  final String searchName;

  final Map<String, int> inventory;
  
  double get winRate => gamesPlayed == 0 ? 0 : wins / gamesPlayed;
  int get level => isAdmin ? 999 : (points / 1000).floor() + 1;

  bool canAfford(int price, {bool isDiamonds = false}) => 
    isAdmin || (isDiamonds ? diamonds >= price : coins >= price);

  AppUser({
    required this.uid,
    required this.email,
    this.isEmailVerified = false,
    required this.displayName,
    this.avatarUrl,
    this.points = 0,
    this.diamonds = 0,
    this.coins = 0,
    this.rank = 0,
    this.friends = const [],
    this.pendingFriendRequests = const [],
    this.sentFriendRequests = const [],
    this.friendInvites = const {},
    this.inventory = const {},
    this.wins = 0,
    this.losses = 0,
    this.gamesPlayed = 0,
    this.bestScore = 0,
    this.achievements = const [],
    this.isAdmin = false,
    this.ownedSkins = const [],
    this.searchName = '',
    this.username,
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
      diamonds: json['diamonds'] ?? 0,
      coins: json['coins'] ?? 0,
      rank: json['rank'] ?? 0,
      friends: parseFriends(json['friends']),
      pendingFriendRequests: parseFriends(json['pendingFriendRequests']),
      sentFriendRequests: parseFriends(json['sentFriendRequests']),
      friendInvites: parseInvites(json['friendInvites']),
      inventory: parseInventory(json['inventory']),
      wins: json['wins'] ?? 0,
      losses: json['losses'] ?? 0,
      gamesPlayed: json['gamesPlayed'] ?? 0,
      bestScore: json['bestScore'] ?? 0,
      achievements: parseFriends(json['achievements']),
      isAdmin: (json['isAdmin'] ?? false) || json['email'] == 'ahmed.hossam1060@gmail.com',
      ownedSkins: parseFriends(json['owned_skins']),
      username: json['username'],
      searchName: json['searchName'] ?? (json['username'] ?? json['displayName'] ?? '').toString().toLowerCase(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'isEmailVerified': isEmailVerified,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'points': points,
      'diamonds': diamonds,
      'coins': coins,
      'rank': rank,
      'friends': friends,
      'pendingFriendRequests': pendingFriendRequests,
      'sentFriendRequests': sentFriendRequests,
      'friendInvites': friendInvites,
      'inventory': inventory,
      'wins': wins,
      'losses': losses,
      'gamesPlayed': gamesPlayed,
      'bestScore': bestScore,
      'achievements': achievements,
      'isAdmin': isAdmin,
      'owned_skins': ownedSkins,
      'username': username,
      'searchName': searchName.isEmpty ? (username ?? displayName).toLowerCase() : searchName,
    };
  }

  AppUser copyWith({
    String? uid,
    String? email,
    bool? isEmailVerified,
    String? displayName,
    String? avatarUrl,
    int? points,
    int? diamonds,
    int? coins,
    int? rank,
    List<String>? friends,
    List<String>? pendingFriendRequests,
    List<String>? sentFriendRequests,
    Map<String, String>? friendInvites,
    Map<String, int>? inventory,
    int? wins,
    int? losses,
    int? gamesPlayed,
    int? bestScore,
    List<String>? achievements,
    bool? isAdmin,
    List<String>? ownedSkins,
    String? searchName,
    String? username,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      points: points ?? this.points,
      diamonds: diamonds ?? this.diamonds,
      coins: coins ?? this.coins,
      rank: rank ?? this.rank,
      friends: friends ?? this.friends,
      pendingFriendRequests: pendingFriendRequests ?? this.pendingFriendRequests,
      sentFriendRequests: sentFriendRequests ?? this.sentFriendRequests,
      friendInvites: friendInvites ?? this.friendInvites,
      inventory: inventory ?? this.inventory,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      bestScore: bestScore ?? this.bestScore,
      achievements: achievements ?? this.achievements,
      isAdmin: isAdmin ?? this.isAdmin,
      ownedSkins: ownedSkins ?? this.ownedSkins,
      searchName: searchName ?? this.searchName,
      username: username ?? this.username,
    );
  }
}
