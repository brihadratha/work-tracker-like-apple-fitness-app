import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/format.dart';
import '../models/daily_summary.dart';
import '../models/work_session.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/activity_rings.dart';
import '../widgets/log_session_sheet.dart';
import '../widgets/timer_card.dart';
import 'goals_screen.dart';

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
              tooltip: 'Log time',
              onPressed: () => _logBlock(context, state),
              icon: const Icon(Icons.add_rounded),
            ),
            const SizedBox(width: 6),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
          sliver: SliverList.list(
            children: [
              Text(
                Fmt.dayFull(state.today).toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 14),
              _FocusHero(summary: summary),
              const SizedBox(height: 24),
              const TimerCard(),
              const SizedBox(height: 28),
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

class _FocusHero extends StatelessWidget {
  const _FocusHero({required this.summary});

  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    final progress = summary.progressFor(RingKind.focus);
    final remaining = (summary.goals.focusMinutes - summary.focusMinutes).clamp(
      0,
      9999,
    );
    return Column(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const GoalsScreen())),
          child: Semantics(
            button: true,
            label: 'Edit daily minutes goal',
            child: ActivityRings(
              size: 246,
              strokeWidth: 29,
              progress: {RingKind.focus: progress},
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${summary.focusMinutes}',
                    style: const TextStyle(
                      fontSize: 58,
                      height: 0.95,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -2.5,
                      color: AppColors.label,
                    ),
                  ),
                  const SizedBox(height: 8),
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
        ),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: Text(
            summary.isClosed(RingKind.focus)
                ? 'Goal complete. Keep the momentum if it feels good.'
                : summary.hasWork
                ? '$remaining minutes to close your ring.'
                : 'Start with one focused minute.',
            key: ValueKey(
              '${summary.focusMinutes}-${summary.goals.focusMinutes}',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryLabel,
            ),
          ),
        ),
      ],
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
        SectionHeader(
          sessions.isEmpty ? 'Today' : 'Today · ${sessions.length}',
        ),
        if (sessions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text(
              'Your sessions will appear here.',
              style: TextStyle(fontSize: 14, color: AppColors.tertiaryLabel),
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
        note: block.note,
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
          child: Icon(
            session.category.icon,
            size: 18,
            color: session.category.color,
          ),
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
