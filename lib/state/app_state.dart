import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/persistence.dart';
import '../logic/awards_engine.dart';
import '../logic/streaks.dart';
import '../logic/trends.dart';
import '../models/award.dart';
import '../models/daily_summary.dart';
import '../models/goals.dart';
import '../models/work_session.dart';
import '../services/live_activity_service.dart';
import '../theme/app_theme.dart';

/// A timer the user has started but not yet logged.
@immutable
class RunningTimer {
  const RunningTimer({
    required this.startedAt,
    required this.category,
    required this.accumulated,
    required this.resumedAt,
  });

  final DateTime startedAt;
  final WorkCategory category;
  final Duration accumulated;
  final DateTime? resumedAt;

  bool get isPaused => resumedAt == null;
  String get sessionId => startedAt.millisecondsSinceEpoch.toString();

  Duration elapsedAt(DateTime now) {
    final activeSinceResume = resumedAt == null
        ? Duration.zero
        : now.difference(resumedAt!);
    final elapsed = accumulated + activeSinceResume;
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  Map<String, dynamic> toJson() => {
    'startedAt': startedAt.toIso8601String(),
    'category': category.name,
    'accumulatedSeconds': accumulated.inSeconds,
    if (resumedAt != null) 'resumedAt': resumedAt!.toIso8601String(),
    'isPaused': isPaused,
  };

  factory RunningTimer.fromJson(Map<String, dynamic> json) {
    final startedAt = DateTime.parse(json['startedAt'] as String);
    final hasPauseState =
        json.containsKey('accumulatedSeconds') || json.containsKey('isPaused');
    return RunningTimer(
      startedAt: startedAt,
      category: WorkCategoryInfo.fromName(json['category'] as String?),
      accumulated: Duration(
        seconds: (json['accumulatedSeconds'] as num?)?.round() ?? 0,
      ),
      resumedAt: hasPauseState && json['isPaused'] == true
          ? null
          : DateTime.tryParse(json['resumedAt'] as String? ?? '') ?? startedAt,
    );
  }
}

/// Single source of truth for the app. Owns sessions, goals and the live
/// timer, and derives every summary, streak, trend and award from them.
class AppState extends ChangeNotifier {
  AppState({
    Persistence? persistence,
    DateTime Function()? clock,
    LiveActivityService? liveActivity,
  }) : _persistence =
           persistence ??
           MirroredPersistence(
             local: FilePersistence(),
             cloud: ICloudPersistence(),
           ),
       _clock = clock ?? DateTime.now,
       _liveActivity = liveActivity ?? const LiveActivityService();

  final Persistence _persistence;
  final DateTime Function() _clock;
  final LiveActivityService _liveActivity;

  static const _storeVersion = 2;
  static const _awardsEngine = AwardsEngine();
  static const _streaks = StreakCalculator();
  static const _trends = TrendCalculator();

  final _random = Random();

  List<WorkSession> _sessions = [];
  GoalHistory _goalHistory = GoalHistory.fromStart(const Goals());
  RunningTimer? _timer;
  Timer? _ticker;
  Timer? _liveActivityPoller;
  bool _loaded = false;
  Future<void>? _reconciliation;

  /// Derived caches, rebuilt whenever sessions or goals change.
  Map<DateTime, DailySummary> _byDay = {};
  List<Award> _awards = [];
  Map<String, int> _awardCounts = {};

  /// Awards that crossed a threshold since the last user action, waiting to be
  /// celebrated by the UI.
  final List<Award> _pendingCelebrations = [];

  // --- accessors -----------------------------------------------------------

  bool get isLoaded => _loaded;

  /// The goals in force right now. Past days are scored against whatever was
  /// in force on the day itself — see [goalsOn].
  Goals get goals => goalsOn(today);

  /// The goal that was in force on [day].
  Goals goalsOn(DateTime day) => _goalHistory.goalsOn(day);
  RunningTimer? get timer => _timer;
  bool get isTimerRunning => _timer != null;
  bool get isTimerPaused => _timer?.isPaused ?? false;
  List<WorkSession> get sessions => List.unmodifiable(_sessions);
  List<Award> get awards => List.unmodifiable(_awards);
  Map<DateTime, DailySummary> get summariesByDay => Map.unmodifiable(_byDay);

  DateTime get now => _clock();
  DateTime get today => StreakCalculator.dayKey(now);

  Duration get timerElapsed => _timer?.elapsedAt(now) ?? Duration.zero;

  DailySummary get todaySummary => summaryFor(today);

  DailySummary summaryFor(DateTime day) {
    final key = StreakCalculator.dayKey(day);
    return _byDay[key] ?? DailySummary.empty(key, goalsOn(key));
  }

  List<WorkSession> sessionsOn(DateTime day) {
    final key = StreakCalculator.dayKey(day);
    return _sessions.where((s) => s.day == key).toList()
      ..sort((a, b) => b.start.compareTo(a.start));
  }

  StreakInfo get perfectDayStreak =>
      _streaks.compute(_byDay, today, (d) => d.isPerfect);

  StreakInfo streakFor(RingKind kind) =>
      _streaks.compute(_byDay, today, (d) => d.isClosed(kind));

  /// Consecutive days with any work at all — the "showed up" streak.
  StreakInfo get loggingStreak =>
      _streaks.compute(_byDay, today, (d) => d.hasWork);

  List<Trend> get trends => _trends.computeAll(_byDay, today);

  Trend trendFor(RingKind kind) => _trends.compute(_byDay, today, kind);

  List<Award> get earnedAwards => _awards.where((a) => a.isEarned).toList();

  List<Award> get lockedAwards => _awards.where((a) => !a.isEarned).toList();

  int get lifetimeMinutes =>
      _sessions.fold(0, (total, session) => total + session.minutes);

  int get totalPerfectDays => _byDay.values.where((d) => d.isPerfect).length;

  bool get hasPendingCelebrations => _pendingCelebrations.isNotEmpty;

  List<Award> takeCelebrations() {
    final pending = List<Award>.from(_pendingCelebrations);
    _pendingCelebrations.clear();
    return pending;
  }

  /// The last [days] days ending today, oldest first.
  List<DailySummary> recentDays(int days) {
    return [
      for (var i = days - 1; i >= 0; i--)
        summaryFor(today.subtract(Duration(days: i))),
    ];
  }

  // --- lifecycle -----------------------------------------------------------

  Future<void> load() async {
    final data = await _persistence.read();
    if (data != null) {
      final rawSessions = (data['sessions'] as List?) ?? const [];
      _sessions = [
        for (final raw in rawSessions)
          if (raw is Map<String, dynamic>) _tryParseSession(raw),
      ].whereType<WorkSession>().toList();

      final rawHistory = data['goalHistory'];
      final rawGoals = data['goals'];
      if (rawHistory is List) {
        _goalHistory = GoalHistory.fromJson(rawHistory);
      } else if (rawGoals is Map<String, dynamic>) {
        // Stores written before goals were dated: that one goal really was
        // in force for every day recorded, so backdate it to the beginning and
        // no past day changes score.
        _goalHistory = GoalHistory.fromStart(Goals.fromJson(rawGoals));
      }

      final rawTimer = data['timer'];
      if (rawTimer is Map<String, dynamic>) {
        try {
          _timer = RunningTimer.fromJson(rawTimer);
        } catch (_) {
          _timer = null;
        }
      }
    }

    _recompute(collectCelebrations: false);
    if (_timer != null && !_timer!.isPaused) _startTicker();
    if (_timer != null) _startLiveActivityPoller();
    _loaded = true;
    await reconcileLiveActivityActions();
    notifyListeners();
  }

  WorkSession? _tryParseSession(Map<String, dynamic> raw) {
    try {
      return WorkSession.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _liveActivityPoller?.cancel();
    super.dispose();
  }

  // --- mutations -----------------------------------------------------------

  Future<void> addSession({
    required DateTime start,
    required int minutes,
    required WorkCategory category,
    String? note,
  }) async {
    if (minutes <= 0) return;
    _sessions.add(
      WorkSession(
        id: _newId(),
        start: start,
        minutes: minutes,
        category: category,
        note: note,
      ),
    );
    await _commit();
  }

  Future<void> updateSession(WorkSession session) async {
    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index == -1) return;
    _sessions[index] = session;
    await _commit();
  }

  Future<void> deleteSession(String id) async {
    _sessions.removeWhere((s) => s.id == id);
    await _commit();
  }

  /// Applies [goals] from today forward. Days already behind you keep the goal
  /// they were worked under, so a tougher target can't retroactively break a
  /// streak you earned.
  Future<void> setGoals(Goals goals) async {
    _goalHistory = _goalHistory.withChange(today, goals);
    await _commit();
  }

  Future<void> startTimer(WorkCategory category) async {
    await reconcileLiveActivityActions();
    if (_timer != null) return;
    final startedAt = now;
    _timer = RunningTimer(
      startedAt: startedAt,
      category: category,
      accumulated: Duration.zero,
      resumedAt: startedAt,
    );
    _startTicker();
    _startLiveActivityPoller();
    await _save();
    await _liveActivity.start(
      sessionId: _timer!.sessionId,
      startedAt: startedAt,
      elapsed: Duration.zero,
      category: category.label,
      goalMinutes: goals.focusMinutes,
    );
    notifyListeners();
  }

  Future<void> pauseTimer() async {
    await reconcileLiveActivityActions(synchronize: false);
    final running = _timer;
    if (running == null || running.isPaused) return;
    final elapsed = running.elapsedAt(now);
    _timer = RunningTimer(
      startedAt: running.startedAt,
      category: running.category,
      accumulated: elapsed,
      resumedAt: null,
    );
    _ticker?.cancel();
    _ticker = null;
    await _save();
    await _syncLiveActivity();
    notifyListeners();
  }

  Future<void> resumeTimer() async {
    await reconcileLiveActivityActions(synchronize: false);
    final running = _timer;
    if (running == null || !running.isPaused) return;
    _timer = RunningTimer(
      startedAt: running.startedAt,
      category: running.category,
      accumulated: running.accumulated,
      resumedAt: now,
    );
    _startTicker();
    await _save();
    await _syncLiveActivity();
    notifyListeners();
  }

  /// Stops the timer and logs it, unless it ran for less than a minute.
  Future<WorkSession?> stopTimer({String? note}) async {
    await reconcileLiveActivityActions(synchronize: false);
    final running = _timer;
    if (running == null) return null;

    // Freeze Flutter polling while native resolves any intent that landed at
    // the same boundary. ActivityKit returns the authoritative elapsed value.
    _ticker?.cancel();
    _ticker = null;
    _liveActivityPoller?.cancel();
    _liveActivityPoller = null;
    final fallbackElapsed = running.elapsedAt(now);
    final nativeElapsed = await _liveActivity.end(
      elapsed: fallbackElapsed,
      sessionId: running.sessionId,
    );
    final elapsed = nativeElapsed ?? fallbackElapsed;
    final minutes = elapsed.inMinutes;
    _timer = null;

    if (minutes <= 0) {
      await _save();
      notifyListeners();
      return null;
    }

    final session = WorkSession(
      id: _newId(),
      start: running.startedAt,
      minutes: minutes,
      category: running.category,
      note: note,
    );
    _sessions.add(session);
    await _commit();
    return session;
  }

  /// Reconciles a pause, resume, or stop performed from the Lock Screen or
  /// Dynamic Island, then makes ActivityKit mirror the resulting app state.
  /// Concurrent lifecycle and button-triggered reconciliations share one pass
  /// so a fast app-side Stop cannot race a Lock Screen pause.
  Future<void> reconcileLiveActivityActions({bool synchronize = true}) async {
    final pending = _reconciliation;
    if (pending != null) {
      await pending;
      if (synchronize) await _synchronizeLiveActivityState();
      return;
    }

    final completer = Completer<void>();
    _reconciliation = completer.future;
    try {
      await _applyPendingLiveActivityAction();
      if (synchronize) await _synchronizeLiveActivityState();
    } finally {
      _reconciliation = null;
      completer.complete();
    }
  }

  Future<void> _applyPendingLiveActivityAction() async {
    final action = await _liveActivity.takePendingAction();
    final running = _timer;
    if (action == null || running == null) return;

    // An intent from an activity belonging to an older session must never
    // pause, resume, or stop the current timer.
    if (action.sessionId != running.sessionId) return;

    switch (action.type) {
      case LiveActivityActionType.pause:
        _timer = RunningTimer(
          startedAt: running.startedAt,
          category: running.category,
          accumulated: action.elapsed,
          resumedAt: null,
        );
        _ticker?.cancel();
        _ticker = null;
        await _save();
        notifyListeners();
        return;
      case LiveActivityActionType.resume:
        final resumedAt = action.occurredAt.isAfter(now)
            ? now
            : action.occurredAt;
        _timer = RunningTimer(
          startedAt: running.startedAt,
          category: running.category,
          accumulated: action.elapsed,
          resumedAt: resumedAt,
        );
        _startTicker();
        await _save();
        notifyListeners();
        return;
      case LiveActivityActionType.stop:
        _timer = null;
        _ticker?.cancel();
        _ticker = null;
        _liveActivityPoller?.cancel();
        _liveActivityPoller = null;
        final minutes = action.elapsed.inMinutes;
        if (minutes > 0) {
          _sessions.add(
            WorkSession(
              id: _newId(),
              start: running.startedAt,
              minutes: minutes,
              category: running.category,
            ),
          );
          await _commit();
        } else {
          await _save();
          notifyListeners();
        }
        return;
    }
  }

  Future<void> cancelTimer() async {
    await reconcileLiveActivityActions(synchronize: false);
    final running = _timer;
    final elapsed = timerElapsed;
    _timer = null;
    _ticker?.cancel();
    _ticker = null;
    _liveActivityPoller?.cancel();
    _liveActivityPoller = null;
    await _save();
    await _liveActivity.end(elapsed: elapsed, sessionId: running?.sessionId);
    notifyListeners();
  }

  /// Wipes everything. Used by the reset action in settings.
  Future<void> clearAll() async {
    final running = _timer;
    final elapsed = timerElapsed;
    _sessions = [];
    _timer = null;
    _ticker?.cancel();
    _ticker = null;
    _liveActivityPoller?.cancel();
    _liveActivityPoller = null;
    await _commit();
    await _liveActivity.end(elapsed: elapsed, sessionId: running?.sessionId);
  }

  // --- internals -----------------------------------------------------------

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_timer == null) return;
      notifyListeners();
    });
  }

  void _startLiveActivityPoller() {
    _liveActivityPoller?.cancel();
    _liveActivityPoller = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_timer == null) return;
      unawaited(reconcileLiveActivityActions(synchronize: false));
    });
  }

  Future<void> _synchronizeLiveActivityState() async {
    if (_timer == null) {
      await _liveActivity.end(elapsed: Duration.zero);
      return;
    }
    await _syncLiveActivity();
  }

  Future<void> _syncLiveActivity() async {
    final running = _timer;
    if (running == null) return;
    await _liveActivity.synchronize(
      sessionId: running.sessionId,
      startedAt: running.startedAt,
      elapsed: running.elapsedAt(now),
      category: running.category.label,
      goalMinutes: goals.focusMinutes,
      isPaused: running.isPaused,
    );
  }

  Future<void> _commit() async {
    _recompute();
    await _save();
    notifyListeners();
  }

  void _recompute({bool collectCelebrations = true}) {
    final grouped = <DateTime, List<WorkSession>>{};
    for (final session in _sessions) {
      grouped.putIfAbsent(session.day, () => []).add(session);
    }

    _byDay = {
      for (final entry in grouped.entries)
        entry.key: DailySummary.fromSessions(
          entry.key,
          entry.value,
          goalsOn(entry.key),
        ),
    };

    final previousCounts = _awardCounts;
    _awards = _awardsEngine.evaluate(
      byDay: _byDay,
      sessions: _sessions,
      today: today,
    );
    _awardCounts = {for (final award in _awards) award.id: award.timesEarned};

    if (collectCelebrations && previousCounts.isNotEmpty) {
      for (final award in _awards) {
        final before = previousCounts[award.id] ?? 0;
        if (award.timesEarned > before) _pendingCelebrations.add(award);
      }
    }
  }

  Future<void> _save() async {
    await _persistence.write({
      'version': _storeVersion,
      'goalHistory': _goalHistory.toJson(),
      'sessions': [for (final session in _sessions) session.toJson()],
      if (_timer != null) 'timer': _timer!.toJson(),
    });
  }

  String _newId() =>
      '${now.microsecondsSinceEpoch.toRadixString(36)}${_random.nextInt(1 << 20).toRadixString(36)}';
}
