import 'package:flutter/material.dart';

/// The three rings, in draw order from outermost to innermost.
enum RingKind { focus, sessions, consistency }

extension RingKindInfo on RingKind {
  String get label => switch (this) {
        RingKind.focus => 'Focus',
        RingKind.sessions => 'Deep Work',
        RingKind.consistency => 'Active Hours',
      };

  /// Short name used where space is tight.
  String get shortLabel => switch (this) {
        RingKind.focus => 'Focus',
        RingKind.sessions => 'Deep',
        RingKind.consistency => 'Hours',
      };

  String get unit => switch (this) {
        RingKind.focus => 'MIN',
        RingKind.sessions => 'SESSIONS',
        RingKind.consistency => 'HRS',
      };

  IconData get icon => switch (this) {
        RingKind.focus => Icons.bolt_rounded,
        RingKind.sessions => Icons.psychology_alt_rounded,
        RingKind.consistency => Icons.schedule_rounded,
      };

  Color get start => switch (this) {
        RingKind.focus => AppColors.focusStart,
        RingKind.sessions => AppColors.sessionsStart,
        RingKind.consistency => AppColors.consistencyStart,
      };

  Color get end => switch (this) {
        RingKind.focus => AppColors.focusEnd,
        RingKind.sessions => AppColors.sessionsEnd,
        RingKind.consistency => AppColors.consistencyEnd,
      };
}

class AppColors {
  const AppColors._();

  static const background = Color(0xFF000000);
  static const surface = Color(0xFF1C1C1E);
  static const surfaceElevated = Color(0xFF2C2C2E);
  static const separator = Color(0x33FFFFFF);

  static const label = Color(0xFFFFFFFF);
  static const secondaryLabel = Color(0xFF98989F);
  static const tertiaryLabel = Color(0xFF636366);

  // Ring gradients run from the deeper shade to the brighter one, the way the
  // Fitness rings brighten as they come around.
  static const focusStart = Color(0xFFF4165B);
  static const focusEnd = Color(0xFFFF5E7D);

  static const sessionsStart = Color(0xFF6FE83F);
  static const sessionsEnd = Color(0xFFC5F84A);

  static const consistencyStart = Color(0xFF00C2E8);
  static const consistencyEnd = Color(0xFF2BF0D8);

  static const gold = Color(0xFFFFC942);
}

class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    const base = ColorScheme.dark(
      primary: AppColors.focusEnd,
      surface: AppColors.surface,
      onSurface: AppColors.label,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: base,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: NoSplash.splashFactory,
      fontFamily: '.SF Pro Text',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
          color: AppColors.label,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
          color: AppColors.label,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: AppColors.label,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.label,
        ),
        bodyMedium: TextStyle(fontSize: 15, color: AppColors.label),
        bodySmall: TextStyle(fontSize: 13, color: AppColors.secondaryLabel),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.secondaryLabel,
        ),
      ),
    );
  }
}

/// Rounded card used throughout, matching the Fitness app's grouped sections.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Small all-caps section header, e.g. "AWARDS".
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
