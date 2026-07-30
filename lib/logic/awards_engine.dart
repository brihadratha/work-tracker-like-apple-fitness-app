import 'package:flutter/material.dart';

import '../models/award.dart';
import '../models/daily_summary.dart';
import '../models/work_session.dart';
import '../theme/app_theme.dart';
import 'streaks.dart';

/// Every badge the app can hand out, in display order.
class AwardCatalog {
  const AwardCatalog._();

  static const firstBlock = AwardDefinition(
    id: 'first_block',
    title: 'First Block',
    description: 'Log your first block of work.',
    icon: Icons.flag_rounded,
    style: AwardStyle.milestone,
  );

  static const perfectDay = AwardDefinition(
    id: 'perfect_day',
    title: 'Perfect Day',
    description: 'Close your minutes ring in a single day.',
    icon: Icons.brightness_7_rounded,
    style: AwardStyle.perfect,
    repeatable: true,
  );

  static const perfectWeek = AwardDefinition(
    id: 'perfect_week',
    title: 'Perfect Week',
    description: 'Close your minutes ring every day of a calendar week.',
    icon: Icons.calendar_view_week_rounded,
    style: AwardStyle.perfect,
    repeatable: true,
  );

  static const perfectMonth = AwardDefinition(
    id: 'perfect_month',
    title: 'Perfect Month',
    description: 'Close your minutes ring every day of a calendar month.',
    icon: Icons.calendar_month_rounded,
    style: AwardStyle.perfect,
    repeatable: true,
  );

  static const streak7 = AwardDefinition(
    id: 'streak_7',
    title: '7 Day Streak',
    description: 'Seven perfect days back to back.',
    icon: Icons.local_fire_department_rounded,
    style: AwardStyle.milestone,
  );

  static const streak30 = AwardDefinition(
    id: 'streak_30',
    title: '30 Day Streak',
    description: 'A full month of perfect days without a break.',
    icon: Icons.local_fire_department_rounded,
    style: AwardStyle.milestone,
  );

  static const streak100 = AwardDefinition(
    id: 'streak_100',
    title: '100 Day Streak',
    description: 'One hundred perfect days in a row.',
    icon: Icons.whatshot_rounded,
    style: AwardStyle.milestone,
  );

  static const streak365 = AwardDefinition(
    id: 'streak_365',
    title: '365 Day Streak',
    description: 'A perfect year. Every single day.',
    icon: Icons.workspace_premium_rounded,
    style: AwardStyle.milestone,
  );

  static const focus100h = AwardDefinition(
    id: 'focus_100h',
    title: '100 Hours',
    description: 'Log 100 hours of focused work.',
    icon: Icons.timelapse_rounded,
    style: AwardStyle.focus,
  );

  static const focus500h = AwardDefinition(
    id: 'focus_500h',
    title: '500 Hours',
    description: 'Log 500 hours of focused work.',
    icon: Icons.timelapse_rounded,
    style: AwardStyle.focus,
  );

  static const focus1000h = AwardDefinition(
    id: 'focus_1000h',
    title: '1,000 Hours',
    description: 'Log 1,000 hours of focused work.',
    icon: Icons.military_tech_rounded,
    style: AwardStyle.focus,
  );

  static const doubleFocus = AwardDefinition(
    id: 'double_focus',
    title: 'Double Focus',
    description: 'Hit twice your minutes goal in one day.',
    icon: Icons.bolt_rounded,
    style: AwardStyle.focus,
    repeatable: true,
  );

  static const tripleFocus = AwardDefinition(
    id: 'triple_focus',
    title: 'Triple Focus',
    description: 'Hit three times your minutes goal in one day.',
    icon: Icons.rocket_launch_rounded,
    style: AwardStyle.focus,
    repeatable: true,
  );

  static const deepDive = AwardDefinition(
    id: 'deep_dive',
    title: 'Deep Dive',
    description: 'A single unbroken block of two hours.',
    icon: Icons.scuba_diving_rounded,
    style: AwardStyle.sessions,
    repeatable: true,
  );

  static const marathon = AwardDefinition(
    id: 'marathon',
    title: 'Marathon',
    description: 'A single unbroken block of three hours.',
    icon: Icons.timer_rounded,
    style: AwardStyle.sessions,
    repeatable: true,
  );

  static const hundredSessions = AwardDefinition(
    id: 'hundred_sessions',
    title: '100 Deep Blocks',
    description: 'Complete 100 deep work blocks.',
    icon: Icons.stacked_bar_chart_rounded,
    style: AwardStyle.sessions,
  );

  static const earlyBird = AwardDefinition(
    id: 'early_bird',
    title: 'Early Bird',
    description: 'Start a block before 6:00 AM.',
    icon: Icons.wb_twilight_rounded,
    style: AwardStyle.quirk,
    repeatable: true,
  );

  static const nightOwl = AwardDefinition(
    id: 'night_owl',
    title: 'Night Owl',
    description: 'Still working past 11:00 PM.',
    icon: Icons.nightlight_round,
    style: AwardStyle.quirk,
    repeatable: true,
  );

  static const weekendWarrior = AwardDefinition(
    id: 'weekend_warrior',
    title: 'Weekend Warrior',
    description: 'A perfect Saturday and Sunday in the same weekend.',
    icon: Icons.weekend_rounded,
    style: AwardStyle.quirk,
    repeatable: true,
  );

  static const comeback = AwardDefinition(
    id: 'comeback',
    title: 'Comeback',
    description: 'A perfect day after a week or more away.',
    icon: Icons.replay_rounded,
    style: AwardStyle.quirk,
    repeatable: true,
  );

  static const wellRounded = AwardDefinition(
    id: 'well_rounded',
    title: 'Well Rounded',
    description: 'Log every category of work in one day.',
    icon: Icons.donut_small_rounded,
    style: AwardStyle.consistency,
    repeatable: true,
  );

  static const consistencyKing = AwardDefinition(
    id: 'consistency_20',
    title: 'Twenty Closes',
    description: 'Close the Active Hours ring 20 times in one month.',
    icon: Icons.event_available_rounded,
    style: AwardStyle.consistency,
    repeatable: true,
  );

  static const all = <AwardDefinition>[
    perfectDay,
    perfectWeek,
    perfectMonth,
    streak7,
    streak30,
    streak100,
    streak365,
    focus100h,
    focus500h,
    focus1000h,
    doubleFocus,
    tripleFocus,
    deepDive,
    marathon,
    hundredSessions,
    earlyBird,
    nightOwl,
    weekendWarrior,
    comeback,
    wellRounded,
    consistencyKing,
    firstBlock,
  ];
}

/// Recomputes the full award list from history. Nothing about which awards are
/// earned is persisted — it's always derived, so changing a goal re-evaluates
/// everything honestly.
class AwardsEngine {
  const AwardsEngine();

  List<Award> evaluate({
    required Map<DateTime, DailySummary> byDay,
    required List<WorkSession> sessions,
    required DateTime today,
  }) {
    final orderedDays = byDay.keys.toList()..sort();
    final orderedSessions = [...sessions]
      ..sort((a, b) => a.start.compareTo(b.start));

    return <Award>[
      _dayAward(
        AwardCatalog.perfectDay,
        orderedDays,
        byDay,
        (d) => d.isPerfect,
      ),
      _perfectWeekAward(byDay, today),
      _perfectMonthAward(byDay, today),
      ..._streakAwards(byDay, today),
      ..._lifetimeHourAwards(orderedDays, byDay),
      _dayAward(
        AwardCatalog.doubleFocus,
        orderedDays,
        byDay,
        (d) => d.progressFor(RingKind.focus) >= 2,
      ),
      _dayAward(
        AwardCatalog.tripleFocus,
        orderedDays,
        byDay,
        (d) => d.progressFor(RingKind.focus) >= 3,
      ),
      _sessionAward(
        AwardCatalog.deepDive,
        orderedSessions,
        (s) => s.minutes >= 120,
      ),
      _sessionAward(
        AwardCatalog.marathon,
        orderedSessions,
        (s) => s.minutes >= 180,
      ),
      _hundredSessionsAward(orderedDays, byDay),
      _sessionAward(
        AwardCatalog.earlyBird,
        orderedSessions,
        (s) => s.start.hour < 6,
      ),
      _sessionAward(
        AwardCatalog.nightOwl,
        orderedSessions,
        (s) => s.end.hour >= 23 || s.end.day != s.start.day,
      ),
      _weekendWarriorAward(byDay),
      _comebackAward(orderedDays, byDay),
      _dayAward(
        AwardCatalog.wellRounded,
        orderedDays,
        byDay,
        (d) => d.minutesByCategory.length >= WorkCategory.values.length,
      ),
      _monthlyRingCloseAward(byDay),
      _firstBlockAward(orderedSessions),
    ];
  }

  // --- builders ------------------------------------------------------------

  Award _dayAward(
    AwardDefinition def,
    List<DateTime> orderedDays,
    Map<DateTime, DailySummary> byDay,
    bool Function(DailySummary) qualifies,
  ) {
    final hits = orderedDays.where((d) => qualifies(byDay[d]!)).toList();
    return Award(
      definition: def,
      timesEarned: hits.length,
      firstEarnedOn: hits.isEmpty ? null : hits.first,
      lastEarnedOn: hits.isEmpty ? null : hits.last,
      progress: hits.isEmpty ? 0 : 1,
    );
  }

  Award _sessionAward(
    AwardDefinition def,
    List<WorkSession> orderedSessions,
    bool Function(WorkSession) qualifies,
  ) {
    final hits = orderedSessions.where(qualifies).toList();
    return Award(
      definition: def,
      timesEarned: hits.length,
      firstEarnedOn: hits.isEmpty ? null : hits.first.day,
      lastEarnedOn: hits.isEmpty ? null : hits.last.day,
      progress: hits.isEmpty ? 0 : 1,
    );
  }

  /// Awards one badge per calendar week (Mon–Sun) in which every day was
  /// perfect. The current, unfinished week can't qualify yet.
  Award _perfectWeekAward(Map<DateTime, DailySummary> byDay, DateTime today) {
    final normalizedToday = StreakCalculator.dayKey(today);
    final weekStarts = <DateTime>{};
    for (final day in byDay.keys) {
      weekStarts.add(day.subtract(Duration(days: day.weekday - 1)));
    }

    final earned = <DateTime>[];
    for (final start in weekStarts) {
      final end = start.add(const Duration(days: 6));
      if (end.isAfter(normalizedToday)) continue;
      final allPerfect = List.generate(
        7,
        (i) => start.add(Duration(days: i)),
      ).every((d) => byDay[d]?.isPerfect ?? false);
      if (allPerfect) earned.add(end);
    }
    earned.sort();

    return Award(
      definition: AwardCatalog.perfectWeek,
      timesEarned: earned.length,
      firstEarnedOn: earned.isEmpty ? null : earned.first,
      lastEarnedOn: earned.isEmpty ? null : earned.last,
      progress: earned.isEmpty
          ? _currentWeekProgress(byDay, normalizedToday)
          : 1,
      progressLabel: earned.isEmpty
          ? _currentWeekLabel(byDay, normalizedToday)
          : null,
    );
  }

  double _currentWeekProgress(
    Map<DateTime, DailySummary> byDay,
    DateTime today,
  ) {
    final start = today.subtract(Duration(days: today.weekday - 1));
    final elapsed = today.difference(start).inDays + 1;
    final perfect = List.generate(
      elapsed,
      (i) => start.add(Duration(days: i)),
    ).where((d) => byDay[d]?.isPerfect ?? false).length;
    return perfect / 7;
  }

  String _currentWeekLabel(Map<DateTime, DailySummary> byDay, DateTime today) {
    final start = today.subtract(Duration(days: today.weekday - 1));
    final elapsed = today.difference(start).inDays + 1;
    final perfect = List.generate(
      elapsed,
      (i) => start.add(Duration(days: i)),
    ).where((d) => byDay[d]?.isPerfect ?? false).length;
    return '$perfect of 7 days this week';
  }

  /// Every day of a fully elapsed calendar month closed.
  Award _perfectMonthAward(Map<DateTime, DailySummary> byDay, DateTime today) {
    final normalizedToday = StreakCalculator.dayKey(today);
    final months = <DateTime>{
      for (final day in byDay.keys) DateTime(day.year, day.month),
    };

    final earned = <DateTime>[];
    for (final month in months) {
      final lastDay = DateTime(month.year, month.month + 1, 0);
      if (lastDay.isAfter(normalizedToday)) continue;
      final allPerfect = List.generate(
        lastDay.day,
        (i) => DateTime(month.year, month.month, i + 1),
      ).every((d) => byDay[d]?.isPerfect ?? false);
      if (allPerfect) earned.add(lastDay);
    }
    earned.sort();

    return Award(
      definition: AwardCatalog.perfectMonth,
      timesEarned: earned.length,
      firstEarnedOn: earned.isEmpty ? null : earned.first,
      lastEarnedOn: earned.isEmpty ? null : earned.last,
      progress: earned.isEmpty ? 0 : 1,
    );
  }

  List<Award> _streakAwards(Map<DateTime, DailySummary> byDay, DateTime today) {
    final streak = const StreakCalculator().compute(
      byDay,
      today,
      (d) => d.isPerfect,
    );
    final best = streak.longest;

    Award milestone(AwardDefinition def, int target) {
      final earned = best >= target;
      return Award(
        definition: def,
        timesEarned: earned ? 1 : 0,
        progress: (best / target).clamp(0.0, 1.0),
        progressLabel: earned ? null : '$best of $target days',
      );
    }

    return [
      milestone(AwardCatalog.streak7, 7),
      milestone(AwardCatalog.streak30, 30),
      milestone(AwardCatalog.streak100, 100),
      milestone(AwardCatalog.streak365, 365),
    ];
  }

  List<Award> _lifetimeHourAwards(
    List<DateTime> orderedDays,
    Map<DateTime, DailySummary> byDay,
  ) {
    // Walk the history forward so each milestone gets the date it was crossed.
    final crossedOn = <int, DateTime>{};
    const targetsHours = [100, 500, 1000];
    var runningMinutes = 0;
    for (final day in orderedDays) {
      runningMinutes += byDay[day]!.focusMinutes;
      for (final target in targetsHours) {
        if (!crossedOn.containsKey(target) && runningMinutes >= target * 60) {
          crossedOn[target] = day;
        }
      }
    }

    final totalHours = runningMinutes / 60;
    Award hourAward(AwardDefinition def, int target) {
      final earnedOn = crossedOn[target];
      return Award(
        definition: def,
        timesEarned: earnedOn != null ? 1 : 0,
        firstEarnedOn: earnedOn,
        lastEarnedOn: earnedOn,
        progress: (totalHours / target).clamp(0.0, 1.0),
        progressLabel: earnedOn != null
            ? null
            : '${totalHours.floor()} of $target hours',
      );
    }

    return [
      hourAward(AwardCatalog.focus100h, 100),
      hourAward(AwardCatalog.focus500h, 500),
      hourAward(AwardCatalog.focus1000h, 1000),
    ];
  }

  Award _hundredSessionsAward(
    List<DateTime> orderedDays,
    Map<DateTime, DailySummary> byDay,
  ) {
    const target = 100;
    var running = 0;
    DateTime? crossedOn;
    for (final day in orderedDays) {
      running += byDay[day]!.deepSessions;
      if (crossedOn == null && running >= target) crossedOn = day;
    }
    return Award(
      definition: AwardCatalog.hundredSessions,
      timesEarned: crossedOn != null ? 1 : 0,
      firstEarnedOn: crossedOn,
      lastEarnedOn: crossedOn,
      progress: (running / target).clamp(0.0, 1.0),
      progressLabel: crossedOn != null ? null : '$running of $target blocks',
    );
  }

  Award _weekendWarriorAward(Map<DateTime, DailySummary> byDay) {
    final saturdays =
        byDay.keys.where((d) => d.weekday == DateTime.saturday).toList()
          ..sort();
    final earned = <DateTime>[];
    for (final saturday in saturdays) {
      final sunday = saturday.add(const Duration(days: 1));
      final both =
          (byDay[saturday]?.isPerfect ?? false) &&
          (byDay[sunday]?.isPerfect ?? false);
      if (both) earned.add(sunday);
    }
    return Award(
      definition: AwardCatalog.weekendWarrior,
      timesEarned: earned.length,
      firstEarnedOn: earned.isEmpty ? null : earned.first,
      lastEarnedOn: earned.isEmpty ? null : earned.last,
      progress: earned.isEmpty ? 0 : 1,
    );
  }

  /// A perfect day that lands after seven or more consecutive days with nothing
  /// logged — the badge for getting back on the horse.
  Award _comebackAward(
    List<DateTime> orderedDays,
    Map<DateTime, DailySummary> byDay,
  ) {
    final workedDays = orderedDays.where((d) => byDay[d]!.hasWork).toList();
    final earned = <DateTime>[];
    for (var i = 1; i < workedDays.length; i++) {
      final gap = workedDays[i].difference(workedDays[i - 1]).inDays;
      if (gap >= 8 && byDay[workedDays[i]]!.isPerfect) {
        earned.add(workedDays[i]);
      }
    }
    return Award(
      definition: AwardCatalog.comeback,
      timesEarned: earned.length,
      firstEarnedOn: earned.isEmpty ? null : earned.first,
      lastEarnedOn: earned.isEmpty ? null : earned.last,
      progress: earned.isEmpty ? 0 : 1,
    );
  }

  Award _monthlyRingCloseAward(Map<DateTime, DailySummary> byDay) {
    const target = 20;
    final closesByMonth = <DateTime, int>{};
    for (final entry in byDay.entries) {
      if (!entry.value.isClosed(RingKind.consistency)) continue;
      final month = DateTime(entry.key.year, entry.key.month);
      closesByMonth.update(month, (v) => v + 1, ifAbsent: () => 1);
    }

    final earned =
        closesByMonth.entries.where((e) => e.value >= target).toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    final best = closesByMonth.values.fold(0, (a, b) => a > b ? a : b);

    return Award(
      definition: AwardCatalog.consistencyKing,
      timesEarned: earned.length,
      firstEarnedOn: earned.isEmpty ? null : earned.first.key,
      lastEarnedOn: earned.isEmpty ? null : earned.last.key,
      progress: earned.isEmpty ? (best / target).clamp(0.0, 1.0) : 1,
      progressLabel: earned.isEmpty ? '$best of $target days in a month' : null,
    );
  }

  Award _firstBlockAward(List<WorkSession> orderedSessions) {
    final first = orderedSessions.isEmpty ? null : orderedSessions.first;
    return Award(
      definition: AwardCatalog.firstBlock,
      timesEarned: first != null ? 1 : 0,
      firstEarnedOn: first?.day,
      lastEarnedOn: first?.day,
      progress: first != null ? 1 : 0,
    );
  }
}
