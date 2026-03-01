class GlobalSettings {
  final Map<String, String> sfxOverrides; // assetPath -> remoteUrl
  final String? musicOverrideUrl;
  final int defaultTurnTimer;
  final int defaultTargetScore;

  GlobalSettings({
    this.sfxOverrides = const {},
    this.musicOverrideUrl,
    this.defaultTurnTimer = 10,
    this.defaultTargetScore = 41,
  });

  factory GlobalSettings.fromJson(Map<String, dynamic> json) {
    return GlobalSettings(
      sfxOverrides: Map<String, String>.from(json['sfxOverrides'] ?? {}),
      musicOverrideUrl: json['musicOverrideUrl'] as String?,
      defaultTurnTimer: json['defaultTurnTimer'] as int? ?? 10,
      defaultTargetScore: json['defaultTargetScore'] as int? ?? 41,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sfxOverrides': sfxOverrides,
      'musicOverrideUrl': musicOverrideUrl,
      'defaultTurnTimer': defaultTurnTimer,
      'defaultTargetScore': defaultTargetScore,
    };
  }

  GlobalSettings copyWith({
    Map<String, String>? sfxOverrides,
    String? musicOverrideUrl,
    int? defaultTurnTimer,
    int? defaultTargetScore,
  }) {
    return GlobalSettings(
      sfxOverrides: sfxOverrides ?? this.sfxOverrides,
      musicOverrideUrl: musicOverrideUrl ?? this.musicOverrideUrl,
      defaultTurnTimer: defaultTurnTimer ?? this.defaultTurnTimer,
      defaultTargetScore: defaultTargetScore ?? this.defaultTargetScore,
    );
  }
}
