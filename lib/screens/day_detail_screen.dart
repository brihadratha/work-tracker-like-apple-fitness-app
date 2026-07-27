import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/format.dart';
import '../models/work_session.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/activity_rings.dart';
import '../widgets/ring_stats.dart';
import 'today_screen.dart';

/// Read-only look back at a single past day, opened from the history grid.
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: ActivityRings(
              size: 190,
              progress: {
                for (final kind in RingKind.values) kind: summary.progressFor(kind),
              },
            ),
          ),
          const SizedBox(height: 24),
          AppCard(child: RingStatColumn(summary: summary, dense: true)),
          const SizedBox(height: 14),
          if (summary.isPerfect)
            AppCard(
              color: AppColors.sessionsStart.withValues(alpha: 0.14),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: AppColors.sessionsEnd, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Perfect day — all three closed.',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.label,
                    ),
                  ),
                ],
              ),
            ),
          if (summary.isPerfect) const SizedBox(height: 14),
          if (summary.hasWork) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader('Active hours'),
                  HourStrip(summary: summary),
                ],
              ),
            ),
            const SizedBox(height: 22),
          ],
          SectionHeader('${sessions.length} block${sessions.length == 1 ? '' : 's'}'),
          if (sessions.isEmpty)
            const AppCard(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'Nothing logged this day',
                  style: TextStyle(fontSize: 14, color: AppColors.tertiaryLabel),
                ),
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
                          height: 1, indent: 60, color: AppColors.separator),
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
  Widget build(BuildContext context) {
    return SessionTile(session: session, deepThreshold: deepThreshold);
  }
}
