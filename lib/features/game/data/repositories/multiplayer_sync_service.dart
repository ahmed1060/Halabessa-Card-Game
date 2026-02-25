import 'package:firebase_database/firebase_database.dart';
import '../../domain/models/match_state.dart';
import 'package:flutter/foundation.dart';

class MultiplayerSyncService {
  final FirebaseDatabase _db;

  MultiplayerSyncService(this._db);

  DatabaseReference get _matchRef => _db.ref('matches');

  /// Create a new match room in Firebase Realtime Database
  Future<void> createMatch(MatchState matchState) async {
    await _matchRef.child(matchState.id).set(matchState.toJson());
  }

  /// Update an entire existing match state
  Future<void> updateMatchState(MatchState matchState) async {
    await _matchRef.child(matchState.id).update(matchState.toJson());
  }

  Stream<MatchState?> watchMatch(String matchId) {
    return _matchRef.child(matchId).onValue.map((event) {
      if (event.snapshot.value == null) return null;
      try {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        return MatchState.fromJson(Map<String, dynamic>.from(data));
      } catch (e) {
        debugPrint('Error parsing match state: $e');
        return null;
      }
    });
  }

  /// Listen to all public matches
  Stream<List<MatchState>> watchPublicMatches() {
    return _matchRef.onValue.map((event) {
      if (event.snapshot.value == null) return [];
      try {
        final Map<dynamic, dynamic> matches = event.snapshot.value as Map<dynamic, dynamic>;
        return matches.entries
            .map((entry) {
              try {
                return MatchState.fromJson(Map<String, dynamic>.from(entry.value as Map));
              } catch (e) {
                return null;
              }
            })
            .whereType<MatchState>()
            .where((match) => match.isPublic && match.phase == GamePhase.waitingForPlayers && match.playerIds.length < 4)
            .toList();
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
    final actionRef = _matchRef.child(matchId).child('actions').push();
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
    final snapshot = await usersRef.orderByChild('displayName')
        .startAt(query)
        .endAt('$query\uf8ff')
        .limitToFirst(20)
        .get();
    
    if (snapshot.value == null) return [];
    
    final Map<dynamic, dynamic> users = snapshot.value as Map<dynamic, dynamic>;
    return users.entries.map((entry) {
      return AppUser.fromJson(Map<String, dynamic>.from(entry.value as Map), entry.key as String);
    }).toList();
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
}
