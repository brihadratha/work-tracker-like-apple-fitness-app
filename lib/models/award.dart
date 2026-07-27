import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Visual family for a badge. Mirrors how Fitness groups its awards by colour.
enum AwardStyle { focus, sessions, consistency, perfect, milestone, quirk }

extension AwardStyleInfo on AwardStyle {
  List<Color> get gradient => switch (this) {
        AwardStyle.focus => const [AppColors.focusStart, AppColors.focusEnd],
        AwardStyle.sessions => const [AppColors.sessionsStart, AppColors.sessionsEnd],
        AwardStyle.consistency => const [
            AppColors.consistencyStart,
            AppColors.consistencyEnd,
          ],
        AwardStyle.perfect => const [Color(0xFF7B2BFF), Color(0xFFE44AF5)],
        AwardStyle.milestone => const [Color(0xFFFF8A00), AppColors.gold],
        AwardStyle.quirk => const [Color(0xFF2A6BFF), Color(0xFF37D6FF)],
      };
}

/// A badge the app can hand out. Definitions are static; whether one is earned
/// is recomputed from history every time.
@immutable
class AwardDefinition {
  const AwardDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.style,
    this.repeatable = false,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final AwardStyle style;

  /// Repeatable awards show a "×N" count, like Perfect Week in Fitness.
  final bool repeatable;
}

/// A definition plus the user's progress toward (or through) it.
@immutable
class Award {
  const Award({
    required this.definition,
    required this.timesEarned,
    this.firstEarnedOn,
    this.lastEarnedOn,
    this.progress = 0,
    this.progressLabel,
  });

  final AwardDefinition definition;
  final int timesEarned;
  final DateTime? firstEarnedOn;
  final DateTime? lastEarnedOn;

  /// 0–1 completion toward the next (or first) unlock.
  final double progress;

  /// e.g. "62 / 100 hours" — shown on locked badges.
  final String? progressLabel;

  bool get isEarned => timesEarned > 0;

  String get id => definition.id;
  String get title => definition.title;
  String get description => definition.description;
}
