import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../logic/format.dart';
import '../models/daily_summary.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'day_detail_screen.dart';

enum _HistoryRange { day, week, month, year }

extension on _HistoryRange {
  String get label => switch (this) {
    _HistoryRange.day => 'D',
    _HistoryRange.week => 'W',
    _HistoryRange.month => 'M',
    _HistoryRange.year => 'Y',
  };
}

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  _HistoryRange _range = _HistoryRange.day;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final buckets = _buckets(state, _range);
    final total = buckets.fold<int>(0, (sum, bucket) => sum + bucket.minutes);
    final active = buckets.where((bucket) => bucket.minutes > 0).length;
    final average = active == 0 ? 0 : total ~/ active;

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          title: const Text('History'),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
          sliver: SliverList.list(
            children: [
              _RangeSelector(
                selected: _range,
                onChanged: (range) => setState(() => _range = range),
              ),
              const SizedBox(height: 28),
              Text(
                _headline(_range),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 6),
              Text(
                Fmt.duration(total),
                style: const TextStyle(
                  fontSize: 44,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                active == 0
                    ? 'Your time will build here, one session at a time.'
                    : '${Fmt.duration(average)} average across $active active ${active == 1 ? 'period' : 'periods'}.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 26),
              _HistoryChart(buckets: buckets),
              const SizedBox(height: 30),
              const SectionHeader('Recent days'),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < 14; i++) ...[
                      _DayRow(
                        summary: state.summaryFor(
                          state.today.subtract(Duration(days: i)),
                        ),
                        onTap: () {
                          final day = state.today.subtract(Duration(days: i));
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DayDetailScreen(day: day),
                            ),
                          );
                        },
                      ),
                      if (i != 13)
                        const Divider(
                          height: 1,
                          indent: 66,
                          color: AppColors.separator,
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _headline(_HistoryRange range) => switch (range) {
    _HistoryRange.day => 'LAST 7 DAYS',
    _HistoryRange.week => 'LAST 12 WEEKS',
    _HistoryRange.month => 'LAST 12 MONTHS',
    _HistoryRange.year => 'LAST 5 YEARS',
  };
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.selected, required this.onChanged});

  final _HistoryRange selected;
  final ValueChanged<_HistoryRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          for (final range in _HistoryRange.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(range),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == range
                        ? AppColors.surfaceElevated
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: selected == range
                        ? const [
                            BoxShadow(color: Colors.black38, blurRadius: 5),
                          ]
                        : null,
                  ),
                  child: Text(
                    range.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected == range
                          ? AppColors.label
                          : AppColors.secondaryLabel,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bucket {
  const _Bucket(this.label, this.minutes);
  final String label;
  final int minutes;
}

List<_Bucket> _buckets(AppState state, _HistoryRange range) {
  switch (range) {
    case _HistoryRange.day:
      return [
        for (var offset = 6; offset >= 0; offset--)
          (() {
            final day = state.today.subtract(Duration(days: offset));
            return _Bucket(
              DateFormat.E().format(day).substring(0, 1),
              state.summaryFor(day).focusMinutes,
            );
          })(),
      ];
    case _HistoryRange.week:
      return [
        for (var week = 11; week >= 0; week--)
          (() {
            final end = state.today.subtract(Duration(days: week * 7));
            final minutes = List.generate(
              7,
              (i) => state
                  .summaryFor(end.subtract(Duration(days: i)))
                  .focusMinutes,
            ).fold<int>(0, (a, b) => a + b);
            return _Bucket(
              week % 3 == 0 ? DateFormat.Md().format(end) : '',
              minutes,
            );
          })(),
      ];
    case _HistoryRange.month:
      return [
        for (var offset = 11; offset >= 0; offset--)
          (() {
            final month = DateTime(
              state.today.year,
              state.today.month - offset,
            );
            final next = DateTime(month.year, month.month + 1);
            var minutes = 0;
            for (
              var day = month;
              day.isBefore(next);
              day = day.add(const Duration(days: 1))
            ) {
              minutes += state.summaryFor(day).focusMinutes;
            }
            return _Bucket(
              DateFormat.MMM().format(month).substring(0, 1),
              minutes,
            );
          })(),
      ];
    case _HistoryRange.year:
      return [
        for (var offset = 4; offset >= 0; offset--)
          (() {
            final year = state.today.year - offset;
            final minutes = state.summariesByDay.entries
                .where((entry) => entry.key.year == year)
                .fold<int>(0, (sum, entry) => sum + entry.value.focusMinutes);
            return _Bucket('$year', minutes);
          })(),
      ];
  }
}

class _HistoryChart extends StatelessWidget {
  const _HistoryChart({required this.buckets});
  final List<_Bucket> buckets;

  @override
  Widget build(BuildContext context) {
    final maxValue = buckets.fold<int>(
      1,
      (value, bucket) => math.max(value, bucket.minutes),
    );
    return SizedBox(
      height: 190,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final bucket in buckets)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: bucket.minutes == 0
                              ? 0.018
                              : bucket.minutes / maxValue,
                          widthFactor: 0.78,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  AppColors.focusStart,
                                  AppColors.focusEnd,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(7),
                              boxShadow: bucket.minutes > 0
                                  ? [
                                      BoxShadow(
                                        color: AppColors.focusEnd.withValues(
                                          alpha: 0.22,
                                        ),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      bucket.label,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.summary, required this.onTap});
  final DailySummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = summary.progressFor(RingKind.focus).clamp(0.0, 1.0);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 5,
                strokeCap: StrokeCap.round,
                backgroundColor: AppColors.focusStart.withValues(alpha: 0.18),
                valueColor: const AlwaysStoppedAnimation(AppColors.focusEnd),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Fmt.dayFull(summary.day),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${summary.sessionCount} ${summary.sessionCount == 1 ? 'session' : 'sessions'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              Fmt.duration(summary.focusMinutes),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: summary.focusMinutes > 0
                    ? AppColors.label
                    : AppColors.tertiaryLabel,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.tertiaryLabel,
            ),
          ],
        ),
      ),
    );
  }
}
