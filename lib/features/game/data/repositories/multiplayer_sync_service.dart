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

  /// Listen to an active match state
  Stream<MatchState?> watchMatch(String matchId) {
    return _matchRef.child(matchId).onValue.map((event) {
      if (event.snapshot.value == null) return null;
      try {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        return MatchState.fromJson(data);
      } catch (e) {
        debugPrint('Error parsing match state: \$e');
        return null;
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
}
