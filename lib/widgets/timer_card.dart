import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../logic/format.dart';
import '../models/goals.dart';
import '../models/work_session.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Start/stop control for a live work block. Idle it offers a category and a
/// start button; running it becomes a stopwatch.
class TimerCard extends StatefulWidget {
  const TimerCard({super.key});

  @override
  State<TimerCard> createState() => _TimerCardState();
}

class _TimerCardState extends State<TimerCard> {
  WorkCategory _category = WorkCategory.deepWork;

  Future<void> _start(AppState state) async {
    HapticFeedback.mediumImpact();
    await state.startTimer(_category);
  }

  Future<void> _stop(AppState state) async {
    HapticFeedback.mediumImpact();
    final session = await state.stopTimer();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceElevated,
        content: Text(
          session == null
              ? 'Too short to log — blocks start at one minute.'
              : 'Logged ${Fmt.duration(session.minutes)} of ${session.category.label}.',
        ),
      ),
    );
  }

  Future<void> _confirmCancel(AppState state) async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Discard this block?'),
        content: const Text('The time you\'ve tracked so far won\'t be logged.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Going'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard', style: TextStyle(color: AppColors.focusEnd)),
          ),
        ],
      ),
    );
    if (discard ?? false) await state.cancelTimer();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: state.isTimerRunning ? _running(state) : _idle(state),
    );
  }

  Widget _idle(AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Start a block'),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: WorkCategory.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = WorkCategory.values[index];
              final selected = category == _category;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _category = category);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? category.color.withValues(alpha: 0.2)
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: selected ? category.color : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        category.icon,
                        size: 14,
                        color: selected ? category.color : AppColors.secondaryLabel,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        category.label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color:
                              selected ? AppColors.label : AppColors.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _start(state),
            icon: const Icon(Icons.play_arrow_rounded, size: 22),
            label: const Text(
              'Start',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _category.color.withValues(alpha: 0.9),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _running(AppState state) {
    final timer = state.timer!;
    final elapsed = state.timerElapsed;
    final goals = state.goals;
    final untilDeep = goals.deepSessionMinutes - elapsed.inMinutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _PulsingDot(color: timer.category.color),
            const SizedBox(width: 8),
            Text(
              timer.category.label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: timer.category.color,
                  ),
            ),
            const Spacer(),
            Text(
              'since ${Fmt.time(timer.startedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          Fmt.stopwatch(elapsed),
          style: const TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w300,
            letterSpacing: -2,
            fontFeatures: [FontFeature.tabularFigures()],
            color: AppColors.label,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _statusLine(untilDeep, goals),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () => _stop(state),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.focusStart,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Finish Block',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              onPressed: () => _confirmCancel(state),
              icon: const Icon(Icons.close_rounded),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceElevated,
                foregroundColor: AppColors.secondaryLabel,
                padding: const EdgeInsets.all(14),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _statusLine(int untilDeep, Goals goals) {
    if (untilDeep > 0) {
      return '$untilDeep min until this counts as deep work';
    }
    return 'Counting toward your Deep Work ring';
  }
}

/// The small breathing dot that marks a live timer.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_controller),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
