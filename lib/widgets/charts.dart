import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../models/daily_summary.dart';
import '../theme/app_theme.dart';
import 'activity_rings.dart';

/// Seven-day bar chart for one ring, with a dashed goal line. Bars that reach
/// the goal light up in the ring's colour; the rest stay muted.
class WeeklyBars extends StatelessWidget {
  const WeeklyBars({
    super.key,
    required this.kind,
    required this.days,
    this.height = 128,
  });

  final RingKind kind;
  final List<DailySummary> days;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();

    final goal = days.last.goalFor(kind).toDouble();
    final peak = days
        .map((d) => d.valueFor(kind).toDouble())
        .fold<double>(goal, (a, b) => a > b ? a : b);
    // Leave headroom so a record day doesn't touch the ceiling.
    final scaleMax = peak * 1.15;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const labelHeight = 20.0;
          final plotHeight = constraints.maxHeight - labelHeight;
          final goalY = plotHeight * (1 - goal / scaleMax);

          return Stack(
            children: [
              Positioned(
                top: goalY,
                left: 0,
                right: 0,
                child: CustomPaint(
                  size: Size(constraints.maxWidth, 1),
                  painter: _DashedLinePainter(
                    color: AppColors.tertiaryLabel.withValues(alpha: 0.7),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final day in days)
                    Expanded(
                      child: _Bar(
                        kind: kind,
                        day: day,
                        plotHeight: plotHeight,
                        scaleMax: scaleMax,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.kind,
    required this.day,
    required this.plotHeight,
    required this.scaleMax,
  });

  final RingKind kind;
  final DailySummary day;
  final double plotHeight;
  final double scaleMax;

  @override
  Widget build(BuildContext context) {
    final value = day.valueFor(kind).toDouble();
    final closed = day.isClosed(kind);
    final barHeight = scaleMax <= 0 ? 0.0 : (value / scaleMax) * plotHeight;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          height: barHeight.clamp(value > 0 ? 4.0 : 0.0, plotHeight),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            gradient: closed
                ? LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [kind.start, kind.end],
                  )
                : null,
            color: closed ? null : kind.start.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 14,
          child: Text(
            Fmt.weekdayLetter(day.day),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: closed ? kind.end : AppColors.tertiaryLabel,
                  letterSpacing: 0,
                ),
          ),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 4.0;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter old) => old.color != color;
}

/// A calendar month of days, each rendered as a tiny ring stack — the app's
/// version of the Fitness activity history.
class HistoryGrid extends StatelessWidget {
  const HistoryGrid({
    super.key,
    required this.month,
    required this.summaryFor,
    required this.today,
    this.onDayTap,
  });

  final DateTime month;
  final DailySummary Function(DateTime) summaryFor;
  final DateTime today;
  final void Function(DateTime day)? onDayTap;

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Monday-first grid, matching the weekday labels below.
    final leadingBlanks = firstOfMonth.weekday - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final label in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 0,
                        ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: leadingBlanks + daysInMonth,
          itemBuilder: (context, index) {
            if (index < leadingBlanks) return const SizedBox.shrink();
            final day = DateTime(month.year, month.month, index - leadingBlanks + 1);
            if (day.isAfter(today)) {
              return const _FutureDayCell();
            }
            final summary = summaryFor(day);
            return _HistoryCell(
              day: day,
              summary: summary,
              isToday: day == today,
              onTap: onDayTap == null ? null : () => onDayTap!(day),
            );
          },
        ),
      ],
    );
  }
}

class _HistoryCell extends StatelessWidget {
  const _HistoryCell({
    required this.day,
    required this.summary,
    required this.isToday,
    this.onTap,
  });

  final DateTime day;
  final DailySummary summary;
  final bool isToday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: MiniRings(
              progress: {
                for (final kind in RingKind.values) kind: summary.progressFor(kind),
              },
              size: 32,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
              color: isToday ? AppColors.label : AppColors.tertiaryLabel,
            ),
          ),
        ],
      ),
    );
  }
}

class _FutureDayCell extends StatelessWidget {
  const _FutureDayCell();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: AppColors.surfaceElevated,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
