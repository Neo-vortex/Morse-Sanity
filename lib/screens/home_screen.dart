import 'dart:math';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import '../widgets/motion.dart';
import 'course_screen.dart';
import 'practice_screen.dart';
import 'reference_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'translate_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  void _open(Widget screen) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final titles = [s.tabCourse, s.tabPractice, s.tabTranslate, s.titleChart];
    return Scaffold(
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(titles[_index], key: ValueKey(_index)),
        ),
        actions: [
          _StreakChip(onTap: () => _open(const StatsScreen())),
          const SizedBox(width: 6),
          _GoalRing(onTap: () => _open(const StatsScreen())),
          IconButton(
            tooltip: s.settings,
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => _open(const SettingsScreen()),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          CourseScreen(),
          PracticeScreen(),
          TranslateScreen(),
          ReferenceScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.route_outlined),
            selectedIcon: const Icon(Icons.route),
            label: s.tabCourse,
          ),
          NavigationDestination(
            icon: const Icon(Icons.sports_esports_outlined),
            selectedIcon: const Icon(Icons.sports_esports),
            label: s.tabPractice,
          ),
          NavigationDestination(
            icon: const Icon(Icons.translate_outlined),
            selectedIcon: const Icon(Icons.translate),
            label: s.tabTranslate,
          ),
          NavigationDestination(
            icon: const Icon(Icons.grid_view_outlined),
            selectedIcon: const Icon(Icons.grid_view_rounded),
            label: s.tabChart,
          ),
        ],
      ),
    );
  }
}

/// Flame with the current day streak; grey when today isn't done yet.
class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = AppScope.of(context).progress;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) {
        final lit = progress.practisedToday;
        final color = lit
            ? context.colors.streak
            : theme.colorScheme.onSurfaceVariant;
        return Tooltip(
          message: context.s.streakTooltip(progress.streak),
          child: Pressable(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: color,
                    size: 26,
                  ),
                  Text(
                    context.s.n(progress.streak),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: color,
                      fontFamily: displayFont,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Ring showing today's XP against the daily goal.
class _GoalRing extends StatelessWidget {
  const _GoalRing({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.progress, scope.settings]),
      builder: (context, _) {
        final goal = scope.settings.dailyGoal;
        final xp = scope.progress.xpToday;
        final done = xp >= goal;
        return Tooltip(
          message: context.s.xpTooltip(xp, goal),
          child: Pressable(
            onTap: onTap,
            child: SizedBox(
              width: 38,
              height: 38,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: min(xp / goal, 1)),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: v,
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      color: done
                          ? context.colors.success
                          : theme.colorScheme.primary,
                    ),
                    done
                        ? Icon(
                            Icons.check_rounded,
                            size: 20,
                            color: context.colors.success,
                          )
                        : Text(
                            'XP',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
