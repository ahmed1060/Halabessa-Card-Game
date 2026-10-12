import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/logic/online_match_clock.dart';

void main() {
  test(
    'server offset corrects skew; elapsed clock ignores local wall-clock edits',
    () {
      final base = DateTime.utc(2026, 10, 12);
      var wall = base.add(const Duration(minutes: 10));
      var elapsed = Duration.zero;
      final clock = OnlineMatchClock(wall: () => wall, elapsed: () => elapsed);
      expect(clock.now(), wall);
      clock.calibrate(-600000);
      expect(clock.now(), base);
      wall = wall.add(const Duration(hours: 4));
      elapsed = const Duration(milliseconds: 450);
      expect(clock.now(), base.add(elapsed));
      clock.calibrate(null);
      clock.calibrate(double.nan);
      clock.calibrate(double.infinity);
    clock.calibrate(1e100);
      expect(clock.now(), base.add(elapsed));
      clock.calibrate(
        -15000000,
      ); // Reconnect/resume calibration with new wall time.
      expect(clock.now(), base);
      elapsed += const Duration(seconds: 2);
      expect(clock.now(), base.add(const Duration(seconds: 2)));
    },
  );
}
