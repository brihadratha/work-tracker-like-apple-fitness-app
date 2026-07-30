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
  DateTime? _anchor;
  int? _selectedBucket;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final anchor = _anchor ?? state.today;
    final period = _period(state, _range, anchor);
    final total = period.buckets.fold<int>(
      0,
      (sum, bucket) => sum + bucket.minutes,
    );
    final active = period.buckets.where((bucket) => bucket.minutes > 0).length;
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
                onChanged: (range) => setState(() {
                  _range = range;
                  _anchor = state.today;
                  _selectedBucket = null;
                }),
              ),
              const SizedBox(height: 20),
              _PeriodNavigator(
                label: period.title,
                canGoForward: !_isCurrentPeriod(state.today, anchor, _range),
                onBack: () => _movePeriod(-1, state.today),
                onForward: () => _movePeriod(1, state.today),
              ),
              const SizedBox(height: 18),
              Text(
                'FOCUSED TIME',
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
                    ? 'No focused minutes in this period.'
                    : '${Fmt.duration(average)} average across $active active ${active == 1 ? period.unit : '${period.unit}s'}.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              _HistoryChart(
                buckets: period.buckets,
                selectedIndex: _selectedBucket,
                onSelected: (index) => setState(() => _selectedBucket = index),
              ),
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

  void _movePeriod(int delta, DateTime today) {
    final anchor = _anchor ?? today;
    final next = switch (_range) {
      _HistoryRange.day => anchor.add(Duration(days: delta)),
      _HistoryRange.week => anchor.add(Duration(days: delta * 7)),
      _HistoryRange.month => DateTime(anchor.year, anchor.month + delta, 1),
      _HistoryRange.year => DateTime(anchor.year + delta, 1, 1),
    };
    if (delta > 0 && _isAfterCurrent(today, next, _range)) return;
    setState(() {
      _anchor = next;
      _selectedBucket = null;
    });
  }
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
                key: ValueKey('history-range-${range.label}'),
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

class _PeriodNavigator extends StatelessWidget {
  const _PeriodNavigator({
    required this.label,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
  });
  final String label;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: onBack,
          icon: const Icon(Icons.chevron_left_rounded),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.label,
          ),
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        IconButton.filledTonal(
          onPressed: canGoForward ? onForward : null,
          icon: const Icon(Icons.chevron_right_rounded),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.label,
            disabledForegroundColor: AppColors.tertiaryLabel,
          ),
        ),
      ],
    );
  }
}

class _Bucket {
  const _Bucket({
    required this.label,
    required this.valueLabel,
    required this.minutes,
  });
  final String label;
  final String valueLabel;
  final int minutes;
}

class _PeriodData {
  const _PeriodData({
    required this.title,
    required this.unit,
    required this.buckets,
  });
  final String title;
  final String unit;
  final List<_Bucket> buckets;
}

_PeriodData _period(AppState state, _HistoryRange range, DateTime anchor) {
  switch (range) {
    case _HistoryRange.day:
      final day = DateTime(anchor.year, anchor.month, anchor.day);
      final byHour = List<int>.filled(24, 0);
      for (final session in state.sessionsOn(day)) {
        for (var hour = 0; hour < 24; hour++) {
          final start = DateTime(day.year, day.month, day.day, hour);
          final end = start.add(const Duration(hours: 1));
          final overlapStart = session.start.isAfter(start)
              ? session.start
              : start;
          final overlapEnd = session.end.isBefore(end) ? session.end : end;
          if (overlapEnd.isAfter(overlapStart)) {
            byHour[hour] += overlapEnd.difference(overlapStart).inMinutes;
          }
        }
      }
      return _PeriodData(
        title: DateFormat('EEEE, MMMM d').format(day),
        unit: 'hour',
        buckets: [
          for (var hour = 0; hour < 24; hour++)
            _Bucket(
              label: switch (hour) {
                0 => '12a',
                6 => '6a',
                12 => '12p',
                18 => '6p',
                23 => '11p',
                _ => '',
              },
              valueLabel: DateFormat(
                'ha',
              ).format(DateTime(2020, 1, 1, hour)).toLowerCase(),
              minutes: byHour[hour],
            ),
        ],
      );
    case _HistoryRange.week:
      final day = DateTime(anchor.year, anchor.month, anchor.day);
      final start = day.subtract(Duration(days: day.weekday - 1));
      final end = start.add(const Duration(days: 6));
      return _PeriodData(
        title:
            '${DateFormat.MMMd().format(start)} – ${DateFormat.MMMd().format(end)}',
        unit: 'day',
        buckets: [
          for (var i = 0; i < 7; i++)
            (() {
              final date = start.add(Duration(days: i));
              return _Bucket(
                label: DateFormat.E().format(date).substring(0, 1),
                valueLabel: DateFormat.EEEE().format(date),
                minutes: state.summaryFor(date).focusMinutes,
              );
            })(),
        ],
      );
    case _HistoryRange.month:
      final month = DateTime(anchor.year, anchor.month, 1);
      final count = DateTime(month.year, month.month + 1, 0).day;
      return _PeriodData(
        title: DateFormat.yMMMM().format(month),
        unit: 'day',
        buckets: [
          for (var i = 1; i <= count; i++)
            _Bucket(
              label: i == 1 || i % 7 == 0 || i == count ? '$i' : '',
              valueLabel: DateFormat.MMMd().format(
                DateTime(month.year, month.month, i),
              ),
              minutes: state
                  .summaryFor(DateTime(month.year, month.month, i))
                  .focusMinutes,
            ),
        ],
      );
    case _HistoryRange.year:
      final year = anchor.year;
      return _PeriodData(
        title: '$year',
        unit: 'month',
        buckets: [
          for (var month = 1; month <= 12; month++)
            (() {
              final start = DateTime(year, month, 1);
              final end = DateTime(year, month + 1, 1);
              var total = 0;
              for (
                var day = start;
                day.isBefore(end);
                day = day.add(const Duration(days: 1))
              ) {
                total += state.summaryFor(day).focusMinutes;
              }
              return _Bucket(
                label: DateFormat.MMM().format(start).substring(0, 1),
                valueLabel: DateFormat.MMMM().format(start),
                minutes: total,
              );
            })(),
        ],
      );
  }
}

class _HistoryChart extends StatelessWidget {
  const _HistoryChart({
    required this.buckets,
    required this.selectedIndex,
    required this.onSelected,
  });
  final List<_Bucket> buckets;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final maxValue = buckets.fold<int>(
      0,
      (value, bucket) => math.max(value, bucket.minutes),
    );
    final step = _niceStep(maxValue);
    final axisMax = math.max(step * 4, step);
    final selected = selectedIndex == null ? null : buckets[selectedIndex!];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 26,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: selected == null
                ? const Text(
                    'Tap a bar to see its exact value',
                    key: ValueKey('hint'),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.tertiaryLabel,
                    ),
                  )
                : Text.rich(
                    key: const ValueKey('history-selected-value'),
                    TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.secondaryLabel,
                      ),
                      children: [
                        TextSpan(
                          text: '${selected.valueLabel}  ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: '${selected.minutes} min',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.focusEnd,
                          ),
                        ),
                        TextSpan(
                          text: '  ·  ${Fmt.duration(selected.minutes)}',
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 42,
              child: Column(
                children: [
                  const Text(
                    'MIN',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                      color: AppColors.tertiaryLabel,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 180,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var tick = 4; tick >= 0; tick--)
                          Text(
                            _axisLabel(step * tick),
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.secondaryLabel,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                children: [
                  const SizedBox(height: 25),
                  SizedBox(
                    height: 180,
                    child: Stack(
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (var i = 0; i < 5; i++)
                              Container(height: 1, color: AppColors.separator),
                          ],
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var index = 0; index < buckets.length; index++)
                              Expanded(
                                child: Semantics(
                                  button: true,
                                  label:
                                      '${buckets[index].valueLabel}, ${buckets[index].minutes} minutes',
                                  child: GestureDetector(
                                    key: ValueKey('history-bar-$index'),
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => onSelected(index),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: buckets.length > 20 ? 1 : 3,
                                      ),
                                      child: Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Opacity(
                                          opacity: buckets[index].minutes == 0
                                              ? 0
                                              : 1,
                                          child: FractionallySizedBox(
                                            heightFactor:
                                                buckets[index].minutes == 0
                                                ? 0.012
                                                : buckets[index].minutes /
                                                      axisMax,
                                            widthFactor: buckets.length > 20
                                                ? 0.72
                                                : 0.78,
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 260,
                                              ),
                                              curve: Curves.easeOutCubic,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.bottomCenter,
                                                  end: Alignment.topCenter,
                                                  colors: selectedIndex == index
                                                      ? const [
                                                          Color(0xFFFF285F),
                                                          Color(0xFFFF8AA1),
                                                        ]
                                                      : const [
                                                          AppColors.focusStart,
                                                          AppColors.focusEnd,
                                                        ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                boxShadow:
                                                    selectedIndex == index
                                                    ? [
                                                        BoxShadow(
                                                          color: AppColors
                                                              .focusEnd
                                                              .withValues(
                                                                alpha: 0.45,
                                                              ),
                                                          blurRadius: 10,
                                                        ),
                                                      ]
                                                    : null,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _XAxisLabels(buckets: buckets),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _XAxisLabels extends StatelessWidget {
  const _XAxisLabels({required this.buckets});
  final List<_Bucket> buckets;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const labelWidth = 38.0;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var index = 0; index < buckets.length; index++)
                if (buckets[index].label.isNotEmpty)
                  Positioned(
                    left:
                        ((index + 0.5) / buckets.length * constraints.maxWidth -
                                labelWidth / 2)
                            .clamp(0.0, constraints.maxWidth - labelWidth),
                    width: labelWidth,
                    child: Text(
                      buckets[index].label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.secondaryLabel,
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

int _niceStep(int maxValue) {
  if (maxValue <= 0) return 15;
  final rough = maxValue / 4;
  final magnitude = math
      .pow(10, (math.log(rough) / math.ln10).floor())
      .toDouble();
  final normalized = rough / magnitude;
  final nice = normalized <= 1
      ? 1
      : normalized <= 1.25
      ? 1.25
      : normalized <= 2
      ? 2
      : normalized <= 2.5
      ? 2.5
      : normalized <= 5
      ? 5
      : 10;
  return (nice * magnitude).ceil();
}

String _axisLabel(int minutes) => minutes >= 1000
    ? '${(minutes / 1000).toStringAsFixed(minutes % 1000 == 0 ? 0 : 1)}k'
    : '$minutes';

bool _isCurrentPeriod(DateTime today, DateTime anchor, _HistoryRange range) =>
    switch (range) {
      _HistoryRange.day => DateUtils.isSameDay(today, anchor),
      _HistoryRange.week => _weekStart(today) == _weekStart(anchor),
      _HistoryRange.month =>
        today.year == anchor.year && today.month == anchor.month,
      _HistoryRange.year => today.year == anchor.year,
    };

bool _isAfterCurrent(DateTime today, DateTime anchor, _HistoryRange range) =>
    switch (range) {
      _HistoryRange.day => DateTime(
        anchor.year,
        anchor.month,
        anchor.day,
      ).isAfter(DateTime(today.year, today.month, today.day)),
      _HistoryRange.week => _weekStart(anchor).isAfter(_weekStart(today)),
      _HistoryRange.month => DateTime(
        anchor.year,
        anchor.month,
      ).isAfter(DateTime(today.year, today.month)),
      _HistoryRange.year => anchor.year > today.year,
    };

DateTime _weekStart(DateTime day) {
  final normalized = DateTime(day.year, day.month, day.day);
  return normalized.subtract(Duration(days: normalized.weekday - 1));
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
