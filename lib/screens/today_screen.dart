import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/format.dart';
import '../models/daily_summary.dart';
import '../models/work_session.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/activity_rings.dart';
import '../widgets/charts.dart';
import '../widgets/log_session_sheet.dart';
import '../widgets/ring_stats.dart';
import '../widgets/timer_card.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final summary = state.todaySummary;
    final sessions = state.sessionsOn(state.today);

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          title: const Text('Today'),
          actions: [
            IconButton(
              tooltip: 'Log a block',
              onPressed: () => _logBlock(context, state),
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
            const SizedBox(width: 4),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverList.list(
            children: [
              Text(
                Fmt.dayFull(state.today).toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 16),
              _RingsHeader(summary: summary),
              const SizedBox(height: 20),
              _MotivationBanner(summary: summary),
              const SizedBox(height: 14),
              const TimerCard(),
              const SizedBox(height: 14),
              _ActiveHoursCard(summary: summary),
              const SizedBox(height: 14),
              _WeekCard(days: state.recentDays(7)),
              const SizedBox(height: 22),
              _SessionsSection(sessions: sessions, state: state),
            ],
          ),
        ),
      ],
    );
  }

  static Future<void> _logBlock(BuildContext context, AppState state) async {
    final block = await LogSessionSheet.show(context, now: state.now);
    if (block == null) return;
    await state.addSession(
      start: block.start,
      minutes: block.minutes,
      category: block.category,
      note: block.note,
    );
  }
}

class _RingsHeader extends StatelessWidget {
  const _RingsHeader({required this.summary});

  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: RingStatColumn(summary: summary)),
        const SizedBox(width: 12),
        ActivityRings(
          size: 176,
          progress: {
            for (final kind in RingKind.values) kind: summary.progressFor(kind),
          },
        ),
      ],
    );
  }
}

/// The one line of encouragement under the rings — what's left, or a
/// well-earned victory lap.
class _MotivationBanner extends StatelessWidget {
  const _MotivationBanner({required this.summary});

  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    final message = _message();
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: summary.isPerfect
          ? AppColors.sessionsStart.withValues(alpha: 0.14)
          : AppColors.surface,
      child: Row(
        children: [
          Icon(
            summary.isPerfect
                ? Icons.check_circle_rounded
                : Icons.arrow_circle_right_rounded,
            size: 20,
            color: summary.isPerfect ? AppColors.sessionsEnd : AppColors.focusEnd,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.3,
                fontWeight: FontWeight.w500,
                color: AppColors.label,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _message() {
    if (summary.isPerfect) {
      return 'All three rings closed. That\'s the day — anything else is bonus.';
    }
    if (!summary.hasWork) {
      return 'Nothing logged yet. One block is all it takes to start the day.';
    }

    // Nudge toward whichever ring is closest to closing.
    final open = RingKind.values.where((k) => !summary.isClosed(k)).toList()
      ..sort((a, b) => summary.progressFor(b).compareTo(summary.progressFor(a)));
    final nearest = open.first;
    final remaining = summary.goalFor(nearest) - summary.valueFor(nearest);

    return switch (nearest) {
      RingKind.focus =>
        '${Fmt.duration(remaining)} of focus left to close your Focus ring.',
      RingKind.sessions => remaining == 1
          ? 'One more deep block closes your Deep Work ring.'
          : '$remaining more deep blocks close your Deep Work ring.',
      RingKind.consistency => remaining == 1
          ? 'Work in one more hour of the day to close Active Hours.'
          : 'Work in $remaining more hours of the day to close Active Hours.',
    };
  }
}

class _ActiveHoursCard extends StatelessWidget {
  const _ActiveHoursCard({required this.summary});

  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            'Active hours',
            trailing: Text(
              '${summary.activeHours} of ${summary.goalFor(RingKind.consistency)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.consistencyEnd,
              ),
            ),
          ),
          const SizedBox(height: 4),
          HourStrip(summary: summary),
        ],
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.days});

  final List<DailySummary> days;

  @override
  Widget build(BuildContext context) {
    final total = days.fold<int>(0, (sum, day) => sum + day.focusMinutes);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            'Last 7 days',
            trailing: Text(
              '${Fmt.duration(total)} total',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.focusEnd,
              ),
            ),
          ),
          WeeklyBars(kind: RingKind.focus, days: days),
        ],
      ),
    );
  }
}

class _SessionsSection extends StatelessWidget {
  const _SessionsSection({required this.sessions, required this.state});

  final List<WorkSession> sessions;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader('${sessions.length} block${sessions.length == 1 ? '' : 's'}'),
        if (sessions.isEmpty)
          const AppCard(
            padding: EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            child: Center(
              child: Text(
                'No blocks logged today',
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
                  SessionTile(
                    session: sessions[i],
                    deepThreshold: state.goals.deepSessionMinutes,
                    onEdit: () => _edit(context, sessions[i]),
                    onDelete: () => state.deleteSession(sessions[i].id),
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
    );
  }

  Future<void> _edit(BuildContext context, WorkSession session) async {
    final block = await LogSessionSheet.show(
      context,
      existing: session,
      now: state.now,
    );
    if (block == null) return;
    await state.updateSession(
      session.copyWith(
        start: block.start,
        minutes: block.minutes,
        category: block.category,
        note: block.note ?? '',
      ),
    );
  }
}

/// One logged block. Swipe to delete, tap to edit.
class SessionTile extends StatelessWidget {
  const SessionTile({
    super.key,
    required this.session,
    required this.deepThreshold,
    this.onEdit,
    this.onDelete,
  });

  final WorkSession session;
  final int deepThreshold;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isDeep = session.minutes >= deepThreshold;

    return Dismissible(
      key: ValueKey(session.id),
      direction: onDelete == null
          ? DismissDirection.none
          : DismissDirection.endToStart,
      background: Container(
        color: AppColors.focusStart,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => onDelete?.call(),
      child: ListTile(
        onTap: onEdit,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: session.category.color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(session.category.icon, size: 18, color: session.category.color),
        ),
        title: Row(
          children: [
            Text(
              Fmt.duration(session.minutes),
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: AppColors.label,
              ),
            ),
            const SizedBox(width: 8),
            if (isDeep)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.sessionsStart.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text(
                  'DEEP',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: AppColors.sessionsEnd,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          session.note?.isNotEmpty ?? false
              ? '${Fmt.time(session.start)} · ${session.note}'
              : '${Fmt.time(session.start)} · ${session.category.label}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: AppColors.secondaryLabel),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.tertiaryLabel,
          size: 20,
        ),
      ),
    );
  }
}
