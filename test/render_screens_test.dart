@Tags(['render'])
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:work_rings/data/persistence.dart';
import 'package:work_rings/models/goals.dart';
import 'package:work_rings/models/work_session.dart';
import 'package:work_rings/screens/awards_screen.dart';
import 'package:work_rings/screens/goals_screen.dart';
import 'package:work_rings/screens/profile_screen.dart';
import 'package:work_rings/screens/today_screen.dart';
import 'package:work_rings/screens/trends_screen.dart';
import 'package:work_rings/state/app_state.dart';
import 'package:work_rings/theme/app_theme.dart';

/// Renders each screen against a seeded history so the visual design can be
/// reviewed. Run with `flutter test --update-goldens test/render_screens_test.dart`
/// to refresh the PNGs in test/goldens/.
final _now = DateTime(2026, 7, 27, 15, 42);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadRealFonts();
  });

  Future<AppState> seededState() async {
    final state = AppState(
      persistence: InMemoryPersistence(_seedData()),
      clock: () => _now,
    );
    await state.load();
    return state;
  }

  Future<void> render(
    WidgetTester tester,
    String name,
    Widget screen, {
    AppState? withState,
    double scrollBy = 0,
    Future<void> Function(WidgetTester tester)? interact,
  }) async {
    final state = withState ?? await seededState();
    tester.view
      ..physicalSize = const Size(393 * 2, 852 * 2)
      ..devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark.copyWith(
            textTheme: AppTheme.dark.textTheme.apply(fontFamily: 'Roboto'),
          ),
          home: Scaffold(backgroundColor: AppColors.background, body: screen),
        ),
      ),
    );

    // Let the ring entrance animation finish before capturing.
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    if (interact != null) {
      await interact(tester);
      await tester.pumpAndSettle();
    }

    if (scrollBy > 0) {
      await tester.drag(find.byType(CustomScrollView), Offset(0, -scrollBy));
      await tester.pumpAndSettle();
    }

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets(
    'today',
    (tester) => render(tester, 'today', const TodayScreen()),
  );

  testWidgets(
    'trends',
    (tester) => render(tester, 'trends', const TrendsScreen()),
  );

  for (final range in ['W', 'M', 'Y']) {
    testWidgets(
      'history $range range',
      (tester) => render(
        tester,
        'history_${range.toLowerCase()}',
        const TrendsScreen(),
        interact: (tester) async {
          await tester.tap(find.byKey(ValueKey('history-range-$range')));
        },
      ),
    );
  }

  testWidgets(
    'history selected bar value',
    (tester) => render(
      tester,
      'history_selected',
      const TrendsScreen(),
      interact: (tester) async {
        final bar = tester.widget<GestureDetector>(
          find.byKey(const ValueKey('history-bar-9')),
        );
        bar.onTap!();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('history-selected-value')),
          findsOneWidget,
        );
      },
    ),
  );

  testWidgets(
    'trends history grid',
    (tester) =>
        render(tester, 'trends_history', const TrendsScreen(), scrollBy: 1400),
  );

  testWidgets(
    'awards',
    (tester) => render(tester, 'awards', const AwardsScreen()),
  );

  testWidgets(
    'summary',
    (tester) => render(tester, 'summary', const ProfileScreen()),
  );

  testWidgets(
    'goals',
    (tester) => render(tester, 'goals', const GoalsScreen()),
  );

  testWidgets('empty today', (tester) async {
    final state = AppState(
      persistence: InMemoryPersistence(),
      clock: () => _now,
    );
    await state.load();
    await render(tester, 'today_empty', const TodayScreen(), withState: state);
  });
}

/// Golden output is meaningless with the test-harness placeholder font, so pull
/// in the real Roboto and Material icon faces the SDK ships.
Future<void> _loadRealFonts() async {
  // Walk up from the dart binary until the SDK's font cache turns up, rather
  // than hard-coding how deep it is.
  Directory? fontDir;
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    final candidate = Directory(
      '${dir.path}/bin/cache/artifacts/material_fonts',
    );
    if (candidate.existsSync()) {
      fontDir = candidate;
      break;
    }
    dir = dir.parent;
  }
  if (fontDir == null) {
    fail(
      'Could not locate the Flutter material_fonts cache for golden rendering.',
    );
  }
  final fonts = fontDir;

  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final file in files) {
      final path = File('${fonts.path}/$file');
      if (!path.existsSync()) continue;
      loader.addFont(
        path.readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
      );
    }
    await loader.load();
  }

  await load('Roboto', ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

/// A believable few months of work history: mostly good days, some slippage,
/// a couple of monster days and a gap.
Map<String, dynamic> _seedData() {
  final random = Random(42);
  final today = DateTime(_now.year, _now.month, _now.day);
  final sessions = <WorkSession>[];
  var counter = 0;

  for (var daysAgo = 89; daysAgo >= 0; daysAgo--) {
    final day = today.subtract(Duration(days: daysAgo));
    final isWeekend = day.weekday >= DateTime.saturday;

    // A deliberate week off, six weeks back, so the history has texture.
    if (daysAgo >= 40 && daysAgo <= 46) continue;
    if (isWeekend && random.nextDouble() < 0.72) continue;

    // Recent weeks run stronger than older ones, so trends point up.
    final strength = daysAgo < 30 ? 1.0 : 0.62;
    final blocks = (2 + random.nextInt(5) * strength).round().clamp(1, 7);

    var hour = 8 + random.nextInt(2);
    for (var b = 0; b < blocks; b++) {
      final minutes = [25, 30, 45, 50, 60, 90][random.nextInt(6)];
      sessions.add(
        WorkSession(
          id: 'seed${counter++}',
          start: day.add(Duration(hours: hour, minutes: random.nextInt(30))),
          minutes: minutes,
          category:
              WorkCategory.values[random.nextInt(WorkCategory.values.length)],
          note: b == 0 ? 'Morning push' : null,
        ),
      );
      hour += 1 + random.nextInt(2);
      if (hour > 20) break;
    }
  }

  return {
    'version': 1,
    'goals': const Goals().toJson(),
    'sessions': [for (final session in sessions) session.toJson()],
  };
}
