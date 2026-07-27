import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A concentric ring stack. Progress values are uncapped — anything over 1.0
/// wraps back around and casts a shadow on the lap beneath it.
class ActivityRings extends StatefulWidget {
  const ActivityRings({
    super.key,
    required this.progress,
    this.size = 220,
    this.strokeWidth,
    this.animate = true,
    this.duration = const Duration(milliseconds: 1100),
    this.center,
  });

  /// Progress per ring, keyed by kind. Missing entries read as zero.
  final Map<RingKind, double> progress;
  final double size;
  final double? strokeWidth;
  final bool animate;
  final Duration duration;

  /// Optional widget drawn in the hollow middle.
  final Widget? center;

  @override
  State<ActivityRings> createState() => _ActivityRingsState();
}

class _ActivityRingsState extends State<ActivityRings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Map<RingKind, double> _from;
  late Map<RingKind, double> _to;

  @override
  void initState() {
    super.initState();
    _to = _normalized(widget.progress);
    _from = widget.animate ? {for (final k in RingKind.values) k: 0.0} : _to;
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant ActivityRings oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _normalized(widget.progress);
    if (_mapsEqual(next, _to)) return;
    // Re-aim the animation from wherever it currently sits so rapid updates
    // (a running timer) stay smooth instead of snapping.
    _from = _currentValues();
    _to = next;
    _controller
      ..duration = widget.animate ? widget.duration : Duration.zero
      ..forward(from: 0);
  }

  Map<RingKind, double> _normalized(Map<RingKind, double> input) {
    return {
      for (final kind in RingKind.values)
        kind: (input[kind] ?? 0).clamp(0.0, 99.0).toDouble(),
    };
  }

  Map<RingKind, double> _currentValues() {
    final t = Curves.easeOutCubic.transform(_controller.value.clamp(0.0, 1.0));
    return {
      for (final kind in RingKind.values)
        kind: ((_from[kind] ?? 0) + ((_to[kind] ?? 0) - (_from[kind] ?? 0)) * t),
    };
  }

  bool _mapsEqual(Map<RingKind, double> a, Map<RingKind, double> b) {
    for (final kind in RingKind.values) {
      if (((a[kind] ?? 0) - (b[kind] ?? 0)).abs() > 0.0005) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stroke = widget.strokeWidth ?? widget.size * 0.10;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _RingsPainter(progress: _currentValues(), strokeWidth: stroke),
            child: child,
          );
        },
        child: widget.center == null ? null : Center(child: widget.center),
      ),
    );
  }
}

/// Static, unanimated rings for dense contexts — history cells, list rows.
class MiniRings extends StatelessWidget {
  const MiniRings({
    super.key,
    required this.progress,
    this.size = 28,
    this.strokeWidth,
  });

  final Map<RingKind, double> progress;
  final double size;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingsPainter(
          progress: {
            for (final kind in RingKind.values)
              kind: (progress[kind] ?? 0).clamp(0.0, 99.0).toDouble(),
          },
          // Thin enough that all three rings still fit at grid-cell sizes.
          strokeWidth: strokeWidth ?? size * 0.115,
          minimal: true,
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({
    required this.progress,
    required this.strokeWidth,
    this.minimal = false,
  });

  final Map<RingKind, double> progress;
  final double strokeWidth;

  /// Skips shadows and glow for small sizes, where they'd just read as mud.
  final bool minimal;

  static const _startAngle = -math.pi / 2;
  static const _fullTurn = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Half a stroke of air between rings leaves the innermost one a real
    // hollow centre instead of a filled dot.
    final gap = strokeWidth * (minimal ? 0.35 : 0.5);

    for (var i = 0; i < RingKind.values.length; i++) {
      final kind = RingKind.values[i];
      final radius = size.width / 2 - strokeWidth / 2 - i * (strokeWidth + gap);
      if (radius <= 0) continue;
      _paintRing(canvas, center, radius, kind, progress[kind] ?? 0);
    }
  }

  void _paintRing(
    Canvas canvas,
    Offset center,
    double radius,
    RingKind kind,
    double value,
  ) {
    final rect = Rect.fromCircle(center: center, radius: radius);

    // The unfilled track: the ring's own colour, heavily dimmed.
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Color.lerp(kind.start, Colors.black, minimal ? 0.74 : 0.84)!;
    canvas.drawCircle(center, radius, track);

    if (value <= 0) return;

    // A sweep fixed to the circle, so the ring is deepest at 12 o'clock and
    // brightest just before it comes back around.
    final shader = SweepGradient(
      colors: [kind.start, kind.end, kind.start],
      stops: const [0.0, 0.82, 1.0],
      transform: const GradientRotation(_startAngle),
    ).createShader(rect);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = shader;

    if (value <= 1.0) {
      if (!minimal) _paintGlow(canvas, rect, kind, value);
      canvas.drawArc(rect, _startAngle, _fullTurn * value, false, arcPaint);
      return;
    }

    // Past 100%: lay down a complete lap, then draw the overflow on top with a
    // shadow so the overlap reads as depth rather than a flat seam.
    canvas.drawArc(rect, _startAngle, _fullTurn, false, arcPaint);

    final overflow = value - value.floor();
    // A dead-on multiple of the goal should show a full extra lap, not nothing.
    final sweep = overflow == 0 ? _fullTurn : _fullTurn * overflow;

    if (!minimal) {
      _paintCapShadow(canvas, center, radius, _startAngle + sweep);
      _paintGlow(canvas, rect, kind, 1);
    }
    canvas.drawArc(rect, _startAngle, sweep, false, arcPaint);
  }

  /// Soft halo around the filled portion, strongest once the ring is closed.
  void _paintGlow(Canvas canvas, Rect rect, RingKind kind, double value) {
    if (value < 0.98) return;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.9
      ..strokeCap = StrokeCap.round
      ..color = kind.end.withValues(alpha: 0.28)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * 0.55);
    canvas.drawArc(rect, _startAngle, _fullTurn * value, false, glow);
  }

  /// The drop shadow cast by the leading tip onto the lap underneath.
  void _paintCapShadow(Canvas canvas, Offset center, double radius, double angle) {
    final tip = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * 0.35);
    canvas.drawCircle(tip.translate(0, strokeWidth * 0.1), strokeWidth * 0.62, shadow);
  }

  @override
  bool shouldRepaint(covariant _RingsPainter old) {
    if (old.strokeWidth != strokeWidth || old.minimal != minimal) return true;
    for (final kind in RingKind.values) {
      if (old.progress[kind] != progress[kind]) return true;
    }
    return false;
  }
}
