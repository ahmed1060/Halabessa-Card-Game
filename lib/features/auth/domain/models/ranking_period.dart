class RankingPeriod {
  static DateTime start(DateTime date) {
    final utc = date.toUtc();
    return DateTime.utc(
      utc.year,
      utc.month,
      utc.day,
    ).subtract(Duration(days: utc.weekday - 1));
  }

  static String key(DateTime date) =>
      start(date).toIso8601String().substring(0, 10);
  static DateTime end(DateTime date) =>
      start(date).add(const Duration(days: 7));
}
