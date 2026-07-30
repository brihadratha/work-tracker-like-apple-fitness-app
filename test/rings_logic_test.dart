import 'package:flutter_test/flutter_test.dart';
import 'package:work_rings/data/persistence.dart';
import 'package:work_rings/logic/awards_engine.dart';
import 'package:work_rings/logic/streaks.dart';
import 'package:work_rings/logic/trends.dart';
import 'package:work_rings/models/award.dart';
import 'package:work_rings/models/daily_summary.dart';
import 'package:work_rings/models/goals.dart';
import 'package:work_rings/models/work_session.dart';
import 'package:work_rings/state/app_state.dart';
import 'package:work_rings/theme/app_theme.dart';

/// Fixed "now" so nothing in these tests depends on the wall clock.
final _now = DateTime(2026, 7, 27, 14, 30);
DateTime get _today => DateTime(_now.year, _now.month, _now.day);

WorkSession _session({
  required DateTime start,
  required int minutes,
  WorkCategory category = WorkCategory.deepWork,
  String? id,
}) {
  return WorkSession(
    id: id ?? '${start.microsecondsSinceEpoch}-$minutes',
    start: start,
    minutes: minutes,
    category: category,
  );
}

void main() {
  group('DailySummary', () {
    const goals = Goals();

    test('sums focus minutes and counts only long enough blocks as deep', () {
      final day = DateTime(2026, 7, 20);
      final summary = DailySummary.fromSessions(day, [
        _session(start: day.add(const Duration(hours: 9)), minutes: 50),
        _session(start: day.add(const Duration(hours: 11)), minutes: 25),
        _session(start: day.add(const Duration(hours: 13)), minutes: 10),
      ], goals);

      expect(summary.focusMinutes, 85);
      // 50 and 25 clear the 25-minute bar; the 10-minute block doesn't.
      expect(summary.deepSessions, 2);
      expect(summary.sessionCount, 3);
      expect(summary.longestSessionMinutes, 50);
    });

    test('counts every clock hour a block touches', () {
      final day = DateTime(2026, 7, 20);
      final summary = DailySummary.fromSessions(day, [
        _session(
          start: day.add(const Duration(hours: 9, minutes: 50)),
          minutes: 40,
        ),
      ], goals);

      // 09:50 → 10:30 spans the 9 o'clock and 10 o'clock hours.
      expect(summary.activeHourSlots, {9, 10});
      expect(summary.activeHours, 2);
    });

    test('a block ending exactly on the hour does not claim the next hour', () {
      final day = DateTime(2026, 7, 20);
      final summary = DailySummary.fromSessions(day, [
        _session(start: day.add(const Duration(hours: 9)), minutes: 60),
      ], goals);

      expect(summary.activeHourSlots, {9});
    });

    test('a block running past midnight is capped at its starting day', () {
      final day = DateTime(2026, 7, 20);
      final summary = DailySummary.fromSessions(day, [
        _session(start: day.add(const Duration(hours: 23)), minutes: 180),
      ], goals);

      expect(summary.activeHourSlots, {23});
      expect(summary.activeHours, 1);
    });

    test('progress is uncapped so a double day reads as 200%', () {
      final day = DateTime(2026, 7, 20);
      final summary = DailySummary.fromSessions(day, [
        _session(start: day.add(const Duration(hours: 8)), minutes: 480),
      ], goals);

      expect(summary.progressFor(RingKind.focus), 2.0);
      expect(summary.isClosed(RingKind.focus), isTrue);
    });

    test('closing the minutes ring makes a complete day', () {
      final day = DateTime(2026, 7, 20);
      // 8 blocks of 30 min, one per hour: 240 focus, 8 deep, 8 active hours.
      final sessions = [
        for (var hour = 9; hour < 17; hour++)
          _session(start: day.add(Duration(hours: hour)), minutes: 30),
      ];

      final summary = DailySummary.fromSessions(day, sessions, goals);
      expect(summary.focusMinutes, 240);
      expect(summary.deepSessions, 8);
      expect(summary.activeHours, 8);
      expect(summary.isPerfect, isTrue);
      expect(summary.closedRingCount, 1);
    });
  });

  group('StreakCalculator', () {
    const calculator = StreakCalculator();
    const goals = Goals();

    Map<DateTime, DailySummary> historyOfPerfectDays(List<int> daysAgo) {
      final byDay = <DateTime, DailySummary>{};
      for (final offset in daysAgo) {
        final day = _today.subtract(Duration(days: offset));
        final sessions = [
          for (var hour = 9; hour < 17; hour++)
            _session(start: day.add(Duration(hours: hour)), minutes: 30),
        ];
        byDay[day] = DailySummary.fromSessions(day, sessions, goals);
      }
      return byDay;
    }

    test('counts consecutive perfect days ending today', () {
      final byDay = historyOfPerfectDays([0, 1, 2, 3]);
      final streak = calculator.compute(byDay, _now, (d) => d.isPerfect);

      expect(streak.current, 4);
      expect(streak.todayCounts, isTrue);
    });

    test('an unfinished today does not break yesterday\'s streak', () {
      final byDay = historyOfPerfectDays([1, 2, 3]);
      final streak = calculator.compute(byDay, _now, (d) => d.isPerfect);

      expect(streak.current, 3);
      expect(streak.todayCounts, isFalse);
    });

    test('a gap ends the streak but the record survives', () {
      // A 5-day run that ended a week ago, plus a single perfect day today.
      final byDay = historyOfPerfectDays([0, 7, 8, 9, 10, 11]);
      final streak = calculator.compute(byDay, _now, (d) => d.isPerfect);

      expect(streak.current, 1);
      expect(streak.longest, 5);
    });

    test('no history means no streak', () {
      final streak = calculator.compute({}, _now, (d) => d.isPerfect);
      expect(streak.current, 0);
      expect(streak.longest, 0);
    });
  });

  group('TrendCalculator', () {
    const calculator = TrendCalculator();
    const goals = Goals();

    Map<DateTime, DailySummary> history(int Function(int daysAgo) minutesFor) {
      final byDay = <DateTime, DailySummary>{};
      for (var offset = 0; offset < 90; offset++) {
        final day = _today.subtract(Duration(days: offset));
        final minutes = minutesFor(offset);
        if (minutes <= 0) continue;
        byDay[day] = DailySummary.fromSessions(day, [
          _session(start: day.add(const Duration(hours: 9)), minutes: minutes),
        ], goals);
      }
      return byDay;
    }

    test('stays quiet until there is enough history to read', () {
      final byDay = history((offset) => offset < 5 ? 120 : 0);
      final trend = calculator.compute(byDay, _now, RingKind.focus);

      expect(trend.direction, TrendDirection.notEnoughData);
    });

    test('a stronger recent month trends up', () {
      // Last 30 days at 200 min; the 60 before that at 60 min.
      final byDay = history((offset) => offset < 30 ? 200 : 60);
      final trend = calculator.compute(byDay, _now, RingKind.focus);

      expect(trend.direction, TrendDirection.up);
      expect(trend.recentAverage, greaterThan(trend.baselineAverage));
    });

    test('a weaker recent month trends down and suggests a way back', () {
      final byDay = history((offset) => offset < 30 ? 40 : 200);
      final trend = calculator.compute(byDay, _now, RingKind.focus);

      expect(trend.direction, TrendDirection.down);
      expect(trend.dailyBoostToTurnAround, isNotNull);
      expect(trend.dailyBoostToTurnAround, greaterThan(0));
    });

    test('a flat history reads as steady, not noise', () {
      final byDay = history((_) => 120);
      final trend = calculator.compute(byDay, _now, RingKind.focus);

      expect(trend.direction, TrendDirection.steady);
    });
  });

  group('AwardsEngine', () {
    const engine = AwardsEngine();
    const goals = Goals();

    List<WorkSession> perfectDaySessions(DateTime day) => [
      for (var hour = 9; hour < 17; hour++)
        _session(start: day.add(Duration(hours: hour)), minutes: 30),
    ];

    ({Map<DateTime, DailySummary> byDay, List<WorkSession> sessions}) build(
      List<DateTime> perfectDays, {
      List<WorkSession> extra = const [],
    }) {
      final sessions = <WorkSession>[
        for (final day in perfectDays) ...perfectDaySessions(day),
        ...extra,
      ];
      final grouped = <DateTime, List<WorkSession>>{};
      for (final session in sessions) {
        grouped.putIfAbsent(session.day, () => []).add(session);
      }
      return (
        byDay: {
          for (final entry in grouped.entries)
            entry.key: DailySummary.fromSessions(entry.key, entry.value, goals),
        },
        sessions: sessions,
      );
    }

    Award find(List<Award> awards, String id) =>
        awards.firstWhere((a) => a.id == id);

    test('nothing is earned on an empty history', () {
      final awards = engine.evaluate(byDay: {}, sessions: [], today: _today);

      expect(awards.every((a) => !a.isEarned), isTrue);
      expect(find(awards, 'first_block').isEarned, isFalse);
    });

    test('the first block unlocks its badge', () {
      final data = build(
        [],
        extra: [
          _session(start: _today.add(const Duration(hours: 9)), minutes: 30),
        ],
      );
      final awards = engine.evaluate(
        byDay: data.byDay,
        sessions: data.sessions,
        today: _today,
      );

      expect(find(awards, 'first_block').isEarned, isTrue);
    });

    test('perfect days accumulate as a repeatable count', () {
      final days = [
        _today,
        _today.subtract(const Duration(days: 1)),
        _today.subtract(const Duration(days: 3)),
      ];
      final data = build(days);
      final awards = engine.evaluate(
        byDay: data.byDay,
        sessions: data.sessions,
        today: _today,
      );

      final perfectDay = find(awards, 'perfect_day');
      expect(perfectDay.timesEarned, 3);
      expect(perfectDay.firstEarnedOn, days.last);
    });

    test('a full elapsed calendar week earns Perfect Week', () {
      // Mon 2026-07-13 through Sun 2026-07-19, entirely in the past.
      final monday = DateTime(2026, 7, 13);
      final week = [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];
      final data = build(week);
      final awards = engine.evaluate(
        byDay: data.byDay,
        sessions: data.sessions,
        today: _today,
      );

      final perfectWeek = find(awards, 'perfect_week');
      expect(perfectWeek.timesEarned, 1);
      expect(perfectWeek.lastEarnedOn, DateTime(2026, 7, 19));
    });

    test('the current unfinished week cannot earn Perfect Week yet', () {
      // Mon 2026-07-27 is today; the week runs to Sunday the 2nd.
      final data = build([_today]);
      final awards = engine.evaluate(
        byDay: data.byDay,
        sessions: data.sessions,
        today: _today,
      );

      expect(find(awards, 'perfect_week').isEarned, isFalse);
    });

    test('streak milestones track the longest run', () {
      final days = [
        for (var i = 0; i < 8; i++) _today.subtract(Duration(days: i)),
      ];
      final data = build(days);
      final awards = engine.evaluate(
        byDay: data.byDay,
        sessions: data.sessions,
        today: _today,
      );

      expect(find(awards, 'streak_7').isEarned, isTrue);
      final thirty = find(awards, 'streak_30');
      expect(thirty.isEarned, isFalse);
      expect(thirty.progressLabel, '8 of 30 days');
    });

    test('long single blocks earn Deep Dive and Marathon', () {
      final data = build(
        [],
        extra: [
          _session(start: _today.add(const Duration(hours: 9)), minutes: 190),
        ],
      );
      final awards = engine.evaluate(
        byDay: data.byDay,
        sessions: data.sessions,
        today: _today,
      );

      expect(find(awards, 'deep_dive').isEarned, isTrue);
      expect(find(awards, 'marathon').isEarned, isTrue);
    });

    test('odd-hours badges pick up early and late blocks', () {
      final data = build(
        [],
        extra: [
          _session(start: _today.add(const Duration(hours: 5)), minutes: 45),
          _session(
            start: _today.add(const Duration(hours: 23, minutes: 10)),
            minutes: 40,
          ),
        ],
      );
      final awards = engine.evaluate(
        byDay: data.byDay,
        sessions: data.sessions,
        today: _today,
      );

      expect(find(awards, 'early_bird').isEarned, isTrue);
      expect(find(awards, 'night_owl').isEarned, isTrue);
    });

    test('locked hour milestones report how far along they are', () {
      final data = build(
        [],
        extra: [
          _session(
            start: _today.add(const Duration(hours: 9)),
            minutes: 60 * 40,
          ),
        ],
      );
      final awards = engine.evaluate(
        byDay: data.byDay,
        sessions: data.sessions,
        today: _today,
      );

      final hundred = find(awards, 'focus_100h');
      expect(hundred.isEarned, isFalse);
      expect(hundred.progressLabel, '40 of 100 hours');
      expect(hundred.progress, closeTo(0.4, 0.001));
    });
  });

  group('AppState', () {
    late AppState state;

    setUp(() async {
      state = AppState(persistence: InMemoryPersistence(), clock: () => _now);
      await state.load();
    });

    tearDown(() => state.dispose());

    test('logging a block moves today\'s rings', () async {
      await state.addSession(
        start: _now,
        minutes: 45,
        category: WorkCategory.deepWork,
      );

      expect(state.todaySummary.focusMinutes, 45);
      expect(state.todaySummary.deepSessions, 1);
      expect(state.lifetimeMinutes, 45);
    });

    test('a zero-length block is ignored', () async {
      await state.addSession(
        start: _now,
        minutes: 0,
        category: WorkCategory.admin,
      );
      expect(state.sessions, isEmpty);
    });

    test('deleting a block rolls the rings back', () async {
      await state.addSession(
        start: _now,
        minutes: 45,
        category: WorkCategory.admin,
      );
      final id = state.sessions.single.id;

      await state.deleteSession(id);

      expect(state.sessions, isEmpty);
      expect(state.todaySummary.focusMinutes, 0);
    });

    test('the timer logs elapsed time when stopped', () async {
      var clock = _now;
      final timed = AppState(
        persistence: InMemoryPersistence(),
        clock: () => clock,
      );
      await timed.load();

      await timed.startTimer(WorkCategory.deepWork);
      expect(timed.isTimerRunning, isTrue);

      clock = _now.add(const Duration(minutes: 42));
      final session = await timed.stopTimer();

      expect(session, isNotNull);
      expect(session!.minutes, 42);
      expect(timed.isTimerRunning, isFalse);
      expect(timed.todaySummary.focusMinutes, 42);
      timed.dispose();
    });

    test('pause excludes break time and survives a reload', () async {
      final store = InMemoryPersistence();
      var clock = _now;
      final first = AppState(persistence: store, clock: () => clock);
      await first.load();

      await first.startTimer(WorkCategory.deepWork);
      clock = _now.add(const Duration(minutes: 20));
      await first.pauseTimer();
      expect(first.isTimerPaused, isTrue);
      expect(first.timerElapsed, const Duration(minutes: 20));

      clock = _now.add(const Duration(hours: 1));
      first.dispose();
      final second = AppState(persistence: store, clock: () => clock);
      await second.load();
      expect(second.isTimerPaused, isTrue);
      expect(second.timerElapsed, const Duration(minutes: 20));

      await second.resumeTimer();
      clock = _now.add(const Duration(hours: 1, minutes: 15));
      final session = await second.stopTimer();
      expect(session!.minutes, 35);
      second.dispose();
    });

    test('a sub-minute timer is discarded rather than logged', () async {
      await state.startTimer(WorkCategory.deepWork);
      final session = await state.stopTimer();

      expect(session, isNull);
      expect(state.sessions, isEmpty);
    });

    test('cancelling the timer logs nothing', () async {
      var clock = _now;
      final timed = AppState(
        persistence: InMemoryPersistence(),
        clock: () => clock,
      );
      await timed.load();

      await timed.startTimer(WorkCategory.deepWork);
      clock = _now.add(const Duration(minutes: 30));
      await timed.cancelTimer();

      expect(timed.sessions, isEmpty);
      expect(timed.isTimerRunning, isFalse);
      timed.dispose();
    });

    test('sessions and goals survive a reload', () async {
      final store = InMemoryPersistence();
      final first = AppState(persistence: store, clock: () => _now);
      await first.load();
      await first.addSession(
        start: _now,
        minutes: 90,
        category: WorkCategory.learning,
      );
      await first.setGoals(const Goals(focusMinutes: 300));
      first.dispose();

      final second = AppState(persistence: store, clock: () => _now);
      await second.load();

      expect(second.sessions.single.minutes, 90);
      expect(second.sessions.single.category, WorkCategory.learning);
      expect(second.goals.focusMinutes, 300);
      second.dispose();
    });

    test('a running timer survives a reload', () async {
      final store = InMemoryPersistence();
      final first = AppState(persistence: store, clock: () => _now);
      await first.load();
      await first.startTimer(WorkCategory.creative);
      first.dispose();

      final second = AppState(persistence: store, clock: () => _now);
      await second.load();

      expect(second.isTimerRunning, isTrue);
      expect(second.timer!.category, WorkCategory.creative);
      second.dispose();
    });

    test('a corrupt store opens empty instead of throwing', () async {
      final store = InMemoryPersistence({
        'version': 1,
        'sessions': [
          {'id': 'ok', 'start': _now.toIso8601String(), 'minutes': 30},
          {'nonsense': true},
        ],
      });
      final recovered = AppState(persistence: store, clock: () => _now);
      await recovered.load();

      expect(recovered.sessions.length, 1);
      recovered.dispose();
    });

    test('crossing an award threshold queues a celebration', () async {
      await state.addSession(
        start: _now,
        minutes: 200,
        category: WorkCategory.admin,
      );

      final celebrations = state.takeCelebrations();
      expect(celebrations.map((a) => a.id), contains('deep_dive'));
      // The queue empties once taken, so it can't fire twice.
      expect(state.takeCelebrations(), isEmpty);
    });

    test('a new goal applies to today', () async {
      await state.addSession(
        start: _now,
        minutes: 240,
        category: WorkCategory.admin,
      );
      expect(state.todaySummary.isClosed(RingKind.focus), isTrue);

      await state.setGoals(const Goals(focusMinutes: 480));

      expect(state.todaySummary.isClosed(RingKind.focus), isFalse);
      expect(state.goals.focusMinutes, 480);
    });

    test('a new goal leaves past days scored as they were', () async {
      final yesterday = _today.subtract(const Duration(days: 1));
      await state.addSession(
        start: yesterday.add(const Duration(hours: 9)),
        minutes: 240,
        category: WorkCategory.admin,
      );
      expect(state.summaryFor(yesterday).isClosed(RingKind.focus), isTrue);

      await state.setGoals(const Goals(focusMinutes: 480));

      // Yesterday was worked under the 240 goal and stays closed.
      expect(state.goalsOn(yesterday).focusMinutes, 240);
      expect(state.summaryFor(yesterday).isClosed(RingKind.focus), isTrue);
    });

    test('raising a goal does not break a streak already earned', () async {
      // Ten perfect days ending yesterday, under the default goals.
      for (var offset = 1; offset <= 10; offset++) {
        final day = _today.subtract(Duration(days: offset));
        for (var hour = 9; hour < 17; hour++) {
          await state.addSession(
            start: day.add(Duration(hours: hour)),
            minutes: 30,
            category: WorkCategory.deepWork,
          );
        }
      }
      expect(state.perfectDayStreak.current, 10);

      await state.setGoals(const Goals(focusMinutes: 600, deepSessions: 10));

      expect(state.perfectDayStreak.current, 10);
      expect(state.totalPerfectDays, 10);
    });

    test(
      'lowering a goal does not hand out past days you did not earn',
      () async {
        final yesterday = _today.subtract(const Duration(days: 1));
        await state.addSession(
          start: yesterday.add(const Duration(hours: 9)),
          minutes: 60,
          category: WorkCategory.admin,
        );
        expect(state.summaryFor(yesterday).isClosed(RingKind.focus), isFalse);

        await state.setGoals(const Goals(focusMinutes: 30));

        expect(state.summaryFor(yesterday).isClosed(RingKind.focus), isFalse);
      },
    );

    test('each goal change applies from the day it was made', () async {
      var clock = _now.subtract(const Duration(days: 5));
      final dated = AppState(
        persistence: InMemoryPersistence(),
        clock: () => clock,
      );
      await dated.load();

      await dated.setGoals(const Goals(focusMinutes: 120));
      clock = _now;
      await dated.setGoals(const Goals(focusMinutes: 360));

      expect(dated.goalsOn(_today).focusMinutes, 360);
      expect(
        dated.goalsOn(_today.subtract(const Duration(days: 2))).focusMinutes,
        120,
      );
      // Before any change of his own, the default still stands.
      expect(
        dated.goalsOn(_today.subtract(const Duration(days: 30))).focusMinutes,
        240,
      );
      dated.dispose();
    });

    test('goal history survives a reload', () async {
      final store = InMemoryPersistence();
      var clock = _now.subtract(const Duration(days: 3));
      final first = AppState(persistence: store, clock: () => clock);
      await first.load();
      await first.setGoals(const Goals(focusMinutes: 120));
      clock = _now;
      await first.setGoals(const Goals(focusMinutes: 300));
      first.dispose();

      final second = AppState(persistence: store, clock: () => _now);
      await second.load();

      expect(second.goals.focusMinutes, 300);
      expect(
        second.goalsOn(_today.subtract(const Duration(days: 2))).focusMinutes,
        120,
      );
      second.dispose();
    });

    test(
      'a store written before goals were dated keeps its history intact',
      () async {
        final yesterday = _today.subtract(const Duration(days: 1));
        final store = InMemoryPersistence({
          'version': 1,
          'goals': const Goals(focusMinutes: 120).toJson(),
          'sessions': [
            {
              'id': 'legacy',
              'start': yesterday
                  .add(const Duration(hours: 9))
                  .toIso8601String(),
              'minutes': 120,
              'category': 'admin',
            },
          ],
        });
        final migrated = AppState(persistence: store, clock: () => _now);
        await migrated.load();

        // The old single goal applied to every day, so yesterday stays closed.
        expect(migrated.goals.focusMinutes, 120);
        expect(migrated.summaryFor(yesterday).isClosed(RingKind.focus), isTrue);
        migrated.dispose();
      },
    );

    test('reset clears everything', () async {
      await state.addSession(
        start: _now,
        minutes: 60,
        category: WorkCategory.admin,
      );
      await state.clearAll();

      expect(state.sessions, isEmpty);
      expect(state.todaySummary.hasWork, isFalse);
    });
  });
}
