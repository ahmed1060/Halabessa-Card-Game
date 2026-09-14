import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/core/services/daily_streak_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DailyStreakService', () {
    test('brand new user starts on Day 1 and can claim reward', () async {
      final baseDate = DateTime(2026, 9, 1);
      final status = await DailyStreakService.checkStatus(overrideNow: baseDate);

      expect(status.currentStreak, 1);
      expect(status.isClaimableToday, isTrue);
      expect(status.todayReward.day, 1);
      expect(status.todayReward.coins, 100);
      expect(status.todayReward.diamonds, 0);
    });

    test('claiming today makes reward unclaimable on the same date', () async {
      final baseDate = DateTime(2026, 9, 1);
      final claimed = await DailyStreakService.claimTodayReward(overrideNow: baseDate);

      expect(claimed.day, 1);
      expect(claimed.coins, 100);

      final statusAfter = await DailyStreakService.checkStatus(overrideNow: baseDate);
      expect(statusAfter.currentStreak, 1);
      expect(statusAfter.isClaimableToday, isFalse);
    });

    test('logging in on consecutive day progresses streak to Day 2', () async {
      final day1 = DateTime(2026, 9, 1);
      await DailyStreakService.claimTodayReward(overrideNow: day1);

      final day2 = DateTime(2026, 9, 2);
      final statusDay2 = await DailyStreakService.checkStatus(overrideNow: day2);

      expect(statusDay2.currentStreak, 2);
      expect(statusDay2.isClaimableToday, isTrue);
      expect(statusDay2.todayReward.day, 2);
      expect(statusDay2.todayReward.coins, 200);

      final claimed2 = await DailyStreakService.claimTodayReward(overrideNow: day2);
      expect(claimed2.day, 2);
    });

    test('consecutive progression up to Day 7 grand reward', () async {
      DateTime current = DateTime(2026, 9, 1);
      for (int i = 1; i <= 6; i++) {
        await DailyStreakService.claimTodayReward(overrideNow: current);
        current = current.add(const Duration(days: 1));
      }

      // Day 7
      final statusDay7 = await DailyStreakService.checkStatus(overrideNow: current);
      expect(statusDay7.currentStreak, 7);
      expect(statusDay7.isClaimableToday, isTrue);
      expect(statusDay7.todayReward.coins, 1500);
      expect(statusDay7.todayReward.diamonds, 5);
      expect(statusDay7.todayReward.badge, 'حلبساوي أسطوري');

      await DailyStreakService.claimTodayReward(overrideNow: current);

      // Day 8 (Wrap around to Day 1)
      final day8 = current.add(const Duration(days: 1));
      final statusDay8 = await DailyStreakService.checkStatus(overrideNow: day8);
      expect(statusDay8.currentStreak, 1);
      expect(statusDay8.isClaimableToday, isTrue);
      expect(statusDay8.todayReward.coins, 100);
    });

    test('missing more than 1 day resets streak back to Day 1', () async {
      final day1 = DateTime(2026, 9, 1);
      await DailyStreakService.claimTodayReward(overrideNow: day1);

      // Missed day 2, logging in on day 3
      final day3 = DateTime(2026, 9, 3);
      final statusDay3 = await DailyStreakService.checkStatus(overrideNow: day3);

      expect(statusDay3.currentStreak, 1);
      expect(statusDay3.isClaimableToday, isTrue);
      expect(statusDay3.todayReward.day, 1);
      expect(statusDay3.todayReward.coins, 100);
    });
  });
}
