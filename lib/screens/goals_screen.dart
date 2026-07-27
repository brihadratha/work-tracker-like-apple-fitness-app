import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../logic/format.dart';
import '../models/daily_summary.dart';
import '../models/goals.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/activity_rings.dart';

/// Goal editor. The preview rings update live against today's actual numbers,
/// so you can see what a change would mean before committing to it.
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  late Goals _draft;

  @override
  void initState() {
    super.initState();
    _draft = context.read<AppState>().goals;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final preview = DailySummary.fromSessions(
      state.today,
      state.sessionsOn(state.today),
      _draft,
    );
    final changed = _draft != state.goals;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Daily Goals'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: ActivityRings(
              size: 170,
              animate: false,
              progress: {
                for (final kind in RingKind.values) kind: preview.progressFor(kind),
              },
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Previewed against today\'s ${Fmt.duration(preview.focusMinutes)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 26),

          _GoalSlider(
            kind: RingKind.focus,
            title: 'Focus',
            description: 'Total minutes of work logged in a day.',
            value: _draft.focusMinutes.toDouble(),
            min: 30,
            max: 720,
            step: 15,
            formatter: (v) => Fmt.duration(v.round()),
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(focusMinutes: v.round())),
          ),
          const SizedBox(height: 14),
          _GoalSlider(
            kind: RingKind.sessions,
            title: 'Deep Work',
            description:
                'Blocks of at least ${_draft.deepSessionMinutes} minutes, uninterrupted.',
            value: _draft.deepSessions.toDouble(),
            min: 1,
            max: 12,
            step: 1,
            formatter: (v) => '${v.round()} block${v.round() == 1 ? '' : 's'}',
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(deepSessions: v.round())),
          ),
          const SizedBox(height: 14),
          _GoalSlider(
            kind: RingKind.consistency,
            title: 'Active Hours',
            description: 'Distinct hours of the day containing some work.',
            value: _draft.activeHours.toDouble(),
            min: 1,
            max: 16,
            step: 1,
            formatter: (v) => '${v.round()} hour${v.round() == 1 ? '' : 's'}',
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(activeHours: v.round())),
          ),
          const SizedBox(height: 14),
          _GoalSlider(
            kind: RingKind.sessions,
            title: 'Deep block length',
            description: 'How long a block must run before it counts as deep.',
            value: _draft.deepSessionMinutes.toDouble(),
            min: 10,
            max: 90,
            step: 5,
            formatter: (v) => Fmt.duration(v.round()),
            onChanged: (v) => setState(
              () => _draft = _draft.copyWith(deepSessionMinutes: v.round()),
            ),
          ),

          const SizedBox(height: 26),
          FilledButton(
            onPressed: changed
                ? () async {
                    HapticFeedback.mediumImpact();
                    await state.setGoals(_draft);
                    if (context.mounted) Navigator.of(context).pop();
                  }
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.focusStart,
              disabledBackgroundColor: AppColors.surfaceElevated,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              changed ? 'Save Goals' : 'No Changes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: changed ? Colors.white : AppColors.tertiaryLabel,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'New goals start today. Days you\'ve already finished keep the goals '
            'you had then, so your streak and awards stay safe.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.35, color: AppColors.tertiaryLabel),
          ),
        ],
      ),
    );
  }
}

class _GoalSlider extends StatelessWidget {
  const _GoalSlider({
    required this.kind,
    required this.title,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.formatter,
    required this.onChanged,
  });

  final RingKind kind;
  final String title;
  final String description;
  final double value;
  final double min;
  final double max;
  final double step;
  final String Function(double) formatter;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(kind.icon, size: 17, color: kind.end),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: Theme.of(context).textTheme.titleMedium),
              ),
              Text(
                formatter(value),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: kind.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(description, style: Theme.of(context).textTheme.bodySmall),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: ((max - min) / step).round(),
              activeColor: kind.end,
              inactiveColor: AppColors.surfaceElevated,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}
