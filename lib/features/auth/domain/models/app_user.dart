class AppUser {
  final String uid;
  final String email;
  final bool isEmailVerified;
  final String displayName;
  final String? avatarUrl;
  final int points;
  final int rank;

  AppUser({
    required this.uid,
    required this.email,
    this.isEmailVerified = false,
    required this.displayName,
    this.avatarUrl,
    this.points = 0,
    this.rank = 0,
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
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      points: points ?? this.points,
      rank: rank ?? this.rank,
    );
  }
}
