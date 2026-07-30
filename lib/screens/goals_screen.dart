import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../logic/format.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/activity_rings.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  late int _minutes;

  @override
  void initState() {
    super.initState();
    _minutes = context.read<AppState>().goals.focusMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final progress = state.todaySummary.focusMinutes / _minutes;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Daily Goal'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        children: [
          Center(
            child: ActivityRings(
              size: 220,
              strokeWidth: 28,
              animate: false,
              progress: {RingKind.focus: progress},
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_minutes',
                    style: const TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -2,
                    ),
                  ),
                  Text(
                    'MINUTES',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppColors.focusEnd),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Choose a goal that feels achievable every day.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.secondaryLabel),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepButton(
                icon: Icons.remove_rounded,
                onTap: () => _change(-15),
              ),
              SizedBox(
                width: 128,
                child: Text(
                  Fmt.duration(_minutes),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              _StepButton(icon: Icons.add_rounded, onTap: () => _change(15)),
            ],
          ),
          const SizedBox(height: 34),
          FilledButton(
            onPressed: _minutes == state.goals.focusMinutes
                ? null
                : () async {
                    HapticFeedback.mediumImpact();
                    await state.setGoals(
                      state.goals.copyWith(focusMinutes: _minutes),
                    );
                    if (context.mounted) Navigator.of(context).pop();
                  },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.focusEnd,
              disabledBackgroundColor: AppColors.surfaceElevated,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Set Daily Goal',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _change(int delta) {
    final next = (_minutes + delta).clamp(15, 720);
    if (next == _minutes) return;
    HapticFeedback.selectionClick();
    setState(() => _minutes = next);
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton.filled(
    onPressed: onTap,
    icon: Icon(icon),
    style: IconButton.styleFrom(
      minimumSize: const Size.square(52),
      backgroundColor: AppColors.surfaceElevated,
      foregroundColor: AppColors.label,
    ),
  );
}
