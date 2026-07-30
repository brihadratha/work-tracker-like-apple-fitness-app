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
    final streak = state.perfectDayStreak;
    final recentAwards =
        state.earnedAwards.where((a) => a.lastEarnedOn != null).toList()
          ..sort((a, b) => b.lastEarnedOn!.compareTo(a.lastEarnedOn!));

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          title: const Text('Summary'),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
          sliver: SliverList.list(
            children: [
              _StreakHero(streak: streak),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      value: _hours(state.lifetimeMinutes),
                      label: 'hours focused',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Metric(
                      value: '${state.sessions.length}',
                      label: 'sessions',
                    ),
                  ),
                ],
              ),
              if (recentAwards.isNotEmpty) ...[
                const SizedBox(height: 30),
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
              ],
              const SizedBox(height: 30),
              const SectionHeader('Settings'),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.track_changes_rounded,
                        color: AppColors.focusEnd,
                      ),
                      title: const Text('Daily minutes goal'),
                      subtitle: Text('${state.goals.focusMinutes} minutes'),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.tertiaryLabel,
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const GoalsScreen()),
                      ),
                    ),
                    const Divider(
                      height: 1,
                      indent: 56,
                      color: AppColors.separator,
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.focusEnd,
                      ),
                      title: const Text(
                        'Reset all data',
                        style: TextStyle(color: AppColors.focusEnd),
                      ),
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

  static String _hours(int minutes) {
    final hours = minutes / 60;
    return hours >= 100 ? '${hours.round()}' : hours.toStringAsFixed(1);
  }

  Future<void> _confirmReset(BuildContext context, AppState state) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Reset all data?'),
        content: const Text(
          'Every session, streak and award will be erased. This can’t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Reset',
              style: TextStyle(color: AppColors.focusEnd),
            ),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await state.clearAll();
  }
}

class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.streak});
  final StreakInfo streak;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: streak.current > 0
                    ? const [Color(0xFFFF8A00), AppColors.gold]
                    : const [
                        AppColors.surfaceElevated,
                        AppColors.surfaceElevated,
                      ],
              ),
              boxShadow: streak.current > 0
                  ? [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.25),
                        blurRadius: 18,
                      ),
                    ]
                  : null,
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: Colors.black,
              size: 35,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${streak.current} day streak',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 5),
                Text(
                  streak.current == 0
                      ? 'Close your ring today to begin.'
                      : 'Best: ${streak.longest} days',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
            color: AppColors.focusEnd,
          ),
        ),
        const SizedBox(height: 3),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}
