import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:halabessa/core/services/supabase_backend_service.dart';
import '../../domain/models/match_state.dart';
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
  DatabaseReference _handsRef(String matchId) => _db.ref('matchHands').child(matchId);

  Map<String, dynamic> _handUpdates(MatchState matchState) {
    final updates = <String, dynamic>{};
    matchState.handCards.forEach((uid, cards) {
      updates['matchHands/${matchState.id}/$uid'] = cards.map((c) => c.toJson()).toList();
    });
    return updates;
  }

  /// Lightweight lobby index -- see room_summary.dart and HAL-06.
  DatabaseReference get roomsRef => _db.ref('rooms');
  DatabaseReference get _roomsRef => roomsRef;

  /// Creates a room through the server so the caller cannot choose another
  /// user's identity or race another room creator for the same id.
  Future<MatchState> createMatch(MatchState matchState) async {
    final data = await SupabaseBackendService.call('createRoom', data: {
      'mode': matchState.mode.name,
      'maxPoints': matchState.maxPoints,
      'timerDurationSeconds': matchState.timerDurationSeconds,
      'isPublic': matchState.isPublic,
      'displayName': matchState.playerNames.isEmpty ? '' : matchState.playerNames.values.first,
      'cardBackId': matchState.playerSkins.isEmpty ? '' : matchState.playerSkins.values.first,
      'avatarUrl': matchState.playerAvatars.isEmpty ? '' : matchState.playerAvatars.values.first,
    });
    return MatchState.fromJson(Map<String, dynamic>.from(data['match'] as Map));
  }

  /// Update an entire existing match state
  Future<void> updateMatchState(MatchState matchState, {bool refreshRoomIndex = false}) async {
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
      if (kDebugMode) debugPrint('Could not refresh room index for ${matchState.id}: $e');
    }
  }

  /// Deletes a room through the admin-only server endpoint.
  Future<void> deleteMatch(String matchId) async {
    await FirebaseFunctions.instance.httpsCallable('deleteRoom').call({'roomId': matchId});
  }

  /// Atomically claims a waiting seat through the server.
  Future<MatchState> joinRoom({
    required String roomId,
    required String displayName,
    required String cardBackId,
    required String avatarUrl,
  }) async {
    final data = await SupabaseBackendService.call('joinRoom', data: {
      'roomId': roomId,
      'displayName': displayName,
      'cardBackId': cardBackId,
      'avatarUrl': avatarUrl,
    });
    return MatchState.fromJson(Map<String, dynamic>.from(data['match'] as Map));
  }

  /// Watches the public match node and the (participant-only) hands tree
  /// together, merging both into one MatchState stream. Kept as a manual
  /// two-subscription merge rather than combining via a Stream library --
  /// this file has no reactive-streams dependency to reach for, and the
  /// merge itself is small enough not to need one.
  Stream<MatchState?> watchMatch(String matchId) {
    final controller = StreamController<MatchState?>.broadcast();
    Map<String, dynamic>? latestPublic;
    Object? latestHands;
    var havePublic = false;

    void emit() {
      if (!havePublic || latestPublic == null) {
        controller.add(null);
        return;
      }
      try {
        final merged = Map<String, dynamic>.from(latestPublic!);
        if (latestHands != null) merged['handCards'] = latestHands;
        controller.add(MatchState.fromJson(merged));
      } catch (e) {
        if (kDebugMode) debugPrint('CRITICAL: Error parsing match state for $matchId: $e');
        controller.add(null);
      }
    }

    final publicSub = matchRef.child(matchId).onValue.listen((event) {
      final value = event.snapshot.value;
      havePublic = true;
      latestPublic = (value is Map) ? Map<String, dynamic>.from(value) : null;
      emit();
    }, onError: (error) {
      if (kDebugMode) debugPrint('STREAM ERROR for match $matchId: $error');
      controller.add(null);
    });

    final handsSub = _handsRef(matchId).onValue.listen((event) {
      final value = event.snapshot.value;
      latestHands = (value is Map) ? value : null;
      if (havePublic) emit();
    }, onError: (error) {
      // Expected before you've joined a match (matchHands read is
      // participant-only) -- leave handCards empty rather than surfacing it.
      if (kDebugMode) debugPrint('Hands stream error for $matchId (not a participant yet?): $error');
      latestHands = null;
    });

    controller.onCancel = () {
      publicSub.cancel();
      handsSub.cancel();
    };

    return controller.stream;
  }

  /// Sync presence for a player: sets online status and removes it on disconnect
  Future<void> syncPresence(String matchId, String playerId) async {
    final presenceRef = matchRef.child(matchId).child('presence').child(playerId);
    // Set online status to true
    await presenceRef.set(true);
    // Set onDisconnect behavior
    await presenceRef.onDisconnect().remove();
  }

  /// Remove presence for a player manually
  Future<void> removePresence(String matchId, String playerId) async {
    await matchRef.child(matchId).child('presence').child(playerId).remove();
    await matchRef.child(matchId).child('playerLastActive').child(playerId).remove();
  }

  /// Update heartbeat timestamp for AFK detection
  Future<void> heartbeat(String matchId, String playerId) async {
    await matchRef.child(matchId).child('playerLastActive').child(playerId).set(DateTime.now().toIso8601String());
  }

  /// Watch presence changes for all players in a match
  Stream<Map<String, bool>> watchPresence(String matchId) {
    return matchRef.child(matchId).child('presence').onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null || value is! Map) return <String, bool>{};
      return Map<String, bool>.from(value.map((k, v) => MapEntry(k.toString(), v == true)));
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

            if (room.isPublic && room.phase == GamePhase.waitingForPlayers) {
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
  Future<void> submitAction(String matchId, String playerId, Map<String, dynamic> actionData) async {
    final actionRef = matchRef.child(matchId).child('actions').push();
    await actionRef.set({
      'playerId': playerId,
      'timestamp': ServerValue.timestamp,
      'data': actionData,
    });
  }

  /// Send a match invitation through the server. The function validates that
  /// the caller is seated in a waiting room and that the recipient is their
  /// Firestore friend; clients never write another user's invite map.
  Future<void> sendInvite(String toUid, String matchId) async {
    await FirebaseFunctions.instance
        .httpsCallable('sendRoomInvite')
        .call({'toUid': toUid, 'roomId': matchId});
  }

  /// Search for users by display name (basic prefix search)
  Future<List<AppUser>> searchUsers(String query) async {
    try {
      final lowercaseQuery = query.toLowerCase().replaceAll('@', '').trim();
      final firestore = FirebaseFirestore.instance;
      
      final snapshot = await firestore.collection('users')
          .where('searchName', isGreaterThanOrEqualTo: lowercaseQuery)
          .where('searchName', isLessThanOrEqualTo: '$lowercaseQuery\uf8ff')
          .limit(20)
          .get();
      
      return snapshot.docs.map((doc) {
        try {
          return AppUser.fromJson(doc.data(), doc.id);
        } catch (e) {
          debugPrint('Error parsing user ${doc.id}: $e');
          return null;
        }
      }).whereType<AppUser>().toList();
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
    await SupabaseBackendService.call('sendFriendRequest', data: {'toUid': toUid});
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
  Future<void> sendChatMessage(String matchId, ChatMessage message) async {
    if (matchId.isEmpty || matchId.startsWith('OFFLINE_')) return;
    final chatRef = matchRef.child(matchId).child('chat').push();
    await chatRef.set(message.toJson());
  }

  Stream<List<ChatMessage>> watchChatMessages(String matchId) {
    if (matchId.isEmpty || matchId.startsWith('OFFLINE_')) return Stream.value([]);
    
    return matchRef.child(matchId).child('chat')
      .orderByKey()
      .limitToLast(50)
      .onValue.map((event) {
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
        
        final list = messages.entries.map((entry) {
          final val = entry.value;
          if (val == null || val is! Map) return null;
          try {
            return ChatMessage.fromJson(Map<String, dynamic>.from(val), entry.key.toString());
          } catch (e) {
            debugPrint('Error parsing chat message at ${entry.key}: $e');
            return null;
          }
        }).whereType<ChatMessage>().toList();
        
        // Ensure consistent chronological order
        list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        return list;
      }).handleError((error) {
        debugPrint('CHAT STREAM ERROR for $matchId: $error');
        return <ChatMessage>[];
      });
  }
}
