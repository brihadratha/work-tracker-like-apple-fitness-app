import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/celebration.dart';
import 'awards_screen.dart';
import 'profile_screen.dart';
import 'today_screen.dart';
import 'trends_screen.dart';

/// Tab shell. Also watches for freshly earned awards and puts up the
/// celebration once the frame that earned them has settled.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  bool _celebrating = false;

  static const _tabs = [
    TodayScreen(),
    TrendsScreen(),
    AwardsScreen(),
    ProfileScreen(),
  ];

  /// Held directly rather than looked up in dispose, where reading an
  /// inherited widget is no longer safe.
  late final AppState _state;

  @override
  void initState() {
    super.initState();
    _state = context.read<AppState>();
    _state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (_celebrating || !mounted) return;
    if (!_state.hasPendingCelebrations) return;

    _celebrating = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final awards = _state.takeCelebrations();
      if (mounted && awards.isNotEmpty) {
        await CelebrationOverlay.show(context, awards);
      }
      _celebrating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: const Color(0xF01C1C1E),
          indicatorColor: AppColors.focusStart.withValues(alpha: 0.22),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: states.contains(WidgetState.selected)
                  ? AppColors.label
                  : AppColors.secondaryLabel,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          height: 64,
          onDestinationSelected: (index) => setState(() => _index = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.radio_button_unchecked_rounded),
              selectedIcon: Icon(Icons.donut_large_rounded, color: AppColors.label),
              label: 'Today',
            ),
            NavigationDestination(
              icon: Icon(Icons.show_chart_rounded),
              selectedIcon: Icon(Icons.show_chart_rounded, color: AppColors.label),
              label: 'Trends',
            ),
            NavigationDestination(
              icon: Icon(Icons.military_tech_outlined),
              selectedIcon: Icon(Icons.military_tech_rounded, color: AppColors.label),
              label: 'Awards',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded, color: AppColors.label),
              label: 'Summary',
            ),
          ],
        ),
      ),
    );
  }
}
