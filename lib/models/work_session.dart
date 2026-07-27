import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The kind of work a session was. Purely descriptive — every category counts
/// toward the Focus ring; only sessions long enough count as Deep Work.
enum WorkCategory { deepWork, meetings, admin, learning, creative }

extension WorkCategoryInfo on WorkCategory {
  String get label => switch (this) {
        WorkCategory.deepWork => 'Deep Work',
        WorkCategory.meetings => 'Meetings',
        WorkCategory.admin => 'Admin',
        WorkCategory.learning => 'Learning',
        WorkCategory.creative => 'Creative',
      };

  IconData get icon => switch (this) {
        WorkCategory.deepWork => Icons.center_focus_strong_rounded,
        WorkCategory.meetings => Icons.groups_rounded,
        WorkCategory.admin => Icons.inbox_rounded,
        WorkCategory.learning => Icons.school_rounded,
        WorkCategory.creative => Icons.brush_rounded,
      };

  Color get color => switch (this) {
        WorkCategory.deepWork => AppColors.focusEnd,
        WorkCategory.meetings => AppColors.consistencyStart,
        WorkCategory.admin => AppColors.secondaryLabel,
        WorkCategory.learning => AppColors.sessionsStart,
        WorkCategory.creative => AppColors.gold,
      };

  static WorkCategory fromName(String? name) => WorkCategory.values.firstWhere(
        (c) => c.name == name,
        orElse: () => WorkCategory.deepWork,
      );
}

/// A single logged block of work.
@immutable
class WorkSession {
  const WorkSession({
    required this.id,
    required this.start,
    required this.minutes,
    required this.category,
    this.note,
  });

  final String id;
  final DateTime start;
  final int minutes;
  final WorkCategory category;
  final String? note;

  DateTime get end => start.add(Duration(minutes: minutes));

  /// The calendar day this session is attributed to.
  DateTime get day => DateTime(start.year, start.month, start.day);

  WorkSession copyWith({
    DateTime? start,
    int? minutes,
    WorkCategory? category,
    String? note,
  }) {
    return WorkSession(
      id: id,
      start: start ?? this.start,
      minutes: minutes ?? this.minutes,
      category: category ?? this.category,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start.toIso8601String(),
        'minutes': minutes,
        'category': category.name,
        if (note != null && note!.isNotEmpty) 'note': note,
      };

  factory WorkSession.fromJson(Map<String, dynamic> json) {
    return WorkSession(
      id: json['id'] as String,
      start: DateTime.parse(json['start'] as String),
      minutes: (json['minutes'] as num).round(),
      category: WorkCategoryInfo.fromName(json['category'] as String?),
      note: json['note'] as String?,
    );
  }

  @override
  bool operator ==(Object other) => other is WorkSession && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
