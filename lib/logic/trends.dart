import 'package:flutter/foundation.dart';

import '../models/daily_summary.dart';
import '../theme/app_theme.dart';
import 'streaks.dart';

enum TrendDirection { up, down, steady, notEnoughData }

/// One metric's recent performance measured against its own longer baseline.
@immutable
class Trend {
  const Trend({
    required this.kind,
    required this.direction,
    required this.recentAverage,
    required this.baselineAverage,
    required this.recentDays,
    required this.baselineDays,
    this.dailyBoostToTurnAround,
  });

  final RingKind kind;
  final TrendDirection direction;
  final double recentAverage;
  final double baselineAverage;
  final int recentDays;
  final int baselineDays;

  /// When trending down: roughly how much more per day, sustained for a week,
  /// would pull the recent average back to the baseline.
  final double? dailyBoostToTurnAround;

  double get delta => recentAverage - baselineAverage;

  bool get isUp => direction == TrendDirection.up;
  bool get isDown => direction == TrendDirection.down;
}

/// Computes trends the way Fitness does: a short recent window judged against
/// a longer one, so a good week actually moves the needle.
class TrendCalculator {
  const TrendCalculator({
    this.recentWindowDays = 30,
    this.baselineWindowDays = 90,
    this.minimumDaysForTrend = 14,
    this.steadyBandPercent = 0.03,
  });

  final int recentWindowDays;
  final int baselineWindowDays;

  /// Below this much logged history the app says "keep logging" instead of
  /// pretending it can read a trend.
  final int minimumDaysForTrend;

  /// Differences inside this band read as flat rather than up or down.
  final double steadyBandPercent;

  List<Trend> computeAll(Map<DateTime, DailySummary> byDay, DateTime today) {
    return [for (final kind in RingKind.values) compute(byDay, today, kind)];
  }

  Trend compute(
    Map<DateTime, DailySummary> byDay,
    DateTime today,
    RingKind kind,
  ) {
    final recent = _average(byDay, today, recentWindowDays, kind);
    final baseline = _average(byDay, today, baselineWindowDays, kind);
    final daysLogged = _daysWithWork(byDay, today, baselineWindowDays);

    if (daysLogged < minimumDaysForTrend) {
      return Trend(
        kind: kind,
        direction: TrendDirection.notEnoughData,
        recentAverage: recent,
        baselineAverage: baseline,
        recentDays: recentWindowDays,
        baselineDays: baselineWindowDays,
      );
    }

    final band = baseline * steadyBandPercent;
    final direction = switch (recent - baseline) {
      final d when d > band => TrendDirection.up,
      final d when d < -band => TrendDirection.down,
      _ => TrendDirection.steady,
    };

    double? boost;
    if (direction == TrendDirection.down) {
      // Spread the 30-day shortfall across the coming week.
      final shortfall = (baseline - recent) * recentWindowDays;
      boost = shortfall / 7;
    }

    return Trend(
      kind: kind,
      direction: direction,
      recentAverage: recent,
      baselineAverage: baseline,
      recentDays: recentWindowDays,
      baselineDays: baselineWindowDays,
      dailyBoostToTurnAround: boost,
    );
  }

  /// Averages across every day in the window, counting untouched days as zero —
  /// days off are part of the trend.
  double _average(
    Map<DateTime, DailySummary> byDay,
    DateTime today,
    int windowDays,
    RingKind kind,
  ) {
    var total = 0.0;
    for (var i = 0; i < windowDays; i++) {
      final day = StreakCalculator.dayKey(today.subtract(Duration(days: i)));
      total += byDay[day]?.valueFor(kind).toDouble() ?? 0.0;
    }
    return total / windowDays;
  }

  int _daysWithWork(Map<DateTime, DailySummary> byDay, DateTime today, int windowDays) {
    var count = 0;
    for (var i = 0; i < windowDays; i++) {
      final day = StreakCalculator.dayKey(today.subtract(Duration(days: i)));
      if (byDay[day]?.hasWork ?? false) count++;
    }
    return count;
  }
}
