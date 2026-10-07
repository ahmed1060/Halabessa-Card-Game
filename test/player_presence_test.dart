import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/core/services/player_presence.dart';

void main() {
  test(
    'presence requires one fresh connection and treats stale/malformed data offline',
    () {
      final now = DateTime.utc(2026, 10, 7);
      final n = now.millisecondsSinceEpoch;
      expect(
        hasFreshPresence({
          'phone': {'lastSeen': n - 30000},
          'browser': {'lastSeen': n - 90000},
        }, now),
        isTrue,
      );
      expect(
        hasFreshPresence({
          'browser': {'lastSeen': n - 75001},
        }, now),
        isFalse,
      );
      expect(
        hasFreshPresence({
          'browser': {'lastSeen': n + 10000},
        }, now),
        isFalse,
      );
      expect(
        hasFreshPresence({
          'browser': {'lastSeen': 'fake'},
        }, now),
        isFalse,
      );
      expect(hasFreshPresence(null, now), isFalse);
    },
  );
}
