class GlobalSettings {
  static const _unchanged = Object();
  final Map<String, String> sfxOverrides; // assetPath -> remoteUrl
  final Map<String, String> sfxBackups; // assetPath -> firstUploadedUrl
  final String? musicOverrideUrl;
  final String? musicBackupUrl;
  final String? roomMusicOverrideUrl;
  final String? roomMusicBackupUrl;
  final int defaultTurnTimer;
  final int defaultTargetScore;

  GlobalSettings({
    this.sfxOverrides = const {},
    this.sfxBackups = const {},
    this.musicOverrideUrl,
    this.musicBackupUrl,
    this.roomMusicOverrideUrl,
    this.roomMusicBackupUrl,
    this.defaultTurnTimer = 10,
    this.defaultTargetScore = 41,
  });

  factory GlobalSettings.fromJson(Map<String, dynamic> json) {
    return GlobalSettings(
      sfxOverrides: Map<String, String>.from(json['sfxOverrides'] ?? {}),
      sfxBackups: Map<String, String>.from(json['sfxBackups'] ?? {}),
      musicOverrideUrl: json['musicOverrideUrl'] as String?,
      musicBackupUrl: json['musicBackupUrl'] as String?,
      roomMusicOverrideUrl: json['roomMusicOverrideUrl'] as String?,
      roomMusicBackupUrl: json['roomMusicBackupUrl'] as String?,
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
      'roomMusicOverrideUrl': roomMusicOverrideUrl,
      'roomMusicBackupUrl': roomMusicBackupUrl,
      'defaultTurnTimer': defaultTurnTimer,
      'defaultTargetScore': defaultTargetScore,
    };
  }

  GlobalSettings copyWith({
    Map<String, String>? sfxOverrides,
    Map<String, String>? sfxBackups,
    Object? musicOverrideUrl = _unchanged,
    Object? musicBackupUrl = _unchanged,
    Object? roomMusicOverrideUrl = _unchanged,
    Object? roomMusicBackupUrl = _unchanged,
    int? defaultTurnTimer,
    int? defaultTargetScore,
  }) {
    return GlobalSettings(
      sfxOverrides: sfxOverrides ?? this.sfxOverrides,
      sfxBackups: sfxBackups ?? this.sfxBackups,
      musicOverrideUrl: identical(musicOverrideUrl, _unchanged)
          ? this.musicOverrideUrl
          : musicOverrideUrl as String?,
      musicBackupUrl: identical(musicBackupUrl, _unchanged)
          ? this.musicBackupUrl
          : musicBackupUrl as String?,
      roomMusicOverrideUrl: identical(roomMusicOverrideUrl, _unchanged)
          ? this.roomMusicOverrideUrl
          : roomMusicOverrideUrl as String?,
      roomMusicBackupUrl: identical(roomMusicBackupUrl, _unchanged)
          ? this.roomMusicBackupUrl
          : roomMusicBackupUrl as String?,
      defaultTurnTimer: defaultTurnTimer ?? this.defaultTurnTimer,
      defaultTargetScore: defaultTargetScore ?? this.defaultTargetScore,
    );
  }
}
