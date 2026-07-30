import 'package:flutter/foundation.dart';

import '../theme/app_theme.dart';
import 'goals.dart';
import 'work_session.dart';

/// One day's worth of ring values, derived from that day's sessions.
@immutable
class DailySummary {
  const DailySummary({
    required this.day,
    required this.focusMinutes,
    required this.deepSessions,
    required this.activeHours,
    required this.goals,
    required this.sessionCount,
    required this.longestSessionMinutes,
    required this.minutesByCategory,
    required this.activeHourSlots,
  });

  final DateTime day;
  final int focusMinutes;
  final int deepSessions;
  final int activeHours;
  final Goals goals;
  final int sessionCount;
  final int longestSessionMinutes;
  final Map<WorkCategory, int> minutesByCategory;

  /// Which hours of the day (0–23) contained work. Drives the hour strip.
  final Set<int> activeHourSlots;

  factory DailySummary.empty(DateTime day, Goals goals) {
    return DailySummary(
      day: DateTime(day.year, day.month, day.day),
      focusMinutes: 0,
      deepSessions: 0,
      activeHours: 0,
      goals: goals,
      sessionCount: 0,
      longestSessionMinutes: 0,
      minutesByCategory: const {},
      activeHourSlots: const {},
    );
  }

  /// Rolls a day's [sessions] up into ring values.
  factory DailySummary.fromSessions(
    DateTime day,
    List<WorkSession> sessions,
    Goals goals,
  ) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    if (sessions.isEmpty) return DailySummary.empty(normalizedDay, goals);

    var focusMinutes = 0;
    var deepSessions = 0;
    var longest = 0;
    final byCategory = <WorkCategory, int>{};
    final hours = <int>{};

    for (final session in sessions) {
      focusMinutes += session.minutes;
      if (session.minutes >= goals.deepSessionMinutes) deepSessions++;
      if (session.minutes > longest) longest = session.minutes;
      byCategory.update(
        session.category,
        (value) => value + session.minutes,
        ifAbsent: () => session.minutes,
      );
      hours.addAll(_hoursTouched(session));
    }

    return DailySummary(
      day: normalizedDay,
      focusMinutes: focusMinutes,
      deepSessions: deepSessions,
      activeHours: hours.length,
      goals: goals,
      sessionCount: sessions.length,
      longestSessionMinutes: longest,
      minutesByCategory: byCategory,
      activeHourSlots: hours,
    );
  }

  /// Every clock hour a session overlaps, clamped to the day it started in so a
  /// late-night session can't award more than 24 hours.
  static Iterable<int> _hoursTouched(WorkSession session) {
    final firstHour = session.start.hour;
    final endExclusive = session.end;
    // A session ending exactly on the hour hasn't entered the next hour.
    final lastMinuteOfWork = endExclusive.subtract(const Duration(minutes: 1));
    final spannedDays = lastMinuteOfWork.difference(session.start).inDays;
    final lastHour =
        spannedDays > 0 || lastMinuteOfWork.day != session.start.day
        ? 23
        : lastMinuteOfWork.hour;
    return [for (var h = firstHour; h <= lastHour; h++) h];
  }

  int valueFor(RingKind kind) => switch (kind) {
    RingKind.focus => focusMinutes,
    RingKind.sessions => deepSessions,
    RingKind.consistency => activeHours,
  };

  int goalFor(RingKind kind) => goals.goalFor(kind);

  /// Uncapped completion, so a 2x day can show as 200%.
  double progressFor(RingKind kind) {
    final goal = goalFor(kind);
    if (goal <= 0) return 0;
    return valueFor(kind) / goal;
  }

  bool isClosed(RingKind kind) =>
      valueFor(kind) >= goalFor(kind) && goalFor(kind) > 0;

  /// The single daily minutes ring is closed.
  bool get isPerfect => isClosed(RingKind.focus);

  int get closedRingCount => isPerfect ? 1 : 0;

  bool get hasWork => focusMinutes > 0;

  /// Capped minutes progress used by compact history views.
  double get overallProgress => progressFor(RingKind.focus).clamp(0.0, 1.0);
}
