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
  });

  factory AppUser.fromJson(Map<String, dynamic> json, String uid) {
    return AppUser(
      uid: uid,
      email: json['email'] ?? '',
      isEmailVerified: json['isEmailVerified'] ?? false,
      displayName: json['displayName'] ?? 'Player',
      avatarUrl: json['avatarUrl'],
      points: json['points'] ?? 0,
      rank: json['rank'] ?? 0,
      friends: (json['friends'] as List?)?.cast<String>() ?? const [],
      friendInvites: (json['friendInvites'] as Map?)?.cast<String, String>() ?? const {},
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
    );
  }
}
