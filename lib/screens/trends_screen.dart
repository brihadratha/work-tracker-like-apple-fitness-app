import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/format.dart';
import '../logic/trends.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/charts.dart';
import 'day_detail_screen.dart';

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final today = context.read<AppState>().today;
    _visibleMonth = DateTime(today.year, today.month);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final trends = state.trends;
    final upCount = trends.where((t) => t.isUp).length;
    final measurable =
        trends.where((t) => t.direction != TrendDirection.notEnoughData).length;

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          title: const Text('Trends'),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverList.list(
            children: [
              if (measurable > 0) _TrendSummary(up: upCount, total: measurable),
              if (measurable > 0) const SizedBox(height: 16),
              for (final trend in trends) ...[
                _TrendCard(trend: trend, state: state),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 10),
              _HistoryCard(
                month: _visibleMonth,
                state: state,
                onMonthChange: (delta) {
                  setState(() {
                    _visibleMonth = DateTime(
                      _visibleMonth.year,
                      _visibleMonth.month + delta,
                    );
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrendSummary extends StatelessWidget {
  const _TrendSummary({required this.up, required this.total});

  final int up;
  final int total;

  @override
  Widget build(BuildContext context) {
    final headline = up == total
        ? 'Everything\'s trending up.'
        : up == 0
            ? 'All three need a push.'
            : '$up of $total trending up.';

    return AppCard(
      child: Row(
        children: [
          Icon(
            up >= total - up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: up >= total - up ? AppColors.sessionsEnd : AppColors.focusEnd,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headline, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Your last 30 days measured against your last 90.',
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

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.trend, required this.state});

  final Trend trend;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final kind = trend.kind;
    final noData = trend.direction == TrendDirection.notEnoughData;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TrendArrow(direction: trend.direction, color: kind.end),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kind.label.toUpperCase(),
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: kind.end),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      noData
                          ? 'Not enough history yet'
                          : Fmt.ringAverage(kind, trend.recentAverage),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: noData ? 16 : 22,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      noData
                          ? 'Log a couple of weeks and trends appear here.'
                          : '90-day average ${Fmt.ringAverage(kind, trend.baselineAverage)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          WeeklyBars(kind: kind, days: state.recentDays(7), height: 108),
          if (trend.isDown && trend.dailyBoostToTurnAround != null) ...[
            const SizedBox(height: 12),
            _TurnaroundHint(
              kind: kind,
              boost: trend.dailyBoostToTurnAround!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Fitness tells you what it would take to flip a downward trend; so does this.
class _TurnaroundHint extends StatelessWidget {
  const _TurnaroundHint({required this.kind, required this.boost});

  final RingKind kind;
  final double boost;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag_rounded, size: 16, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Add about ${Fmt.ringAverage(kind, boost)} a day for a week to turn this around.',
              style: const TextStyle(
                fontSize: 13,
                height: 1.3,
                color: AppColors.secondaryLabel,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendArrow extends StatelessWidget {
  const _TrendArrow({required this.direction, required this.color});

  final TrendDirection direction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final (icon, tint) = switch (direction) {
      TrendDirection.up => (Icons.arrow_upward_rounded, color),
      TrendDirection.down => (Icons.arrow_downward_rounded, AppColors.secondaryLabel),
      TrendDirection.steady => (Icons.remove_rounded, AppColors.secondaryLabel),
      TrendDirection.notEnoughData => (
          Icons.hourglass_empty_rounded,
          AppColors.tertiaryLabel,
        ),
    };

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: tint, size: 22),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.month,
    required this.state,
    required this.onMonthChange,
  });

  final DateTime month;
  final AppState state;
  final void Function(int delta) onMonthChange;

  @override
  Widget build(BuildContext context) {
    final isCurrentMonth =
        month.year == state.today.year && month.month == state.today.month;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  Fmt.monthYear(month),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: () => onMonthChange(-1),
                icon: const Icon(Icons.chevron_left_rounded),
                color: AppColors.secondaryLabel,
              ),
              IconButton(
                onPressed: isCurrentMonth ? null : () => onMonthChange(1),
                icon: const Icon(Icons.chevron_right_rounded),
                color: AppColors.secondaryLabel,
                disabledColor: AppColors.tertiaryLabel.withValues(alpha: 0.4),
              ),
            ],
          ),
          const SizedBox(height: 8),
          HistoryGrid(
            month: month,
            today: state.today,
            summaryFor: state.summaryFor,
            onDayTap: (day) => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => DayDetailScreen(day: day)),
            ),
          ),
        ],
      ),
    );
  }
}
