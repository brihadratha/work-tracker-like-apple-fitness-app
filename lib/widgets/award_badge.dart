import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../models/award.dart';
import '../theme/app_theme.dart';

/// A dimensional, animated medal with a restrained moving highlight.
class AwardBadge extends StatefulWidget {
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
  State<AwardBadge> createState() => _AwardBadgeState();
}

class _AwardBadgeState extends State<AwardBadge> with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..forward();
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.award.isEarned) _shimmer.forward();
  }

  @override
  void didUpdateWidget(covariant AwardBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.award.isEarned && widget.award.isEarned) {
      _entrance.forward(from: 0);
      _shimmer.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final award = widget.award;
    final earned = award.isEarned;
    final colors = award.definition.style.gradient;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_entrance, _shimmer]),
            builder: (context, _) {
              final entrance = Curves.elasticOut.transform(_entrance.value);
              final tilt = earned
                  ? math.sin(_shimmer.value * math.pi * 2) * 0.025
                  : 0.0;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0015)
                  ..rotateY(tilt)
                  ..scaleByDouble(
                    0.82 + entrance * 0.18,
                    0.82 + entrance * 0.18,
                    1,
                    1,
                  ),
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      if (!earned)
                        CustomPaint(
                          size: Size.square(widget.size),
                          painter: _ProgressArcPainter(
                            progress: award.progress,
                            color: colors.last,
                          ),
                        ),
                      CustomPaint(
                        size: Size.square(widget.size * 0.88),
                        painter: _MedalPainter(
                          colors: earned
                              ? colors
                              : const [Color(0xFF303034), Color(0xFF171719)],
                          earned: earned,
                          shimmer: _shimmer.value,
                        ),
                      ),
                      Container(
                        width: widget.size * 0.57,
                        height: widget.size * 0.57,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: earned
                                ? Colors.white.withValues(alpha: 0.24)
                                : Colors.white.withValues(alpha: 0.05),
                          ),
                          gradient: RadialGradient(
                            center: const Alignment(-0.35, -0.4),
                            colors: earned
                                ? [
                                    Colors.white.withValues(alpha: 0.18),
                                    Colors.black.withValues(alpha: 0.18),
                                  ]
                                : const [Color(0xFF2C2C30), Color(0xFF202024)],
                          ),
                        ),
                        child: Icon(
                          award.definition.icon,
                          size: widget.size * 0.31,
                          color: earned
                              ? Colors.white
                              : AppColors.tertiaryLabel,
                          shadows: earned
                              ? const [
                                  Shadow(
                                    color: Colors.black45,
                                    offset: Offset(0, 2),
                                    blurRadius: 3,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      if (earned &&
                          award.definition.repeatable &&
                          award.timesEarned > 1)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: _CountChip(count: award.timesEarned),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (widget.showTitle) ...[
            const SizedBox(height: 9),
            SizedBox(
              width: widget.size + 18,
              child: Text(
                award.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.2,
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

class _MedalPainter extends CustomPainter {
  const _MedalPainter({
    required this.colors,
    required this.earned,
    required this.shimmer,
  });

  final List<Color> colors;
  final bool earned;
  final double shimmer;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.47;
    final path = Path();
    for (var i = 0; i < 12; i++) {
      final angle = -math.pi / 2 + i * math.pi / 6;
      final r = i.isEven ? radius : radius * 0.91;
      final point = Offset(
        center.dx + math.cos(angle) * r,
        center.dy + math.sin(angle) * r,
      );
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    path.close();

    if (earned) {
      canvas.drawShadow(
        path,
        colors.last.withValues(alpha: 0.75),
        size.width * 0.12,
        false,
      );
    }
    final rect = Offset.zero & size;
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.last,
            colors.first,
            Color.lerp(colors.first, Colors.black, 0.42)!,
          ],
          stops: const [0, 0.52, 1],
        ).createShader(rect),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.035
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: earned ? 0.72 : 0.12),
            Colors.black54,
          ],
        ).createShader(rect),
    );

    if (!earned) return;
    final x = -size.width + shimmer * size.width * 3;
    canvas.save();
    canvas.clipPath(path);
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.35);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawRect(
      Rect.fromLTWH(x, -size.height, size.width * 0.22, size.height * 3),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.48),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MedalPainter old) =>
      old.shimmer != shimmer || old.earned != earned || old.colors != colors;
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
