import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:halabessa/core/services/supabase_backend_service.dart';
import 'package:halabessa/core/services/idempotent_match_request.dart';
import 'command_snapshot_stream.dart';
import '../../domain/models/match_state.dart';
import '../../domain/logic/online_room_protocol.dart';
import '../../domain/models/room_summary.dart';
import '../../domain/models/chat_message.dart';
import '../../../auth/domain/models/app_user.dart';

class MultiplayerSyncService {
  final FirebaseDatabase _db;

  MultiplayerSyncService(this._db);

  DatabaseReference get matchRef => _db.ref('matches');

  /// Hand cards live in a tree separate from matches/$matchId on purpose:
  /// database.rules.json restricts matchHands/$matchId to that match's own
  /// participants, while matches/$matchId itself stays readable by any
  /// signed-in user so the lobby can browse rooms nobody has joined yet.
  /// Nesting hands under matches/$matchId would inherit that open read
  /// instead -- RTDB read access only ever widens going down a path, it
  /// can't be narrowed by a rule on a child. See HAL-05.
  DatabaseReference _handsRef(String matchId) =>
      _db.ref('matchHands').child(matchId);

  Map<String, dynamic> _handUpdates(MatchState matchState) {
    final updates = <String, dynamic>{};
    matchState.handCards.forEach((uid, cards) {
      updates['matchHands/${matchState.id}/$uid'] = cards
          .map((c) => c.toJson())
          .toList();
    });
    return updates;
  }

  /// Merges a participant's private-hand snapshot into the public room state.
  ///
  /// Realtime Database removes empty lists instead of retaining empty array
  /// nodes. Consequently, `matchHands/$roomId` is a sparse map: a missing
  /// player key means that player's hand is empty, not that their old public
  /// hand count should be kept. Rebuild counts from the complete private
  /// snapshot whenever it has been read successfully.
  @visibleForTesting
  static Map<String, dynamic> mergePrivateHands(
    Map<String, dynamic> publicState,
    Object? privateHands,
  ) {
    final merged = Map<String, dynamic>.from(publicState);
    final hands = privateHands is Map
        ? Map<String, dynamic>.from(privateHands)
        : <String, dynamic>{};
    final playerIds = publicState['playerIds'];

    merged['handCards'] = hands;
    merged['handCounts'] = {
      if (playerIds is List)
        for (final playerId in playerIds)
          playerId.toString(): _privateHandLength(hands[playerId.toString()]),
    };
    return merged;
  }

  static int _privateHandLength(Object? hand) {
    if (hand is List) return hand.length;
    if (hand is Map) return hand.length;
    return 0;
  }

  /// Lightweight lobby index -- see room_summary.dart and HAL-06.
  DatabaseReference get roomsRef => _db.ref('rooms');
  DatabaseReference get _roomsRef => roomsRef;

  /// Creates a room through the server so the caller cannot choose another
  /// user's identity or race another room creator for the same id.
  Future<MatchState> createMatch(MatchState matchState) async {
    final data = await SupabaseBackendService.call(
      'createRoom',
      data: {
        'mode': matchState.mode.name,
        'maxPoints': matchState.maxPoints,
        'timerDurationSeconds': matchState.timerDurationSeconds,
        'isPublic': matchState.isPublic,
        'displayName': matchState.playerNames.isEmpty
            ? ''
            : matchState.playerNames.values.first,
        // Creation policy never rewrites an existing room's saved protocol.
        'protocolVersion': newOnlineRoomProtocol,
        'cardBackId': matchState.playerSkins.isEmpty
            ? ''
            : matchState.playerSkins.values.first,
        'avatarUrl': matchState.playerAvatars.isEmpty
            ? ''
            : matchState.playerAvatars.values.first,
      },
    );
    return MatchState.fromJson(Map<String, dynamic>.from(data['match'] as Map));
  }

  /// Sends player intent to the trusted match engine. The caller supplies the
  /// last observed [MatchState.serverVersion]; stale commands are rejected by
  /// the server instead of overwriting a newer turn.
  Future<MatchState> submitMatchCommand({
    required MatchState matchState,
    required String commandType,
    required String callerUid,
    Map<String, dynamic> payload = const {},
    String? actorUid,
    String? commandId,
  }) async {
    final data = await sendIdempotentMatchRequest(
      {
        'roomId': matchState.id,
        'commandId': commandId ?? _newCommandId(),
        'commandType': commandType,
        'expectedVersion': matchState.serverVersion,
        'commandPayload': payload,
        if (actorUid != null) 'actorUid': actorUid,
      },
      (intent) => SupabaseBackendService.call(
        'submitMatchCommand',
        data: intent,
        timeout: const Duration(seconds: 20),
      ),
    );
    return commandSnapshot(data, callerUid);
  }

  /// Private/public state in a command response belongs to one SQL revision.
  static MatchState commandSnapshot(
    Map<String, dynamic> data,
    String callerUid,
  ) {
    final publicValue = data['state'];
    if (publicValue is! Map) {
      throw const SupabaseBackendException('invalid_match_response');
    }
    final merged = Map<String, dynamic>.from(publicValue);
    final ownHand = data['hand'];
    merged['handCards'] = {
      callerUid: ownHand is List || ownHand is Map ? ownHand : [],
    };
    return MatchState.fromJson(merged);
  }

  Future<MatchState> getCommandSnapshot(
    String matchId,
    String callerUid,
  ) async {
    final data = await SupabaseBackendService.call(
      'getMatchSnapshot',
      data: {'roomId': matchId},
      timeout: const Duration(seconds: 20),
    );
    return commandSnapshot(data, callerUid);
  }

  /// Leaving may race a bot/timeout. Retry only a definite version rejection;
  /// ambiguous transport failures already reuse their original command ID.
  Future<void> leaveServerMatch(MatchState matchState, String callerUid) async {
    var current = matchState;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await submitMatchCommand(
          matchState: current,
          commandType: 'leave',
          callerUid: callerUid,
        );
        return;
      } on SupabaseBackendException catch (error) {
        if (error.code == 'not_room_participant' ||
            error.code == 'room_not_found')
          return;
        if (error.code != 'version_conflict' || error.details['state'] is! Map)
          rethrow;
        current = commandSnapshot(error.details, callerUid);
        if (!current.playerIds.contains(callerUid)) return;
        if (attempt == 2) rethrow;
      }
    }
  }

  /// Only completed server-protocol rooms can award trusted profile changes.
  /// The server's immutable match receipt makes a lost response safe to retry.
  Future<MatchState> settleMatchRewards(
    MatchState matchState,
    String callerUid,
  ) async {
    if (matchState.protocolVersion != 1) {
      throw const SupabaseBackendException('rewards_not_ready');
    }
    final data = await sendIdempotentMatchRequest(
      {'roomId': matchState.id},
      (intent) => SupabaseBackendService.call(
        'settleMatchRewards',
        data: intent,
        timeout: const Duration(seconds: 40),
      ),
    );
    return commandSnapshot(data, callerUid);
  }

  String _newCommandId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Update an entire existing match state
  Future<void> updateMatchState(
    MatchState matchState, {
    bool refreshRoomIndex = false,
  }) async {
    validateLegacyWrite(matchState);
    // The public state and private hands must change in the same RTDB update.
    // Two sequential writes briefly exposed a new turn with old cards and
    // made reconnects vulnerable to observing a mismatched snapshot.
    final updates = <String, dynamic>{
      'matches/${matchState.id}': matchState.toJson(),
      ..._handUpdates(matchState),
    };
    await _db.ref().update(updates);
    if (!refreshRoomIndex) return;
    // The lobby index is server-written from the persisted match, avoiding
    // client-forged room summaries and keeping phase/seat changes visible.
    try {
      await SupabaseBackendService.call(
        'refreshRoomIndex',
        data: {'roomId': matchState.id},
      );
    } catch (e) {
      // Index refresh must not roll back a successfully persisted move; the
      // next state update or scheduled cleanup will reconcile it.
      if (kDebugMode)
        debugPrint('Could not refresh room index for ${matchState.id}: $e');
    }
  }

  static void validateLegacyWrite(MatchState matchState) {
    if (matchState.usesServerCommands) {
      throw const SupabaseBackendException('server_match_requires_command');
    }
  }

  /// Deletes a room through the admin-only server endpoint.
  Future<void> deleteMatch(String matchId) async {
    await SupabaseBackendService.call('deleteRoom', data: {'roomId': matchId});
  }

  /// Atomically claims a waiting seat through the server.
  Future<MatchState> joinRoom({
    required String roomId,
    required String displayName,
    required String cardBackId,
    required String avatarUrl,
    required String callerUid,
  }) async {
    final data = await SupabaseBackendService.call(
      'joinRoom',
      data: {
        'roomId': roomId,
        'displayName': displayName,
        'cardBackId': cardBackId,
        'avatarUrl': avatarUrl,
      },
    );
    final joined = MatchState.fromJson(
      Map<String, dynamic>.from(data['match'] as Map),
    );
    // The join response's hand must not be dropped for active replacements.
    return joined.usesServerCommands
        ? commandSnapshot({...data, 'state': data['match']}, callerUid)
        : joined;
  }

  /// Watches the public match node and the (participant-only) hands tree
  /// together, merging both into one MatchState stream. Kept as a manual
  /// two-subscription merge rather than combining via a Stream library --
  /// this file has no reactive-streams dependency to reach for, and the
  /// merge itself is small enough not to need one.
  Stream<MatchState?> watchMatch(
    String matchId, {
    String? callerUid,
    bool spectator = false,
  }) async* {
    if (spectator) {
      yield* matchRef.child(matchId).onValue.map((event) {
        final value = event.snapshot.value;
        return value is Map
            ? publicSnapshot(Map<String, dynamic>.from(value))
            : null;
      });
      return;
    }
    // Inspect the protocol before subscribing to the private tree. Server
    // rooms never read matchHands/$id (which would reveal opponents' cards).
    final initial = await matchRef.child(matchId).get();
    final value = initial.value;
    final publicState = value is Map ? Map<String, dynamic>.from(value) : null;
    if (publicState == null) {
      yield null;
      return;
    }
    if (((publicState['protocolVersion'] as num?)?.toInt() ?? 0) > 0) {
      if (callerUid == null || callerUid.isEmpty) {
        throw const SupabaseBackendException('unauthenticated');
      }
      yield* watchCommandSnapshots(
        roomId: matchId,
        callerUid: callerUid,
        notifications: matchRef.child(matchId).onValue.map((event) {
          final value = event.snapshot.value;
          return value is Map ? Map<String, dynamic>.from(value) : null;
        }),
        fetchSnapshot: () => getCommandSnapshot(matchId, callerUid),
      );
      return;
    }
    yield* _watchLegacyMatch(matchId);
  }

  Stream<MatchState?> _watchLegacyMatch(String matchId) {
    final controller = StreamController<MatchState?>.broadcast();
    Map<String, dynamic>? latestPublic;
    Object? latestHands;
    var havePublic = false;
    var haveHandsSnapshot = false;

    void emit() {
      if (!havePublic || latestPublic == null) {
        controller.add(null);
        return;
      }
      try {
        final merged = haveHandsSnapshot
            ? mergePrivateHands(latestPublic!, latestHands)
            : Map<String, dynamic>.from(latestPublic!);
        controller.add(MatchState.fromJson(merged));
      } catch (e) {
        if (kDebugMode)
          debugPrint('CRITICAL: Error parsing match state for $matchId: $e');
        controller.addError(e);
      }
    }

    final publicSub = matchRef
        .child(matchId)
        .onValue
        .listen(
          (event) {
            final value = event.snapshot.value;
            havePublic = true;
            latestPublic = (value is Map)
                ? Map<String, dynamic>.from(value)
                : null;
            emit();
          },
          onError: (error) {
            if (kDebugMode)
              debugPrint('STREAM ERROR for match $matchId: $error');
            controller.addError(error);
          },
        );

    final handsSub = _handsRef(matchId).onValue.listen(
      (event) {
        final value = event.snapshot.value;
        latestHands = (value is Map) ? value : null;
        haveHandsSnapshot = true;
        if (havePublic) emit();
      },
      onError: (error) {
        // Expected before you've joined a match (matchHands read is
        // participant-only) -- leave handCards empty rather than surfacing it.
        if (kDebugMode)
          debugPrint(
            'Hands stream error for $matchId (not a participant yet?): $error',
          );
        latestHands = null;
      },
    );

    controller.onCancel = () {
      publicSub.cancel();
      handsSub.cancel();
    };

    return controller.stream;
  }

  /// Spectators never subscribe to any private tree or participant endpoint.
  static MatchState publicSnapshot(Map<String, dynamic> publicState) =>
      MatchState.fromJson({...publicState, 'handCards': <String, dynamic>{}});

  /// Sync presence for a player: sets online status and removes it on disconnect
  Future<void> syncPresence(String matchId, String playerId) async {
    final presenceRef = matchRef
        .child(matchId)
        .child('presence')
        .child(playerId);
    // Set online status to true
    await presenceRef.set(true);
    // Set onDisconnect behavior
    await presenceRef.onDisconnect().remove();
  }

  /// Remove presence for a player manually
  Future<void> removePresence(String matchId, String playerId) async {
    await matchRef.child(matchId).child('presence').child(playerId).remove();
    await matchRef
        .child(matchId)
        .child('playerLastActive')
        .child(playerId)
        .remove();
  }

  /// Update heartbeat timestamp for AFK detection
  Future<void> heartbeat(String matchId, String playerId) async {
    await matchRef
        .child(matchId)
        .child('playerLastActive')
        .child(playerId)
        .set(DateTime.now().toIso8601String());
  }

  /// Watch presence changes for all players in a match
  Stream<Map<String, bool>> watchPresence(String matchId) {
    return matchRef.child(matchId).child('presence').onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null || value is! Map) return <String, bool>{};
      return Map<String, bool>.from(
        value.map((k, v) => MapEntry(k.toString(), v == true)),
      );
    });
  }

  /// Listen to joinable public rooms via the lightweight rooms/ index
  /// instead of the full matches/ tree -- see HAL-06. Every client sitting
  /// on the lobby used to re-download and re-parse every match's complete
  /// object (board, chat, playHistory, presence, ...) on every single write
  /// to any match, active games included; the index carries only what
  /// PublicRoomsList actually needs (see room_summary.dart).
  Stream<List<RoomSummary>> watchPublicMatches() {
    return _roomsRef.onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null || value is! Map) return <RoomSummary>[];
      try {
        final rooms = <RoomSummary>[];
        final now = DateTime.now();

        value.forEach((id, data) {
          try {
            if (data is! Map) return;
            final room = RoomSummary.fromJson(id.toString(), data);

            // Expired rooms are not joinable. Deletion is server-owned; a
            // lobby observer must never be able to delete another room.
            if (room.expireAt != null && now.isAfter(room.expireAt!)) {
              return;
            }

            if (room.isVisiblePublic(now)) {
              rooms.add(room);
            }
          } catch (e) {
            // Skip invalid data
          }
        });

        return rooms;
      } catch (e) {
        debugPrint('Error parsing rooms index: $e');
        return <RoomSummary>[];
      }
    });
  }

  /// Join an existing matchmaking queue
  Future<void> joinMatchQueue(String playerId) async {
    final queueRef = _db.ref('matchmaking_queue');
    await queueRef.child(playerId).set({'timestamp': ServerValue.timestamp});
  }

  /// Add a specific action/move event to a log (if needed for replay or verification)
  Future<void> submitAction(
    String matchId,
    String playerId,
    Map<String, dynamic> actionData,
  ) async {
    final actionRef = matchRef.child(matchId).child('actions').push();
    await actionRef.set({
      'playerId': playerId,
      'timestamp': ServerValue.timestamp,
      'data': actionData,
    });
  }

  /// Send a match invitation through the server. The function validates that
  /// the caller is seated in a waiting room and that the recipient is their
  /// Supabase friend; clients never write another user's invite map.
  Future<void> sendInvite(String toUid, String matchId) async {
    await SupabaseBackendService.call(
      'sendRoomInvite',
      data: {'toUid': toUid, 'roomId': matchId},
    );
  }

  /// Search for users by display name (basic prefix search)
  Future<List<AppUser>> searchUsers(String query) async {
    try {
      final lowercaseQuery = query.toLowerCase().replaceAll('@', '').trim();
      final firestore = FirebaseFirestore.instance;

      final snapshot = await firestore
          .collection('users')
          .where('searchName', isGreaterThanOrEqualTo: lowercaseQuery)
          .where('searchName', isLessThanOrEqualTo: '$lowercaseQuery\uf8ff')
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) {
            try {
              return AppUser.fromJson(doc.data(), doc.id);
            } catch (e) {
              debugPrint('Error parsing user ${doc.id}: $e');
              return null;
            }
          })
          .whereType<AppUser>()
          .toList();
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }

  /// Send a friend request.
  ///
  /// Routed through the Supabase Edge Function: this writes to the *other* user's
  /// document, which both database.rules.json and firestore.rules only ever
  /// allow that user themselves to write. Direct RTDB + Firestore writes
  /// from here always failed with PERMISSION_DENIED; Firestore is now the
  /// social graph's sole source of truth (RTDB's copy was an unread,
  /// silently-drifting duplicate) and functions/index.js's
  /// sendFriendRequest validates the real caller via the Admin SDK, which
  /// bypasses rules entirely. See HAL-07. `fromUid` is kept for API
  /// compatibility with existing call sites -- the function trusts only
  /// request.auth.uid, never a client-supplied sender id.
  Future<void> sendFriendRequest(String fromUid, String toUid) async {
    await SupabaseBackendService.call(
      'sendFriendRequest',
      data: {'toUid': toUid},
    );
  }

  /// Accept a friend request. See sendFriendRequest for why this is a
  /// callable rather than a direct write.
  Future<void> acceptFriendRequest(String myUid, String friendUid) async {
    await SupabaseBackendService.call(
      'respondToFriendRequest',
      data: {'fromUid': friendUid, 'accept': true},
    );
  }

  /// Reject a friend request. See sendFriendRequest for why this is a
  /// callable rather than a direct write.
  Future<void> rejectFriendRequest(String myUid, String friendUid) async {
    await SupabaseBackendService.call(
      'respondToFriendRequest',
      data: {'fromUid': friendUid, 'accept': false},
    );
  }

  /// CHAT: Send a message to the match chat
  Future<void> sendChatMessage(
    String matchId,
    ChatMessage message, {
    String channel = 'public',
    bool legacy = false,
  }) async {
    if (matchId.isEmpty || matchId.startsWith('OFFLINE_')) return;
    if (!['public', 'teamA', 'teamB'].contains(channel))
      throw StateError('invalid_chat_channel');
    if (legacy) {
      if (channel != 'public') throw StateError('legacy_team_chat_unavailable');
      final chatRef = matchRef.child(matchId).child('chat').push();
      await chatRef.set({...message.toJson(), 'id': chatRef.key});
      return;
    }
    final root = _db.ref('matchChat').child(matchId);
    final chatRef = root.child(channel).push();
    await root.update({
      '$channel/${chatRef.key}': {
        ...message.toJson(),
        'id': chatRef.key,
        'timestamp': ServerValue.timestamp,
      },
      'rate/${message.senderId}': ServerValue.timestamp,
    });
  }

  Stream<List<ChatMessage>> watchChatMessages(
    String matchId, {
    String channel = 'public',
    bool legacy = false,
  }) {
    if (matchId.isEmpty || matchId.startsWith('OFFLINE_'))
      return Stream.value([]);

    if (!['public', 'teamA', 'teamB'].contains(channel))
      return Stream.error(StateError('invalid_chat_channel'));
    return (legacy
            ? matchRef.child(matchId).child('chat')
            : _db.ref('matchChat').child(matchId).child(channel))
        .orderByKey()
        .limitToLast(50)
        .onValue
        .map((event) {
          final value = event.snapshot.value;
          if (value == null) return <ChatMessage>[];

          Map<dynamic, dynamic> messages;
          if (value is List) {
            messages = value.asMap();
          } else if (value is Map) {
            messages = value;
          } else {
            debugPrint('Chat data is not a Map or List: ${value.runtimeType}');
            return <ChatMessage>[];
          }

          final list = messages.entries
              .map((entry) {
                final val = entry.value;
                if (val == null || val is! Map) return null;
                try {
                  return ChatMessage.fromJson(
                    Map<String, dynamic>.from(val),
                    entry.key.toString(),
                  );
                } catch (e) {
                  debugPrint('Error parsing chat message at ${entry.key}: $e');
                  return null;
                }
              })
              .whereType<ChatMessage>()
              .toList();

          // Ensure consistent chronological order
          list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          return list;
        })
        .handleError((error) {
          debugPrint('CHAT STREAM ERROR for $matchId: $error');
          return <ChatMessage>[];
        });
  }
}
