import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/core/services/supabase_backend_service.dart';
import 'package:halabessa/features/game/data/repositories/multiplayer_sync_service.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';

class FakeDatabase implements FirebaseDatabase {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('Unexpected database access');
}

class LeavingService extends MultiplayerSyncService {
  LeavingService() : super(FakeDatabase());
  final seenVersions = <int>[];
  final errors = <SupabaseBackendException>[];
  @override
  Future<MatchState> submitMatchCommand({required MatchState matchState,
    required String commandType, required String callerUid,
    Map<String, dynamic> payload = const {}, String? actorUid, String? commandId}) async {
    expect(commandType, 'leave');
    expect(callerUid, 'human');
    seenVersions.add(matchState.serverVersion);
    if (errors.isNotEmpty) throw errors.removeAt(0);
    return matchState;
  }
}

void main() {
  final s = MatchState.fromJson({'id': 'ROOM1234', 'mode': 'classic',
    'protocolVersion': 1, 'serverVersion': 3, 'playerIds': ['human']});
  SupabaseBackendException conflict(int revision) => SupabaseBackendException(
    'version_conflict', details: {'state': s.copyWith(serverVersion: revision).toJson()});

  test('explicit leave retries definite competing-turn rejection with new revision', () async {
    final service = LeavingService()..errors.add(conflict(4));
    await service.leaveServerMatch(s, 'human');
    expect(service.seenVersions, [3, 4]);
  });
  test('already released seat is a completed leave, not another bot replacement', () async {
    final service = LeavingService()..errors.add(const SupabaseBackendException('not_room_participant'));
    await service.leaveServerMatch(s, 'human');
    expect(service.seenVersions, [3]);
  });
  test('version contention is bounded, not an infinite command loop', () async {
    final service = LeavingService()..errors.addAll([conflict(4), conflict(5), conflict(6)]);
    await expectLater(service.leaveServerMatch(s, 'human'), throwsA(isA<SupabaseBackendException>()));
    expect(service.seenVersions, [3, 4, 5]);
  });
  test('ambiguous network failures do not invent a new leave intent', () async {
    final service = LeavingService()..errors.add(const SupabaseBackendException('backend_unavailable'));
    await expectLater(service.leaveServerMatch(s, 'human'), throwsA(isA<SupabaseBackendException>()));
    expect(service.seenVersions, [3]);
  });
}
