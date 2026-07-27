import 'package:flutter/foundation.dart';

import '../models/daily_summary.dart';

/// A run of consecutive qualifying days.
@immutable
class StreakInfo {
  const StreakInfo({
    required this.current,
    required this.longest,
    required this.todayCounts,
  });

  final int current;
  final int longest;

  /// Whether today has already qualified, or the streak is running on
  /// yesterday's credit and today is still open.
  final bool todayCounts;

  static const zero = StreakInfo(current: 0, longest: 0, todayCounts: false);
}

/// Streak maths over a day-keyed history.
class StreakCalculator {
  const StreakCalculator();

  static DateTime dayKey(DateTime date) => DateTime(date.year, date.month, date.day);

  /// Counts consecutive days ending at [today] for which [qualifies] holds.
  ///
  /// Today is still in progress, so a not-yet-qualifying today doesn't break
  /// the streak — the run is measured from yesterday instead. That mirrors how
  /// Fitness keeps a streak alive until the day actually ends.
  StreakInfo compute(
    Map<DateTime, DailySummary> byDay,
    DateTime today,
    bool Function(DailySummary) qualifies,
  ) {
    final normalizedToday = dayKey(today);

    bool qualifiesOn(DateTime day) {
      final summary = byDay[dayKey(day)];
      return summary != null && qualifies(summary);
    }

    final todayCounts = qualifiesOn(normalizedToday);
    var cursor = todayCounts
        ? normalizedToday
        : normalizedToday.subtract(const Duration(days: 1));

    var current = 0;
    while (qualifiesOn(cursor)) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return StreakInfo(
      current: current,
      longest: _longestRun(byDay, qualifies, atLeast: current),
      todayCounts: todayCounts,
    );
  }

  int _longestRun(
    Map<DateTime, DailySummary> byDay,
    bool Function(DailySummary) qualifies, {
    int atLeast = 0,
  }) {
    final days = byDay.entries
        .where((e) => qualifies(e.value))
        .map((e) => e.key)
        .toList()
      ..sort();
    if (days.isEmpty) return atLeast;

    var longest = 1;
    var run = 1;
    for (var i = 1; i < days.length; i++) {
      final gap = days[i].difference(days[i - 1]).inDays;
      run = gap == 1 ? run + 1 : 1;
      if (run > longest) longest = run;
    }
    return longest > atLeast ? longest : atLeast;
  }
}
