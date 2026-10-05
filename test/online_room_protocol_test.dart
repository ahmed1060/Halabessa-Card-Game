import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/logic/online_room_protocol.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';

void main() {
  test('new room policy honors the rollback flag and defaults to server control', () {
    const configured = bool.fromEnvironment('HALABESSA_SERVER_MATCHES', defaultValue: true);
    expect(newOnlineRoomProtocol, configured ? 1 : 0);
  });
  test('creation policy cannot migrate legacy rooms or offline training', () {
    final legacy = MatchState.fromJson({'id': 'OLD_ROOM', 'mode': 'classic', 'playerIds': ['human']});
    final training = MatchState.fromJson({...legacy.toJson(), 'id': 'OFFLINE_TRAINING'});
    expect(legacy.usesServerCommands, false);
    expect(training.usesServerCommands, false);
    expect(legacy.copyWith(teamAScore: 2).protocolVersion, 0);
    expect(MatchState.fromJson({...legacy.toJson(), 'protocolVersion': 1}).usesServerCommands, true);
  });
}
