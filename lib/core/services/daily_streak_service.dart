import 'package:shared_preferences/shared_preferences.dart';

class DailyReward {
  final int day;
  final int coins;
  final int diamonds;
  final String? badge;

  const DailyReward({
    required this.day,
    required this.coins,
    this.diamonds = 0,
    this.badge,
  });
}

class DailyStreakStatus {
  final int currentStreak; // 1 to 7
  final bool isClaimableToday;
  final DailyReward todayReward;
  final List<DailyReward> schedule;

  const DailyStreakStatus({
    required this.currentStreak,
    required this.isClaimableToday,
    required this.todayReward,
    required this.schedule,
  });
}

class DailyStreakService {
  static const String _lastClaimDateKey = 'daily_streak_last_claim_date';
  static const String _currentStreakKey = 'daily_streak_count';

  static const List<DailyReward> schedule = [
    DailyReward(day: 1, coins: 100),
    DailyReward(day: 2, coins: 200),
    DailyReward(day: 3, coins: 300, diamonds: 1),
    DailyReward(day: 4, coins: 400),
    DailyReward(day: 5, coins: 500, diamonds: 2),
    DailyReward(day: 6, coins: 750),
    DailyReward(day: 7, coins: 1500, diamonds: 5, badge: 'حلبساوي أسطوري'),
  ];

  static Future<DailyStreakStatus> checkStatus({DateTime? overrideNow}) async {
    final prefs = await SharedPreferences.getInstance();
    final lastDateStr = prefs.getString(_lastClaimDateKey);
    final savedStreak = prefs.getInt(_currentStreakKey) ?? 0;

    final now = overrideNow ?? DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    if (lastDateStr == null) {
      return DailyStreakStatus(
        currentStreak: 1,
        isClaimableToday: true,
        todayReward: schedule[0],
        schedule: schedule,
      );
    }

    if (lastDateStr == todayStr) {
      final streakDay = (savedStreak - 1) % 7 + 1;
      return DailyStreakStatus(
        currentStreak: streakDay,
        isClaimableToday: false,
        todayReward: schedule[streakDay - 1],
        schedule: schedule,
      );
    }

    final lastDate = DateTime.tryParse(lastDateStr);
    if (lastDate != null) {
      final differenceDays = DateTime(now.year, now.month, now.day)
          .difference(DateTime(lastDate.year, lastDate.month, lastDate.day))
          .inDays;

      if (differenceDays == 1) {
        // Consecutive day
        final nextStreak = (savedStreak % 7) + 1;
        return DailyStreakStatus(
          currentStreak: nextStreak,
          isClaimableToday: true,
          todayReward: schedule[nextStreak - 1],
          schedule: schedule,
        );
      } else {
        // Missed day - reset to day 1
        return DailyStreakStatus(
          currentStreak: 1,
          isClaimableToday: true,
          todayReward: schedule[0],
          schedule: schedule,
        );
      }
    }

    return DailyStreakStatus(
      currentStreak: 1,
      isClaimableToday: true,
      todayReward: schedule[0],
      schedule: schedule,
    );
  }

  static Future<DailyReward> claimTodayReward({DateTime? overrideNow}) async {
    final status = await checkStatus(overrideNow: overrideNow);
    if (!status.isClaimableToday) {
      return status.todayReward;
    }

    final prefs = await SharedPreferences.getInstance();
    final now = overrideNow ?? DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    await prefs.setString(_lastClaimDateKey, todayStr);
    await prefs.setInt(_currentStreakKey, status.currentStreak);

    return status.todayReward;
  }
}
