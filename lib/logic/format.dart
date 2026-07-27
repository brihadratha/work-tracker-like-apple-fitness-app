import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

/// Formatting helpers shared across screens.
class Fmt {
  const Fmt._();

  /// 95 → "1h 35m", 60 → "1h", 45 → "45m".
  static String duration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
  }

  /// Stopwatch face: "12:04" under an hour, "1:02:44" over.
  static String stopwatch(Duration elapsed) {
    final seconds = elapsed.inSeconds;
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  /// Ring values carry different units, so format per kind.
  static String ringValue(RingKind kind, num value) => switch (kind) {
        RingKind.focus => value.round().toString(),
        RingKind.sessions => value.round().toString(),
        RingKind.consistency => value.round().toString(),
      };

  static String ringAverage(RingKind kind, double value) => switch (kind) {
        RingKind.focus => '${value.round()} min',
        RingKind.sessions => value.toStringAsFixed(1),
        RingKind.consistency => value.toStringAsFixed(1),
      };

  static String percent(double progress) => '${(progress * 100).round()}%';

  static String time(DateTime dt) => DateFormat.jm().format(dt);

  static String dayFull(DateTime day) => DateFormat('EEEE, MMMM d').format(day);

  static String dayShort(DateTime day) => DateFormat('MMM d').format(day);

  static String monthYear(DateTime day) => DateFormat('MMMM yyyy').format(day);

  static String weekdayLetter(DateTime day) =>
      DateFormat('EEEE').format(day).substring(0, 1);

  /// "Today", "Yesterday", or a date.
  static String relativeDay(DateTime day, DateTime today) {
    final difference = day.difference(today).inDays;
    return switch (difference) {
      0 => 'Today',
      -1 => 'Yesterday',
      _ => DateFormat('EEE, MMM d').format(day),
    };
  }
}
