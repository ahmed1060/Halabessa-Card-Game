import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/match_state.dart';
import '../../domain/models/chat_message.dart';
import '../../../auth/domain/models/app_user.dart';

class MultiplayerSyncService {
  final FirebaseDatabase _db;

  MultiplayerSyncService(this._db);

  DatabaseReference get matchRef => _db.ref('matches');

  /// Create a new match room in Firebase Realtime Database
  Future<void> createMatch(MatchState matchState) async {
    await matchRef.child(matchState.id).set(matchState.toJson());
  }

  /// Update an entire existing match state
  Future<void> updateMatchState(MatchState matchState) async {
    await matchRef.child(matchState.id).update(matchState.toJson());
  }

  /// Delete a match room
  Future<void> deleteMatch(String matchId) async {
    await matchRef.child(matchId).remove();
  }

  Stream<MatchState?> watchMatch(String matchId) {
    return matchRef.child(matchId).onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null || value is! Map) return null;
      
      try {
        return MatchState.fromJson(value);
      } catch (e) {
        debugPrint('CRITICAL: Error parsing match state for $matchId: $e');
        return null;
      }
    }).handleError((error) {
      debugPrint('STREAM ERROR for match $matchId: $error');
      return null;
    });
  }

  /// Sync presence for a player: sets online status and removes it on disconnect
  Future<void> syncPresence(String matchId, String playerId) async {
    final presenceRef = matchRef.child(matchId).child('presence').child(playerId);
    // Set online status to true
    await presenceRef.set(true);
    // Set onDisconnect behavior
    await presenceRef.onDisconnect().remove();
  }

  /// Watch presence changes for all players in a match
  Stream<Map<String, bool>> watchPresence(String matchId) {
    return matchRef.child(matchId).child('presence').onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null || value is! Map) return <String, bool>{};
      return Map<String, bool>.from(value.map((k, v) => MapEntry(k.toString(), v == true)));
    });
  }

  /// Listen to all public matches
  Stream<List<MatchState>> watchPublicMatches() {
    return matchRef.onValue.map((event) {
      if (event.snapshot.value == null) return [];
      try {
        if (event.snapshot.value is! Map) return [];
        final Map<dynamic, dynamic> matches = event.snapshot.value as Map<dynamic, dynamic>;
        
        final List<MatchState> validMatches = [];
        final now = DateTime.now();

        matches.forEach((id, data) {
          try {
            if (data is! Map) return;
            final match = MatchState.fromJson(Map<String, dynamic>.from(data));
            
            // AUTO-DESTRUCT: If the room is expired, delete it and don't show it
            if (match.expireAt != null && now.isAfter(match.expireAt!)) {
              deleteMatch(match.id);
              return;
            }

            if (match.isPublic && match.phase == GamePhase.waitingForPlayers) {
              validMatches.add(match);
            }
          } catch (e) {
            // Skip invalid data
          }
        });

        return validMatches;
      } catch (e) {
        debugPrint('Error parsing public matches: $e');
        return [];
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

  /// Send a match invitation to a friend
  Future<void> sendInvite(String toUid, String matchId, String senderName) async {
    final inviteRef = _db.ref('users').child(toUid).child('friendInvites').child(matchId);
    await inviteRef.set(senderName);
  }

  /// Search for users by display name (basic prefix search)
  Future<List<AppUser>> searchUsers(String query) async {
    final usersRef = _db.ref('users');
    final lowercaseQuery = query.toLowerCase();
    final snapshot = await usersRef.orderByChild('searchName')
        .startAt(lowercaseQuery)
        .endAt('$lowercaseQuery\uf8ff')
        .limitToFirst(20)
        .get();
    
    if (snapshot.value is! Map) return [];
    
    final Map<dynamic, dynamic> users = snapshot.value as Map<dynamic, dynamic>;
    return users.entries.map((entry) {
      if (entry.value is! Map) return null;
      return AppUser.fromJson(Map<String, dynamic>.from(entry.value as Map), entry.key as String);
    }).whereType<AppUser>().toList();
  }

  /// Accept a friend request / Add a friend
  Future<void> addFriend(String myUid, String friendUid) async {
    final myFriendsRef = _db.ref('users').child(myUid).child('friends');
    final friendFriendsRef = _db.ref('users').child(friendUid).child('friends');
    
    // Add to my list
    final mySnap = await myFriendsRef.get();
    final myFriends = List<String>.from((mySnap.value as List?) ?? [])..add(friendUid);
    await myFriendsRef.set(myFriends);
    
    // Add to friend's list (mutual)
    final friendSnap = await friendFriendsRef.get();
    final friendFriends = List<String>.from((friendSnap.value as List?) ?? [])..add(myUid);
    await friendFriendsRef.set(friendFriends);
  }

  /// CHAT: Send a message to the match chat
  Future<void> sendChatMessage(String matchId, ChatMessage message) async {
    final chatRef = matchRef.child(matchId).child('chat').push();
    await chatRef.set(message.toJson());
  }

  Stream<List<ChatMessage>> watchChatMessages(String matchId) {
    if (matchId.isEmpty) return Stream.value([]);
    
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
