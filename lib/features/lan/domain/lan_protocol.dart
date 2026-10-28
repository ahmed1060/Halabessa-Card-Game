import 'dart:convert';
import 'dart:math';
import '../../game/domain/models/match_state.dart';

const lanProtocolVersion = 1;
const lanServiceType = '_halabessa._tcp';
const lanSocketProtocol = 'halabessa-lan-v1';

String lanSecret([int bytes = 32]) => base64Url
    .encode(List<int>.generate(bytes, (_) => Random.secure().nextInt(256)))
    .replaceAll('=', '');

bool isLocalLanAddress(String value, {bool allowLoopback = false}) {
  final octets = value.split('.');
  if (octets.length != 4) return false;
  final values = octets.map(int.tryParse).toList();
  if (values.any((v) => v == null || v < 0 || v > 255)) return false;
  if (values.map((v) => '$v').join('.') != value) return false;
  return values[0] == 10 ||
      (values[0] == 172 && values[1]! >= 16 && values[1]! <= 31) ||
      (values[0] == 192 && values[1] == 168) ||
      (values[0] == 169 && values[1] == 254) ||
      (allowLoopback && values[0] == 127);
}

class LanInvitation {
  const LanInvitation({
    required this.address,
    required this.port,
    required this.room,
    required this.fingerprint,
    required this.secret,
  });
  final String address, room, fingerprint, secret;
  final int port;
  String get text => Uri(
    scheme: 'halabessa-lan',
    host: 'join',
    queryParameters: {
      'v': '$lanProtocolVersion',
      'h': address,
      'p': '$port',
      'r': room,
      'f': fingerprint,
      's': secret,
    },
  ).toString();

  factory LanInvitation.parse(String value, {bool allowLoopback = false}) {
    if (value.length > 1024) throw const FormatException('lan_bad_invitation');
    final uri = Uri.parse(value.trim());
    final q = uri.queryParameters;
    if (uri.scheme != 'halabessa-lan' ||
        uri.host != 'join' ||
        uri.path.isNotEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.hasPort ||
        q.length != 6 ||
        q['v'] != '$lanProtocolVersion' ||
        uri.queryParametersAll.values.any((v) => v.length != 1) ||
        !isLocalLanAddress(q['h'] ?? '', allowLoopback: allowLoopback) ||
        !RegExp(r'^[A-Za-z0-9_-]{16,64}$').hasMatch(q['r'] ?? '') ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(q['f'] ?? '') ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(q['s'] ?? '')) {
      throw const FormatException('lan_bad_invitation');
    }
    final port = int.tryParse(q['p'] ?? '');
    if (port == null || port < 1 || port > 65535) {
      throw const FormatException('lan_bad_invitation');
    }
    return LanInvitation(
      address: q['h']!,
      port: port,
      room: q['r']!,
      fingerprint: q['f']!,
      secret: q['s']!,
    );
  }
}

String lanName(Object? raw) {
  if (raw is! String) throw const FormatException('lan_bad_name');
  final name = raw.trim();
  if (name.isEmpty ||
      name.runes.length > 30 ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(name)) {
    throw const FormatException('lan_bad_name');
  }
  return name;
}

Map<String, dynamic> lanMessage(Object? message, {int maxBytes = 65536}) {
  if (message is! String ||
      message.length > maxBytes ||
      utf8.encode(message).length > maxBytes) {
    throw const FormatException('lan_bad_message');
  }
  final value = jsonDecode(message);
  if (value is! Map<String, dynamic> ||
      value['v'] is! int ||
      value['v'] != lanProtocolVersion) {
    throw const FormatException('lan_bad_version');
  }
  return value;
}

Map<String, dynamic> lanViewerSnapshot(MatchState state, String uid) {
  if (!state.id.startsWith('OFFLINE_LAN_') || !state.playerIds.contains(uid)) {
    throw StateError('lan_not_member');
  }
  return {
    ...state.toJson(),
    'handCards': {
      uid: (state.handCards[uid] ?? []).map((c) => c.toJson()).toList(),
    },
    'handCounts': {
      for (final id in state.playerIds) id: state.handCards[id]?.length ?? 0,
    },
    'earnedCoins': <String, int>{},
    'earnedStars': <String, int>{},
  };
}

/// This is a display projection, never an input to the host's rules engine.
MatchState lanDisplaySnapshot(
  Map<String, dynamic> data,
  int hostNowMs,
  DateTime receivedAt,
) {
  final delta = receivedAt.millisecondsSinceEpoch - hostNowMs;
  final snapshot = Map<String, dynamic>.from(data);
  for (final key in [
    'turnStartTime',
    'phaseStartedAt',
    'playAvailableAt',
    'expireAt',
  ]) {
    if (snapshot[key] is String) {
      snapshot[key] = DateTime.parse(
        snapshot[key] as String,
      ).add(Duration(milliseconds: delta)).toIso8601String();
    }
  }
  return MatchState.fromJson(snapshot);
}

class LanMember {
  LanMember({required this.uid, required this.name, required this.resumeToken});
  final String uid, name, resumeToken;
  bool connected = true;
  int lastSequence = 0;
  final Map<int, ({String request, Map<String, dynamic> response})> receipts =
      {};
  final List<DateTime> recentRequests = [];
  Map<String, dynamic> get public => {
    'uid': uid,
    'name': name,
    'connected': connected,
  };
}

abstract interface class LanGameDriver {
  Stream<MatchState> get changes;
  MatchState? get state;
  Future<void> start(
    String room,
    List<LanMember> humans, {
    required String mode,
  });
  Future<bool> command(String uid, String action, Map<String, dynamic> payload);
  Future<void> presence(String uid, bool connected);
  Future<void> close();
}
