import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The daily targets that define a closed ring.
@immutable
class Goals {
  const Goals({
    this.focusMinutes = 240,
    this.deepSessions = 4,
    this.activeHours = 8,
    this.deepSessionMinutes = 25,
  });

  /// Focus ring: total minutes of logged work in a day.
  final int focusMinutes;

  /// Deep Work ring: number of uninterrupted blocks of at least
  /// [deepSessionMinutes].
  final int deepSessions;

  /// Active Hours ring: distinct hours of the day containing any work.
  final int activeHours;

  /// How long a single block must run to count toward the Deep Work ring.
  final int deepSessionMinutes;

  int goalFor(RingKind kind) => switch (kind) {
        RingKind.focus => focusMinutes,
        RingKind.sessions => deepSessions,
        RingKind.consistency => activeHours,
      };

  Goals copyWith({
    int? focusMinutes,
    int? deepSessions,
    int? activeHours,
    int? deepSessionMinutes,
  }) {
    return Goals(
      focusMinutes: focusMinutes ?? this.focusMinutes,
      deepSessions: deepSessions ?? this.deepSessions,
      activeHours: activeHours ?? this.activeHours,
      deepSessionMinutes: deepSessionMinutes ?? this.deepSessionMinutes,
    );
  }

  Goals withGoal(RingKind kind, int value) => switch (kind) {
        RingKind.focus => copyWith(focusMinutes: value),
        RingKind.sessions => copyWith(deepSessions: value),
        RingKind.consistency => copyWith(activeHours: value),
      };

  Map<String, dynamic> toJson() => {
        'focusMinutes': focusMinutes,
        'deepSessions': deepSessions,
        'activeHours': activeHours,
        'deepSessionMinutes': deepSessionMinutes,
      };

  factory Goals.fromJson(Map<String, dynamic> json) {
    const fallback = Goals();
    return Goals(
      focusMinutes: (json['focusMinutes'] as num?)?.round() ?? fallback.focusMinutes,
      deepSessions: (json['deepSessions'] as num?)?.round() ?? fallback.deepSessions,
      activeHours: (json['activeHours'] as num?)?.round() ?? fallback.activeHours,
      deepSessionMinutes:
          (json['deepSessionMinutes'] as num?)?.round() ?? fallback.deepSessionMinutes,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Goals &&
      other.focusMinutes == focusMinutes &&
      other.deepSessions == deepSessions &&
      other.activeHours == activeHours &&
      other.deepSessionMinutes == deepSessionMinutes;

  @override
  int get hashCode =>
      Object.hash(focusMinutes, deepSessions, activeHours, deepSessionMinutes);
}

/// A goal change, in force from [effectiveFrom] until the next one.
@immutable
class GoalChange {
  GoalChange({required DateTime effectiveFrom, required this.goals})
      : effectiveFrom = DateTime(
          effectiveFrom.year,
          effectiveFrom.month,
          effectiveFrom.day,
        );

  final DateTime effectiveFrom;
  final Goals goals;

  Map<String, dynamic> toJson() => {
        'from': effectiveFrom.toIso8601String(),
        'goals': goals.toJson(),
      };

  factory GoalChange.fromJson(Map<String, dynamic> json) => GoalChange(
        effectiveFrom: DateTime.parse(json['from'] as String),
        goals: Goals.fromJson(json['goals'] as Map<String, dynamic>),
      );
}

/// The record of what your goals were on any given day.
///
/// Raising a goal shouldn't erase the streak you already earned, so a change
/// applies from the day you make it forward. Past days keep the goal that was
/// actually in force when you worked them.
@immutable
class GoalHistory {
  const GoalHistory(this.changes);

  /// Sorted oldest first. Empty means "defaults, always".
  final List<GoalChange> changes;

  /// Lower bound for the very first goal, so that days predating any change the
  /// user made are still scored against a goal they actually had — not against
  /// a tougher one they set later.
  static final DateTime beginning = DateTime(1970);

  /// A history whose only entry has been in force since the beginning.
  factory GoalHistory.fromStart(Goals goals) =>
      GoalHistory([GoalChange(effectiveFrom: beginning, goals: goals)]);

  /// The goal in force on [day]. Days that predate the first recorded change
  /// use that earliest goal — there's nothing older to appeal to.
  Goals goalsOn(DateTime day) {
    if (changes.isEmpty) return const Goals();
    final key = DateTime(day.year, day.month, day.day);

    var result = changes.first.goals;
    for (final change in changes) {
      if (change.effectiveFrom.isAfter(key)) break;
      result = change.goals;
    }
    return result;
  }

  /// Records [goals] as taking effect on [from], replacing any change already
  /// made that same day. A change that matches the day before is dropped, so
  /// nudging a slider back and forth doesn't litter the history.
  GoalHistory withChange(DateTime from, Goals goals) {
    final entry = GoalChange(effectiveFrom: from, goals: goals);
    final next = [
      for (final change in changes)
        if (change.effectiveFrom != entry.effectiveFrom) change,
      entry,
    ]..sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom));

    final deduped = <GoalChange>[];
    for (final change in next) {
      if (deduped.isNotEmpty && deduped.last.goals == change.goals) continue;
      deduped.add(change);
    }
    return GoalHistory(deduped);
  }

  List<Map<String, dynamic>> toJson() => [
        for (final change in changes) change.toJson(),
      ];

  factory GoalHistory.fromJson(List<dynamic> json) {
    final changes = <GoalChange>[];
    for (final raw in json) {
      if (raw is! Map<String, dynamic>) continue;
      try {
        changes.add(GoalChange.fromJson(raw));
      } catch (_) {
        // Skip an unreadable entry rather than losing the whole history.
      }
    }
    changes.sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom));
    return GoalHistory(changes);
  }
}
