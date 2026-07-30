import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../logic/format.dart';
import '../models/work_session.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

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

  Future<void> _finish(AppState state) async {
    HapticFeedback.mediumImpact();
    final session = await state.stopTimer();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surfaceElevated,
          content: Text(
            session == null
                ? 'Keep going for at least one minute to save it.'
                : '${Fmt.duration(session.minutes)} added to today.',
          ),
        ),
      );
  }

  Future<void> _discard(AppState state) async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Discard session?'),
        content: const Text('The focused time tracked so far won’t be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Discard',
              style: TextStyle(color: AppColors.focusEnd),
            ),
          ),
        ],
      ),
    );
    if (discard ?? false) await state.cancelTimer();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: state.isTimerRunning
            ? AppColors.focusStart.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: state.isTimerRunning
              ? AppColors.focusEnd.withValues(alpha: 0.28)
              : Colors.transparent,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: state.isTimerRunning ? _running(state) : _idle(state),
    );
  }

  Widget _idle(AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Start focus', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            PopupMenuButton<WorkCategory>(
              initialValue: _category,
              color: AppColors.surfaceElevated,
              onSelected: (value) => setState(() => _category = value),
              itemBuilder: (_) => [
                for (final category in WorkCategory.values)
                  PopupMenuItem(value: category, child: Text(category.label)),
              ],
              child: Row(
                children: [
                  Text(
                    _category.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _category.color,
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded, size: 18),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _start(state),
            icon: const Icon(Icons.play_arrow_rounded, size: 24),
            label: const Text(
              'Start Session',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.focusEnd,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _running(AppState state) {
    final paused = state.isTimerPaused;
    return Column(
      children: [
        Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: paused ? AppColors.secondaryLabel : AppColors.focusEnd,
                boxShadow: paused
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.focusEnd.withValues(alpha: 0.55),
                          blurRadius: 10,
                        ),
                      ],
              ),
            ),
            const SizedBox(width: 9),
            Text(
              paused ? 'PAUSED' : 'SESSION ACTIVE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: paused ? AppColors.secondaryLabel : AppColors.focusEnd,
              ),
            ),
            const Spacer(),
            Text(
              state.timer!.category.label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          Fmt.stopwatch(state.timerElapsed),
          style: const TextStyle(
            fontSize: 62,
            height: 1,
            fontWeight: FontWeight.w300,
            letterSpacing: -2.6,
            fontFeatures: [FontFeature.tabularFigures()],
            color: AppColors.label,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoundControl(
              icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              label: paused ? 'Resume' : 'Pause',
              foreground: Colors.black,
              background: Colors.white,
              onTap: paused ? state.resumeTimer : state.pauseTimer,
            ),
            const SizedBox(width: 22),
            _RoundControl(
              icon: Icons.stop_rounded,
              label: 'Finish',
              foreground: Colors.white,
              background: AppColors.focusEnd,
              onTap: () => _finish(state),
            ),
          ],
        ),
        const SizedBox(height: 18),
        TextButton(
          onPressed: () => _discard(state),
          child: const Text(
            'Discard session',
            style: TextStyle(color: AppColors.secondaryLabel),
          ),
        ),
      ],
    );
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton.filled(
          onPressed: onTap,
          icon: Icon(icon, size: 32),
          style: IconButton.styleFrom(
            minimumSize: const Size.square(68),
            backgroundColor: background,
            foregroundColor: foreground,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
