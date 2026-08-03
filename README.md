# Work Rings

An iOS work tracker built on the thing that actually makes Apple Fitness stick: three rings you
want to close, a streak you don't want to break, and a badge waiting on the other side of a good day.

Built in Flutter. Data is stored locally first and privately mirrored through the user’s iCloud account — no separate account and no telemetry.

## The three rings

| Ring | What closes it | Default goal |
| --- | --- | --- |
| **Focus** (red) | Total minutes of work logged in a day | 240 min |
| **Deep Work** (green) | Unbroken blocks of at least 25 minutes | 4 blocks |
| **Active Hours** (cyan) | Distinct hours of the day containing any work | 8 hours |

The split is deliberate. Focus rewards volume, Deep Work rewards not fragmenting your day, and
Active Hours rewards showing up across the day instead of cramming — the same way Move, Exercise
and Stand pull in three different directions.

Rings overshoot rather than cap, so a 2× day visibly laps itself, shadow and all.

## What's in it

- **Today** — the ring stack, a live timer with categories, a 24-hour activity strip, the last
  seven days as bars, and every block you've logged with swipe-to-delete and tap-to-edit.
- **Trends** — each ring's 30-day average measured against its 90-day baseline, with the arrow up
  or down and, when you're slipping, what it would take to turn it around. Plus a month-by-month
  history grid of miniature rings.
- **Awards** — 22 badges. Repeatable ones (Perfect Day, Deep Dive, Weekend Warrior) count up with a
  ×N chip; milestone ones (100 Hours, 30 Day Streak) show a progress arc while locked. Earning one
  triggers a full-screen confetti moment.
- **Summary** — perfect-day streak with your all-time record, lifetime totals, per-ring streaks,
  and goal editing with a live ring preview.

Goals are dated, the way Apple records your Move goal per day. A new goal takes effect today and
leaves finished days scored against the goal you actually had then — so raising your target can
never wipe a streak you already earned, and lowering it can't hand you days you didn't.

## Running it

Requires Xcode and a Mac for the iOS build.

```bash
flutter pub get
flutter run                     # a connected device or simulator
flutter build ios --release     # release build
```

## Tests

```bash
flutter test
```

42 tests. The logic suite covers ring maths (hour-spanning blocks, midnight rollover, overshoot),
streak behaviour (an unfinished today doesn't break yesterday's streak), dated goals (raising a
goal leaves past days and streaks untouched), trend direction, award thresholds, and state
persistence including timer recovery, legacy-store migration and corrupt-store handling. Everything
runs against an injected clock and in-memory store, so nothing depends on the wall clock or a
platform channel.

`test/render_screens_test.dart` renders each screen to `test/goldens/` against a seeded 90-day
history — that's how the layouts and ring geometry were checked. Refresh them with:

```bash
flutter test --update-goldens test/render_screens_test.dart
```

## Layout

```
lib/
  models/       WorkSession, DailySummary (ring maths), Goals, Award
  logic/        streaks, trends, awards_engine, formatting
  data/         JSON persistence (atomic write) behind a swappable interface
  state/        AppState — single ChangeNotifier, owns sessions/goals/timer
  widgets/      activity_rings (the CustomPainter), charts, badges, celebration
  screens/      today, trends, awards, summary, goals, day detail
```

## Notes

- The rings reflect **logged** blocks, so a running timer doesn't move them until you finish the
  block. That keeps a mid-block ring from tripping a celebration you haven't earned yet.
- A block that runs past midnight is credited to the day it started, and can't claim more than
  that day's remaining hours.
- Sessions, dated goals, and running timers are stored locally first and mirrored to iCloud Drive. The app remains usable when iCloud is unavailable.
- Timers survive being force-quit — a running timer is persisted and picked back up on launch.
- Streaks and awards are never stored, only ever recomputed from your blocks and your dated goals,
  so the history can't drift out of sync with what you actually did.
