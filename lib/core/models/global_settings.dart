class GlobalSettings {
  final Map<String, String> sfxOverrides; // assetPath -> remoteUrl
  final Map<String, String> sfxBackups; // assetPath -> firstUploadedUrl
  final String? musicOverrideUrl;
  final String? musicBackupUrl;
  final int defaultTurnTimer;
  final int defaultTargetScore;

  GlobalSettings({
    this.sfxOverrides = const {},
    this.sfxBackups = const {},
    this.musicOverrideUrl,
    this.musicBackupUrl,
    this.defaultTurnTimer = 10,
    this.defaultTargetScore = 41,
  });

  factory GlobalSettings.fromJson(Map<String, dynamic> json) {
    return GlobalSettings(
      sfxOverrides: Map<String, String>.from(json['sfxOverrides'] ?? {}),
      sfxBackups: Map<String, String>.from(json['sfxBackups'] ?? {}),
      musicOverrideUrl: json['musicOverrideUrl'] as String?,
      musicBackupUrl: json['musicBackupUrl'] as String?,
      defaultTurnTimer: json['defaultTurnTimer'] as int? ?? 10,
      defaultTargetScore: json['defaultTargetScore'] as int? ?? 41,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sfxOverrides': sfxOverrides,
      'sfxBackups': sfxBackups,
      'musicOverrideUrl': musicOverrideUrl,
      'musicBackupUrl': musicBackupUrl,
      'defaultTurnTimer': defaultTurnTimer,
      'defaultTargetScore': defaultTargetScore,
    };
  }

  GlobalSettings copyWith({
    Map<String, String>? sfxOverrides,
    Map<String, String>? sfxBackups,
    String? musicOverrideUrl,
    String? musicBackupUrl,
    int? defaultTurnTimer,
    int? defaultTargetScore,
  }) {
    return GlobalSettings(
      sfxOverrides: sfxOverrides ?? this.sfxOverrides,
      sfxBackups: sfxBackups ?? this.sfxBackups,
      musicOverrideUrl: musicOverrideUrl ?? this.musicOverrideUrl,
      musicBackupUrl: musicBackupUrl ?? this.musicBackupUrl,
      defaultTurnTimer: defaultTurnTimer ?? this.defaultTurnTimer,
      defaultTargetScore: defaultTargetScore ?? this.defaultTargetScore,
    );
  }
}
