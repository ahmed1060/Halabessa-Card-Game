import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/models/room_summary.dart';

void main() {
  final now = DateTime.utc(2026, 10, 4);
  RoomSummary summary([Map<String, dynamic> changes = const {}]) => RoomSummary.fromJson('ROOM1234', {
    'mode': 'classic', 'isPublic': true, 'phase': 'playing', 'protocolVersion': 1,
    'playerIds': ['a', 'bot_1', 'bot_replacement_2', 'd'],
    'replacementSeatCount': 1, 'safeReplacementSeatCount': 1, ...changes,
  });
  test('public replacement visible and joinable without placeholder seats', () {
    final s = summary();
    expect(s.isVisiblePublic(now), true);
    expect(s.isJoinable(now), true);
    expect(s.openSeatCount, 1);
    expect(RoomSummary.fromJson(s.id, s.toJson()).isJoinable(now), true);
  });
  test('bot current-turn vacancy stays visible but cannot be joined yet', () {
    final s = summary({'safeReplacementSeatCount': 0});
    expect(s.isVisiblePublic(now), true);
    expect(s.isJoinable(now), false);
  });
  test('initial bots alone do not make a vacancy', () {
    final s = summary({'replacementSeatCount': 0, 'safeReplacementSeatCount': 0});
    expect(s.isVisiblePublic(now), false);
    expect(s.isJoinable(now), false);
  });
  test('private, expired, legacy and results rooms cannot advertise a replacement', () {
    for (final changes in [
      {'isPublic': false}, {'expireAt': now.toIso8601String()},
      {'protocolVersion': 0}, {'protocolVersion': 2}, {'phase': 'matchOver'},
    ]) {
      expect(summary(changes).isVisiblePublic(now), false);
      expect(summary(changes).isJoinable(now), false);
    }
  });
  test('legacy waiting rooms retain placeholder-based availability', () {
    final s = RoomSummary.fromJson('OLD12345', {'isPublic': true,
      'playerIds': ['a', 'waiting_1', 'waiting_2', 'waiting_3']});
    expect(s.isVisiblePublic(now), true);
    expect(s.isJoinable(now), true);
    expect(s.openSeatCount, 3);
  });
  test('malformed index counts do not exceed the four seats', () {
    expect(summary({'replacementSeatCount': -20}).replacementSeatCount, 0);
    expect(summary({'safeReplacementSeatCount': 80}).safeReplacementSeatCount, 4);
  });
}
