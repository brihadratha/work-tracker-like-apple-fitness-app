import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../models/award.dart';
import '../theme/app_theme.dart';

/// A circular medal. Earned badges get their full gradient and a soft bloom;
/// locked ones sit greyed out behind a thin progress arc.
class AwardBadge extends StatelessWidget {
  const AwardBadge({
    super.key,
    required this.award,
    this.size = 82,
    this.showTitle = true,
    this.onTap,
  });

  final Award award;
  final double size;
  final bool showTitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final earned = award.isEarned;
    final gradient = award.definition.style.gradient;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (!earned)
                  CustomPaint(
                    size: Size.square(size),
                    painter: _ProgressArcPainter(
                      progress: award.progress,
                      color: gradient.last,
                    ),
                  ),
                Container(
                  width: size * 0.86,
                  height: size * 0.86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: earned
                          ? gradient
                          : const [Color(0xFF2A2A2C), Color(0xFF202022)],
                    ),
                    boxShadow: earned
                        ? [
                            BoxShadow(
                              color: gradient.last.withValues(alpha: 0.35),
                              blurRadius: size * 0.22,
                              spreadRadius: -size * 0.04,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    award.definition.icon,
                    size: size * 0.38,
                    color: earned
                        ? Colors.white
                        : AppColors.tertiaryLabel.withValues(alpha: 0.85),
                  ),
                ),
                if (earned && award.definition.repeatable && award.timesEarned > 1)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: _CountChip(count: award.timesEarned),
                  ),
              ],
            ),
          ),
          if (showTitle) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: size + 16,
              child: Text(
                award.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: earned ? AppColors.label : AppColors.secondaryLabel,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.background, width: 2),
      ),
      child: Text(
        '×$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.label,
        ),
      ),
    );
  }
}

class _ProgressArcPainter extends CustomPainter {
  _ProgressArcPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width / 2 - 1.5,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.75);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressArcPainter old) =>
      old.progress != progress || old.color != color;
}

/// Bottom sheet describing a single award.
class AwardDetailSheet extends StatelessWidget {
  const AwardDetailSheet({super.key, required this.award});

  final Award award;

  static Future<void> show(BuildContext context, Award award) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => AwardDetailSheet(award: award),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AwardBadge(award: award, size: 132, showTitle: false),
          const SizedBox(height: 20),
          Text(award.title, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            award.description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.secondaryLabel,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          if (award.isEarned)
            _EarnedFooter(award: award)
          else
            _LockedFooter(award: award),
        ],
      ),
    );
  }
}

class _EarnedFooter extends StatelessWidget {
  const _EarnedFooter({required this.award});

  final Award award;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      if (award.definition.repeatable) 'Earned ${award.timesEarned}×',
      if (award.firstEarnedOn != null)
        'First earned ${Fmt.dayShort(award.firstEarnedOn!)}',
      if (award.lastEarnedOn != null &&
          award.lastEarnedOn != award.firstEarnedOn)
        'Most recently ${Fmt.dayShort(award.lastEarnedOn!)}',
    ];

    return Column(
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              line,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.gold,
              ),
            ),
          ),
      ],
    );
  }
}

class _LockedFooter extends StatelessWidget {
  const _LockedFooter({required this.award});

  final Award award;

  @override
  Widget build(BuildContext context) {
    final label = award.progressLabel;
    return Column(
      children: [
        if (label != null)
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryLabel,
            ),
          ),
        if (award.progress > 0) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: award.progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.surfaceElevated,
              valueColor: AlwaysStoppedAnimation(
                award.definition.style.gradient.last,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
