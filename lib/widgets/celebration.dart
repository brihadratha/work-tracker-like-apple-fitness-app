import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/award.dart';
import '../theme/app_theme.dart';
import 'award_badge.dart';

/// Full-screen moment when a badge is earned: the medal springs in over a
/// burst of confetti. Queued awards are shown one after another.
class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({super.key, required this.awards});

  final List<Award> awards;

  static Future<void> show(BuildContext context, List<Award> awards) {
    if (awards.isEmpty) return Future.value();
    HapticFeedback.heavyImpact();
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.86),
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, _, _) => CelebrationOverlay(awards: awards),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
    _particles = _buildParticles();
  }

  List<_Particle> _buildParticles() {
    final random = math.Random(7);
    final palette = widget.awards.first.definition.style.gradient;
    return List.generate(46, (i) {
      return _Particle(
        angle: (i / 46) * math.pi * 2 + random.nextDouble() * 0.3,
        distance: 90 + random.nextDouble() * 190,
        size: 4 + random.nextDouble() * 6,
        color: [
          ...palette,
          AppColors.gold,
          AppColors.consistencyEnd,
        ][random.nextInt(4)],
        spin: random.nextDouble() * 6 - 3,
        delay: random.nextDouble() * 0.18,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index + 1 < widget.awards.length) {
      setState(() => _index++);
      _controller.forward(from: 0);
      HapticFeedback.heavyImpact();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final award = widget.awards[_index];
    final remaining = widget.awards.length - _index - 1;

    return GestureDetector(
      onTap: _next,
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                size: Size.infinite,
                painter: _ConfettiPainter(
                  particles: _particles,
                  progress: _controller.value,
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: CurvedAnimation(
                    parent: _controller,
                    curve: const Interval(0, 0.55, curve: Curves.elasticOut),
                  ),
                  child: AwardBadge(award: award, size: 168, showTitle: false),
                ),
                const SizedBox(height: 28),
                _FadeUp(
                  controller: _controller,
                  child: Column(
                    children: [
                      Text(
                        award.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontSize: 34,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 44),
                        child: Text(
                          award.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.35,
                            color: AppColors.secondaryLabel,
                          ),
                        ),
                      ),
                      if (award.definition.repeatable && award.timesEarned > 1) ...[
                        const SizedBox(height: 14),
                        Text(
                          'That\'s ${award.timesEarned} times now.',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 48,
              child: _FadeUp(
                controller: _controller,
                child: Text(
                  remaining > 0 ? 'Tap for $remaining more' : 'Tap to continue',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.tertiaryLabel,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slides its child up a few points as it fades in, after the badge lands.
class _FadeUp extends StatelessWidget {
  const _FadeUp({required this.controller, required this.child});

  final AnimationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.35, 0.8, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.25),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
    required this.spin,
    required this.delay,
  });

  final double angle;
  final double distance;
  final double size;
  final Color color;
  final double spin;
  final double delay;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.particles, required this.progress});

  final List<_Particle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 60);

    for (final particle in particles) {
      final t = ((progress - particle.delay) / (1 - particle.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final eased = Curves.easeOutCubic.transform(t);
      // A touch of gravity so the burst falls away rather than hanging.
      final gravity = 120 * t * t;
      final offset = Offset(
            math.cos(particle.angle) * particle.distance * eased,
            math.sin(particle.angle) * particle.distance * eased + gravity,
          ) +
          center;

      final paint = Paint()
        ..color = particle.color.withValues(alpha: (1 - t * t).clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(particle.spin * eased * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: particle.size,
            height: particle.size * 1.7,
          ),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.progress != progress;
}
