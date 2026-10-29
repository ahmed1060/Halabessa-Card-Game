import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../domain/lan_protocol.dart';
import '../domain/lan_room.dart';
import 'lan_connection.dart';
import 'lan_tls.dart';

Future<LanHostedRoom> hostLanRoom(
  LanGameDriver driver,
  String name, {
  bool loopbackForTesting = false,
}) async {
  lanName(name);
  final addresses = loopbackForTesting
      ? ['127.0.0.1']
      : [
          for (final network in await NetworkInterface.list(
            type: InternetAddressType.IPv4,
          ))
            for (final address in network.addresses)
              if (isLocalLanAddress(address.address)) address.address,
        ];
  if (addresses.isEmpty) throw StateError('lan_no_network');
  final identity = LanTlsIdentity(
    await compute((_) => generateLanIdentity(), null),
  );
  final server = await HttpServer.bindSecure(
    loopbackForTesting ? InternetAddress.loopbackIPv4 : InternetAddress.anyIPv4,
    0,
    identity.context,
  );
  return _HostedRoom(server, LanRoom(driver, name), identity, addresses);
}

Future<LanConnection> joinLanRoom(
  LanInvitation invitation,
  String name, {
  bool loopbackForTesting = false,
}) async {
  final checked = LanInvitation.parse(
    invitation.text,
    allowLoopback: loopbackForTesting,
  );
  final client = _SocketClient(checked, lanName(name));
  try {
    await client.reconnect();
    return client;
  } catch (_) {
    await client.close(leave: false);
    client.dispose();
    rethrow;
  }
}

class _HostedRoom implements LanHostedRoom {
  _HostedRoom(this.server, this.authority, this.identity, this.addresses) {
    local = _LocalClient(authority);
    _roomEvents = authority.events.listen(
      (_) => _broadcast(),
      onDone: _finishSockets,
    );
    _http = server.listen(
      (request) => unawaited(_accept(request)),
      onError: (Object _) {},
    );
  }
  final HttpServer server;
  final LanRoom authority;
  final LanTlsIdentity identity;
  @override
  final List<String> addresses;
  @override
  late final LanConnection local;
  late final StreamSubscription<HttpRequest> _http;
  late final StreamSubscription<void> _roomEvents;
  final Map<WebSocket, LanMember?> _sockets = {};
  bool _closed = false;
  int _admissions = 0;
  @override
  int get port => server.port;
  @override
  String get room => authority.room;
  @override
  LanInvitation invitation(String address) {
    if (!addresses.contains(address)) throw StateError('lan_bad_invitation');
    return LanInvitation(
      address: address,
      port: port,
      room: room,
      fingerprint: identity.fingerprint,
      secret: authority.joinSecret,
    );
  }

  Future<void> _accept(HttpRequest request) async {
    if (_closed ||
        authority.closed ||
        _sockets.length + _admissions >= 7 ||
        request.uri.path != '/room' ||
        request.uri.hasQuery ||
        request.headers.value('origin') != null ||
        !WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }
    _admissions++;
    try {
      final socket = await WebSocketTransformer.upgrade(
        request,
        protocolSelector: (protocols) =>
            protocols.contains(lanSocketProtocol) ? lanSocketProtocol : null,
        maxPayloadLength: 2048,
      );
      if (socket.protocol != lanSocketProtocol) {
        await socket.close();
        return;
      }
      _sockets[socket] = null;
      socket.pingInterval = const Duration(seconds: 4);
      final admission = Timer(const Duration(seconds: 5), () {
        if (_sockets[socket] == null) unawaited(socket.close());
      });
      socket.listen(
        (message) async {
          try {
            final req = lanMessage(message, maxBytes: 2048);
            var member = _sockets[socket];
            if (member == null) {
              if (req['type'] != 'hello' || req['room'] != room) {
                throw StateError('lan_join_denied');
              }
              member = req['resume'] is String
                  ? authority.resume(req['resume'] as String)
                  : authority.join(req['secret'] as String? ?? '', req['name']);
              _sockets[socket] = member;
              admission.cancel();
              socket.add(
                jsonEncode({
                  'v': lanProtocolVersion,
                  'type': 'welcome',
                  'uid': member.uid,
                  'resume': member.resumeToken,
                  'nextSeq': member.lastSequence + 1,
                  'room': room,
                }),
              );
              socket.add(jsonEncode(authority.view(member)));
            } else if (req['type'] == 'command') {
              final reply = await authority.submit(member, req);
              if (socket.readyState == WebSocket.open) {
                socket.add(jsonEncode(authority.view(member)));
                socket.add(jsonEncode(reply));
              }
            } else if (req['type'] == 'leave') {
              await authority.leave(member);
              await socket.close();
            } else {
              throw const FormatException('lan_bad_message');
            }
          } catch (_) {
            unawaited(socket.close(WebSocketStatus.policyViolation));
          }
        },
        onDone: () {
          admission.cancel();
          final member = _sockets.remove(socket);
          if (member != null) authority.disconnected(member);
        },
        onError: (Object _) {
          unawaited(socket.close());
        },
      );
    } catch (_) {
      try {
        await request.response.close();
      } catch (_) {}
    } finally {
      _admissions--;
    }
  }

  void _broadcast() {
    for (final entry in _sockets.entries.toList()) {
      if (entry.value != null && !authority.members.contains(entry.value)) {
        unawaited(entry.key.close());
        continue;
      }
      if (entry.value != null && entry.key.readyState == WebSocket.open) {
        entry.key.add(jsonEncode(authority.view(entry.value!)));
      }
    }
  }

  void _finishSockets() {
    for (final socket in _sockets.keys.toList()) {
      unawaited(socket.close());
    }
    unawaited(server.close(force: true));
  }

  @override
  Future<void> start({String mode = 'classic'}) => authority.start(mode: mode);
  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await authority.close('lan_host_ended');
    await _roomEvents.cancel();
    await _http.cancel();
    await server.close(force: true);
    await local.close(leave: false);
  }
}

class _LocalClient extends LanConnection {
  _LocalClient(this.room) {
    snapshot = room.view(room.host);
    _subscription = room.events.listen((_) {
      snapshot = room.view(room.host);
      notifyListeners();
    });
  }
  final LanRoom room;
  late final StreamSubscription<void> _subscription;
  @override
  Map<String, dynamic>? snapshot;
  @override
  String get uid => room.host.uid;
  @override
  int get clockOffsetMs => 0;
  @override
  String get status => room.closed ? 'ended' : 'connected';
  @override
  Future<bool> command(String action, Map<String, dynamic> payload) async {
    final result = await room.submit(room.host, {
      'v': lanProtocolVersion,
      'type': 'command',
      'room': room.room,
      'id': lanSecret(18),
      'seq': room.host.lastSequence + 1,
      'revision': room.revision,
      'action': action,
      'payload': payload,
    });
    return result['ok'] == true;
  }

  @override
  Future<void> reconnect() async {}
  @override
  Future<void> close({bool leave = true}) async {
    await _subscription.cancel();
    if (leave) await room.close('lan_host_ended');
  }
}

class _SocketClient extends LanConnection {
  _SocketClient(this.invitation, this.name);
  final LanInvitation invitation;
  final String name;
  @override
  Map<String, dynamic>? snapshot;
  @override
  String uid = '';
  @override
  String status = 'joining';
  String? _resume;
  int? _clockOffset;
  @override
  int get clockOffsetMs => _clockOffset ?? 0;
  int _sequence = 1, _generation = 0;
  WebSocket? _socket;
  HttpClient? _http;
  StreamSubscription? _subscription;
  Completer<void>? _ready;
  Completer<bool>? _result;
  Map<String, dynamic>? _pending;
  bool _closed = false, _suspended = false;
  Timer? _retry;
  int _attempts = 0;

  void _state(String value) {
    status = value;
    notifyListeners();
  }

  @override
  Future<void> reconnect() async {
    if (_closed || status == 'ended') return;
    _suspended = false;
    final generation = ++_generation;
    _clockOffset = null;
    _retry?.cancel();
    await _subscription?.cancel();
    await _socket?.close();
    _http?.close(force: true);
    _state(uid.isEmpty ? 'joining' : 'reconnecting');
    final security = SecurityContext(withTrustedRoots: false);
    final client = HttpClient(context: security)
      ..connectionTimeout = const Duration(seconds: 5)
      ..findProxy = (_) => 'DIRECT';
    _http = client;
    // Restrict every connection attempt, including any redirect, to this peer.
    client.connectionFactory = (uri, proxyHost, proxyPort) {
      if (uri.scheme != 'https' ||
          uri.host != invitation.address ||
          uri.port != invitation.port ||
          proxyHost != null) {
        throw StateError('lan_bad_invitation');
      }
      return SecureSocket.startConnect(
        InternetAddress(invitation.address),
        invitation.port,
        context: security,
        onBadCertificate: (cert) =>
            sha256.convert(cert.der).toString() == invitation.fingerprint,
      );
    };
    try {
      final socket = await WebSocket.connect(
        Uri(
          scheme: 'wss',
          host: invitation.address,
          port: invitation.port,
          path: '/room',
        ).toString(),
        protocols: [lanSocketProtocol],
        compression: CompressionOptions.compressionOff,
        customClient: client,
        maxPayloadLength: 65536,
      ).timeout(const Duration(seconds: 7));
      if (_closed || generation != _generation) {
        await socket.close();
        return;
      }
      _socket = socket;
      socket.pingInterval = const Duration(seconds: 4);
      final ready = _ready = Completer<void>();
      _subscription = socket.listen(
        (message) => _receive(message, generation),
        onDone: () => _disconnected(generation),
        onError: (Object _) => _disconnected(generation),
      );
      socket.add(
        jsonEncode({
          'v': lanProtocolVersion,
          'type': 'hello',
          'room': invitation.room,
          'name': name,
          if (_resume != null)
            'resume': _resume
          else
            'secret': invitation.secret,
        }),
      );
      await ready.future.timeout(const Duration(seconds: 7));
      if (_pending != null) socket.add(jsonEncode(_pending));
    } catch (_) {
      if (!_closed && generation == _generation) _state('reconnecting');
      unawaited(_socket?.close());
      client.close(force: true);
      rethrow;
    }
  }

  void _receive(Object? raw, int generation) {
    if (_closed || generation != _generation) return;
    try {
      final data = lanMessage(raw);
      if (data['room'] != null && data['room'] != invitation.room) {
        throw StateError('lan_bad_message');
      }
      switch (data['type']) {
        case 'welcome':
          if (data['uid'] is! String ||
              data['resume'] is! String ||
              data['nextSeq'] is! int ||
              (uid.isNotEmpty && data['uid'] != uid)) {
            throw StateError('lan_bad_message');
          }
          uid = data['uid'] as String;
          _resume = data['resume'] as String;
          _sequence = max(_sequence, data['nextSeq'] as int);
        case 'snapshot':
          if (uid.isEmpty ||
              data['revision'] is! int ||
              data['hostNow'] is! int ||
              data['members'] is! List ||
              data['room'] != invitation.room) {
            throw StateError('lan_bad_message');
          }
          final previous = snapshot?['revision'] as int? ?? -1;
          if ((data['revision'] as int) < previous) return;
          if (data['match'] is Map) {
            final match = data['match'] as Map;
            final hands = match['handCards'];
            if (match['id'] != 'OFFLINE_LAN_${invitation.room}' ||
                hands is! Map ||
                hands.keys.any((key) => key != uid)) {
              throw StateError('lan_bad_message');
            }
          }
          _clockOffset ??=
              DateTime.now().millisecondsSinceEpoch - (data['hostNow'] as int);
          snapshot = data;
          if (data['closed'] == true) {
            _state('ended');
          } else {
            _attempts = 0;
            _state('connected');
          }
          if (_ready?.isCompleted == false) _ready!.complete();
        case 'result':
          if (_pending?['id'] != data['id'] ||
              _pending?['seq'] != data['seq']) {
            return;
          }
          if (data['consumed'] == true) {
            _sequence = max(_sequence, (data['seq'] as int) + 1);
          }
          if (_result?.isCompleted == false) {
            _result!.complete(data['ok'] == true);
          }
          _pending = null;
        default:
          throw StateError('lan_bad_message');
      }
    } catch (_) {
      unawaited(_socket?.close(WebSocketStatus.policyViolation));
    }
  }

  void _disconnected(int generation) {
    if (_closed ||
        _suspended ||
        generation != _generation ||
        status == 'ended') {
      return;
    }
    if (_ready?.isCompleted == false) {
      _ready!.completeError(StateError('lan_connection_lost'));
    }
    _state('reconnecting');
    if (_attempts++ < 5) {
      _retry?.cancel();
      _retry = Timer(Duration(seconds: min(_attempts, 4)), () {
        unawaited(reconnect().catchError((Object _) {}));
      });
    }
  }

  @override
  Future<bool> command(String action, Map<String, dynamic> payload) async {
    if (_closed || status != 'connected' || _pending != null) return false;
    final pending = _pending = {
      'v': lanProtocolVersion,
      'type': 'command',
      'room': invitation.room,
      'id': lanSecret(18),
      'seq': _sequence,
      'revision': snapshot!['revision'],
      'action': action,
      'payload': payload,
    };
    final result = _result = Completer<bool>();
    _socket!.add(jsonEncode(pending));
    try {
      return await result.future.timeout(const Duration(seconds: 12));
    } catch (_) {
      // Keep this command's identity until a result is recovered. A newer play
      // cannot be sent over an ambiguously accepted older one.
      if (!_closed && status != 'ended') {
        _state('reconnecting');
        if (!_suspended) unawaited(reconnect().catchError((Object _) {}));
      }
      return false;
    }
  }

  @override
  Future<void> suspend() async {
    if (_closed || status == 'ended') return;
    _suspended = true;
    _generation++;
    _retry?.cancel();
    await _subscription?.cancel();
    await _socket?.close();
    _http?.close(force: true);
    _state('reconnecting');
  }

  @override
  Future<void> close({bool leave = true}) async {
    if (_closed) return;
    _closed = true;
    _generation++;
    _retry?.cancel();
    _state('ended');
    if (leave && _socket?.readyState == WebSocket.open) {
      _socket!.add(jsonEncode({'v': lanProtocolVersion, 'type': 'leave'}));
    }
    await _subscription?.cancel();
    await _socket?.close();
    _http?.close(force: true);
    if (_result?.isCompleted == false) _result!.complete(false);
    if (_ready?.isCompleted == false) {
      _ready!.completeError(StateError('lan_room_ended'));
    }
  }
}
