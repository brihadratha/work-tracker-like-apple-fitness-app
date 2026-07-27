import 'package:flutter/material.dart';

import '../models/daily_summary.dart';
import '../theme/app_theme.dart';

/// The "FOCUS 142/240 MIN" line that sits beside the rings.
class RingStatRow extends StatelessWidget {
  const RingStatRow({
    super.key,
    required this.kind,
    required this.summary,
    this.dense = false,
  });

  final RingKind kind;
  final DailySummary summary;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final value = summary.valueFor(kind);
    final goal = summary.goalFor(kind);
    final closed = summary.isClosed(kind);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              kind.label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: kind.end,
                    fontSize: dense ? 10 : 11,
                  ),
            ),
            if (closed) ...[
              const SizedBox(width: 5),
              Icon(Icons.check_circle_rounded, size: dense ? 11 : 12, color: kind.end),
            ],
          ],
        ),
        const SizedBox(height: 1),
        RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [
              TextSpan(
                text: '$value',
                style: TextStyle(
                  fontSize: dense ? 22 : 27,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                  color: AppColors.label,
                ),
              ),
              TextSpan(
                text: '/$goal',
                style: TextStyle(
                  fontSize: dense ? 15 : 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryLabel,
                ),
              ),
              TextSpan(
                text: ' ${kind.unit}',
                style: TextStyle(
                  fontSize: dense ? 10 : 11,
                  fontWeight: FontWeight.w600,
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

/// Vertical stack of all three ring stats.
class RingStatColumn extends StatelessWidget {
  const RingStatColumn({super.key, required this.summary, this.dense = false});

  final DailySummary summary;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final kind in RingKind.values) ...[
          RingStatRow(kind: kind, summary: summary, dense: dense),
          if (kind != RingKind.values.last) SizedBox(height: dense ? 12 : 18),
        ],
      ],
    );
  }
}

/// The 24-hour strip showing which hours contained work, mirroring the Stand
/// hours chart in Fitness.
class HourStrip extends StatelessWidget {
  const HourStrip({super.key, required this.summary});

  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    const kind = RingKind.consistency;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 44,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var hour = 0; hour < 24; hour++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: _HourBar(
                      active: summary.activeHourSlots.contains(hour),
                      color: kind.end,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final label in ['12A', '6A', '12P', '6P', '11P'])
              Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ],
    );
  }
}

class _HourBar extends StatelessWidget {
  const _HourBar({required this.active, required this.color});

  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: active ? 44 : 10,
      decoration: BoxDecoration(
        color: active ? color : color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
