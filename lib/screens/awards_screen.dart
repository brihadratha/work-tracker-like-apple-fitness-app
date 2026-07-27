import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/award.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/award_badge.dart';

class AwardsScreen extends StatelessWidget {
  const AwardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final earned = state.earnedAwards;
    final locked = state.lockedAwards;
    final totalEarned = earned.fold<int>(0, (sum, a) => sum + a.timesEarned);

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          title: const Text('Awards'),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverList.list(
            children: [
              _AwardsSummary(
                unlocked: earned.length,
                total: state.awards.length,
                totalEarned: totalEarned,
              ),
              const SizedBox(height: 24),
              if (earned.isNotEmpty) ...[
                const SectionHeader('Earned'),
                _AwardGrid(awards: earned),
                const SizedBox(height: 28),
              ],
              if (locked.isNotEmpty) ...[
                const SectionHeader('Still to earn'),
                _AwardGrid(awards: locked),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AwardsSummary extends StatelessWidget {
  const _AwardsSummary({
    required this.unlocked,
    required this.total,
    required this.totalEarned,
  });

  final int unlocked;
  final int total;
  final int totalEarned;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              value: '$unlocked',
              caption: 'of $total unlocked',
              color: AppColors.gold,
            ),
          ),
          Container(width: 1, height: 38, color: AppColors.separator),
          Expanded(
            child: _Stat(
              value: '$totalEarned',
              caption: totalEarned == 1 ? 'badge earned' : 'badges earned',
              color: AppColors.consistencyEnd,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.caption, required this.color});

  final String value;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(caption, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _AwardGrid extends StatelessWidget {
  const _AwardGrid({required this.awards});

  final List<Award> awards;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 18,
        crossAxisSpacing: 12,
        childAspectRatio: 0.92,
      ),
      itemCount: awards.length,
      itemBuilder: (context, index) {
        final award = awards[index];
        return AwardBadge(
          award: award,
          onTap: () => AwardDetailSheet.show(context, award),
        );
      },
    );
  }
}
