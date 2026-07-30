import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/format.dart';
import '../models/work_session.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/activity_rings.dart';
import 'today_screen.dart';

class DayDetailScreen extends StatelessWidget {
  const DayDetailScreen({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final summary = state.summaryFor(day);
    final sessions = state.sessionsOn(day);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(Fmt.relativeDay(day, state.today)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
        children: [
          Center(
            child: ActivityRings(
              size: 220,
              strokeWidth: 27,
              progress: {RingKind.focus: summary.progressFor(RingKind.focus)},
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${summary.focusMinutes}',
                    style: const TextStyle(
                      fontSize: 50,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -2,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'OF ${summary.goals.focusMinutes} MIN',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppColors.focusEnd),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          SectionHeader(
            '${sessions.length} ${sessions.length == 1 ? 'session' : 'sessions'}',
          ),
          if (sessions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'No time logged this day.',
                style: TextStyle(fontSize: 14, color: AppColors.tertiaryLabel),
              ),
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < sessions.length; i++) ...[
                    _ReadOnlyTile(
                      session: sessions[i],
                      deepThreshold: state.goals.deepSessionMinutes,
                    ),
                    if (i != sessions.length - 1)
                      const Divider(
                        height: 1,
                        indent: 60,
                        color: AppColors.separator,
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReadOnlyTile extends StatelessWidget {
  const _ReadOnlyTile({required this.session, required this.deepThreshold});
  final WorkSession session;
  final int deepThreshold;

  @override
  Widget build(BuildContext context) =>
      SessionTile(session: session, deepThreshold: deepThreshold);
}
