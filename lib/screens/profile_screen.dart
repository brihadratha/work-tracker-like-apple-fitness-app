import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/streaks.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/award_badge.dart';
import 'goals_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final perfect = state.perfectDayStreak;
    final logging = state.loggingStreak;
    final recentAwards = state.earnedAwards
        .where((a) => a.lastEarnedOn != null)
        .toList()
      ..sort((a, b) => b.lastEarnedOn!.compareTo(a.lastEarnedOn!));

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          title: const Text('Summary'),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverList.list(
            children: [
              _StreakCard(streak: perfect, loggingStreak: logging),
              const SizedBox(height: 14),
              _LifetimeCard(state: state),
              const SizedBox(height: 14),
              _RingStreaksCard(state: state),
              const SizedBox(height: 22),
              if (recentAwards.isNotEmpty) ...[
                const SectionHeader('Recent awards'),
                SizedBox(
                  height: 126,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: recentAwards.length.clamp(0, 10),
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      final award = recentAwards[index];
                      return AwardBadge(
                        award: award,
                        size: 76,
                        onTap: () => AwardDetailSheet.show(context, award),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 22),
              ],
              const SectionHeader('Settings'),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.track_changes_rounded,
                      label: 'Daily Goals',
                      value:
                          '${state.goals.focusMinutes} min · ${state.goals.deepSessions} blocks · ${state.goals.activeHours} hrs',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const GoalsScreen()),
                      ),
                    ),
                    const Divider(height: 1, indent: 56, color: AppColors.separator),
                    _SettingsTile(
                      icon: Icons.delete_outline_rounded,
                      label: 'Reset All Data',
                      destructive: true,
                      onTap: () => _confirmReset(context, state),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmReset(BuildContext context, AppState state) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Reset all data?'),
        content: const Text(
          'Every block, streak and award will be erased. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset', style: TextStyle(color: AppColors.focusEnd)),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await state.clearAll();
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak, required this.loggingStreak});

  final StreakInfo streak;
  final StreakInfo loggingStreak;

  @override
  Widget build(BuildContext context) {
    final isAlive = streak.current > 0;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                color: isAlive ? AppColors.gold : AppColors.tertiaryLabel,
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Perfect Day Streak',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${streak.current}',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 56,
                      color: isAlive ? AppColors.gold : AppColors.tertiaryLabel,
                    ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  streak.current == 1 ? 'day' : 'days',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.secondaryLabel,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _subtitle(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Longest ever',
                  value: '${streak.longest}',
                  suffix: streak.longest == 1 ? 'day' : 'days',
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Days logged in a row',
                  value: '${loggingStreak.current}',
                  suffix: loggingStreak.current == 1 ? 'day' : 'days',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _subtitle() {
    if (streak.current == 0) {
      return 'Close all three rings today to start a new streak.';
    }
    if (!streak.todayCounts) {
      return 'Today isn\'t closed yet — finish the rings to keep it alive.';
    }
    if (streak.current == streak.longest && streak.current > 1) {
      return 'This is your longest streak ever. Don\'t look down.';
    }
    return 'Closed all three rings ${streak.current} days running.';
  }
}

class _LifetimeCard extends StatelessWidget {
  const _LifetimeCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final hours = state.lifetimeMinutes / 60;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Lifetime'),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Focused',
                  value: hours >= 100
                      ? hours.round().toString()
                      : hours.toStringAsFixed(1),
                  suffix: 'hours',
                  color: AppColors.focusEnd,
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Blocks',
                  value: '${state.sessions.length}',
                  suffix: 'logged',
                  color: AppColors.sessionsEnd,
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Perfect days',
                  value: '${state.totalPerfectDays}',
                  suffix: 'closed',
                  color: AppColors.consistencyEnd,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingStreaksCard extends StatelessWidget {
  const _RingStreaksCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Streak by ring'),
          for (final kind in RingKind.values) ...[
            Builder(
              builder: (context) {
                final streak = state.streakFor(kind);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Icon(kind.icon, size: 17, color: kind.end),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          kind.label,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.label,
                          ),
                        ),
                      ),
                      Text(
                        '${streak.current}d',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: streak.current > 0
                              ? kind.end
                              : AppColors.tertiaryLabel,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 58,
                        child: Text(
                          'best ${streak.longest}',
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.suffix,
    this.color,
  });

  final String label;
  final String value;
  final String suffix;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9.5),
        ),
        const SizedBox(height: 3),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  color: color ?? AppColors.label,
                ),
              ),
              TextSpan(
                text: ' $suffix',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.secondaryLabel,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tint = destructive ? AppColors.focusEnd : AppColors.label;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, size: 21, color: tint),
      title: Text(
        label,
        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500, color: tint),
      ),
      subtitle: value == null
          ? null
          : Text(value!, style: Theme.of(context).textTheme.bodySmall),
      trailing: destructive
          ? null
          : const Icon(Icons.chevron_right_rounded,
              color: AppColors.tertiaryLabel, size: 20),
    );
  }
}
