import 'dart:async';
import 'dart:convert';
import '../../game/domain/models/match_state.dart';
import 'lan_protocol.dart';

/// Only the host holds this object or the complete engine state.
class LanRoom {
  LanRoom(
    this.driver,
    String hostName, {
    String? room,
    String? secret,
    DateTime Function()? clock,
  }) : room = room ?? lanSecret(18),
       joinSecret = secret ?? lanSecret(),
       _now = clock ?? DateTime.now {
    host = LanMember(
      uid: 'LOCAL_LAN_${lanSecret(12)}',
      name: lanName(hostName),
      resumeToken: lanSecret(),
    );
    members.add(host);
    _changes = driver.changes.listen((_) {
      revision++;
      _notify();
    });
  }
  final LanGameDriver driver;
  final DateTime Function() _now;
  final String room, joinSecret;
  late final LanMember host;
  final List<LanMember> members = [];
  late final StreamSubscription<MatchState> _changes;
  final _events = StreamController<void>.broadcast(sync: true);
  Stream<void> get events => _events.stream;
  int revision = 0;
  bool started = false, closed = false;
  String? endReason;
  Future<void> _tail = Future.value();
  int _queued = 0;

  void _notify() {
    if (!_events.isClosed) _events.add(null);
  }

  LanMember join(String secret, Object? name) {
    if (closed || started || secret != joinSecret || members.length >= 4) {
      throw StateError('lan_join_denied');
    }
    final member = LanMember(
      uid: 'LOCAL_LAN_${lanSecret(12)}',
      name: lanName(name),
      resumeToken: lanSecret(),
    );
    members.add(member);
    revision++;
    _notify();
    return member;
  }

  LanMember resume(String token) {
    if (closed) throw StateError('lan_room_ended');
    final candidates = members.where(
      (m) => m != host && m.resumeToken == token,
    );
    if (candidates.length != 1) throw StateError('lan_join_denied');
    final member = candidates.single;
    if (member.connected) throw StateError('lan_already_connected');
    member.connected = true;
    if (started) unawaited(driver.presence(member.uid, true));
    revision++;
    _notify();
    return member;
  }

  void disconnected(LanMember member) {
    if (closed || !members.contains(member) || !member.connected) return;
    member.connected = false;
    if (started) unawaited(driver.presence(member.uid, false));
    revision++;
    _notify();
  }

  Future<void> leave(LanMember member) async {
    if (!members.contains(member)) return;
    if (member == host || started) {
      await close(member == host ? 'lan_host_ended' : 'lan_player_left');
    } else {
      members.remove(member);
      revision++;
      _notify();
    }
  }

  Future<void> start({String mode = 'classic'}) async {
    if (closed ||
        started ||
        members.any((m) => !m.connected) ||
        !['classic', 'tafweet'].contains(mode)) {
      throw StateError('lan_cannot_start');
    }
    started = true;
    try {
      await driver.start(room, List.unmodifiable(members), mode: mode);
    } catch (_) {
      started = false;
      rethrow;
    }
    revision++;
    _notify();
  }

  Map<String, dynamic> view(LanMember member) {
    if (!members.contains(member)) throw StateError('lan_not_member');
    final current = driver.state;
    return {
      'v': lanProtocolVersion,
      'type': 'snapshot',
      'room': room,
      'revision': revision,
      'hostNow': _now().millisecondsSinceEpoch,
      'members': members.map((m) => m.public).toList(),
      'started': started,
      'closed': closed,
      'reason': endReason,
      if (current != null && !closed)
        'match': lanViewerSnapshot(current, member.uid),
    };
  }

  Future<Map<String, dynamic>> submit(
    LanMember member,
    Map<String, dynamic> request,
  ) {
    if (_queued >= 32) return Future.value(_reply(request, false, 'lan_busy'));
    _queued++;
    final result = Completer<Map<String, dynamic>>();
    _tail = _tail.then((_) async {
      try {
        result.complete(await _submit(member, request));
      } catch (_) {
        result.complete(_reply(request, false, 'lan_action_failed'));
      } finally {
        _queued--;
      }
    });
    return result.future;
  }

  Map<String, dynamic> _reply(
    Map<String, dynamic> request,
    bool ok,
    String? reason,
  ) => {
    'v': lanProtocolVersion,
    'type': 'result',
    'id': request['id'],
    'seq': request['seq'],
    'ok': ok,
    'consumed': false,
    'reason': reason,
    'revision': revision,
  };

  Future<Map<String, dynamic>> _submit(
    LanMember member,
    Map<String, dynamic> req,
  ) async {
    if (closed ||
        !members.contains(member) ||
        !member.connected ||
        req['v'] is! int ||
        req['v'] != lanProtocolVersion ||
        req['type'] != 'command' ||
        req['room'] != room ||
        req['id'] is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{16,64}$').hasMatch(req['id'] as String) ||
        req['seq'] is! int ||
        req['revision'] is! int ||
        req['action'] is! String ||
        req['payload'] is! Map<String, dynamic> ||
        utf8.encode(jsonEncode(req)).length > 2048) {
      return _reply(req, false, 'lan_bad_command');
    }
    final sequence = req['seq'] as int;
    final identity = jsonEncode(req);
    final old = member.receipts[sequence];
    if (old != null) {
      return old.request == identity
          ? old.response
          : _reply(req, false, 'lan_command_conflict');
    }
    if (sequence != member.lastSequence + 1) {
      return _reply(req, false, 'lan_bad_sequence');
    }
    final now = _now();
    member.recentRequests.removeWhere((t) => now.difference(t).inSeconds >= 1);
    if (member.recentRequests.length >= 10) {
      return _reply(req, false, 'lan_busy');
    }
    member.recentRequests.add(now);
    String? reason;
    var ok = false;
    if (req['revision'] != revision) {
      reason = 'lan_stale';
    } else if (!started ||
        ![
          'play',
          'show',
          'cut',
          'voteShuffle',
          'voteRematch',
          'emoji',
        ].contains(req['action'])) {
      reason = 'lan_bad_command';
    } else {
      try {
        ok = await driver.command(
          member.uid,
          req['action'] as String,
          req['payload'] as Map<String, dynamic>,
        );
      } catch (_) {
        ok = false;
      }
      if (!ok) reason = 'lan_action_failed';
    }
    final reply = {..._reply(req, ok, reason), 'consumed': true};
    member.lastSequence = sequence;
    member.receipts[sequence] = (request: identity, response: reply);
    if (member.receipts.length > 128) {
      member.receipts.remove(member.receipts.keys.first);
    }
    return reply;
  }

  Future<void> close(String reason) async {
    if (closed) return;
    closed = true;
    endReason = reason;
    revision++;
    _notify();
    await _changes.cancel();
    await driver.close();
    await _events.close();
  }
}
