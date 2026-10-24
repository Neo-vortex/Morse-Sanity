import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/words.dart';
import '../morse/morse_code.dart';
import '../services/progress.dart';
import '../widgets/morse_pattern.dart';
import 'quiz_screen.dart';
import 'word_copy_screen.dart';
import '../l10n/strings.dart';

/// Koch-method course: start with two characters, add one each time a
/// lesson is passed with 90% accuracy.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  static void startLesson(BuildContext context, {bool replace = false}) {
    final progress = AppScope.of(context).progress;
    // Snapshot the lesson so unlocking a character mid-route doesn't alter it.
    final s = context.s;
    final title = s.lesson(progress.level - 1);
    final characters = progress.unlocked;
    final focusChar = progress.newest;
    final route = MaterialPageRoute<void>(
      builder: (routeContext) => QuizScreen(
        title: title,
        characters: characters,
        focusChar: focusChar,
        rounds: 25,
        onFinished: (accuracy) {
          if (progress.completeLesson(accuracy)) {
            return progress.isComplete
                ? s.kochAllLearned
                : s.kochPassed(progress.newest);
          }
          if (progress.isComplete) return s.kochComplete;
          return s.kochReach((Progress.passMark * 100).round());
        },
        onRestart: () => startLesson(routeContext, replace: true),
      ),
    );
    final nav = Navigator.of(context);
    replace ? nav.pushReplacement(route) : nav.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final progress = scope.progress;
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) {
        final theme = Theme.of(context);
        final newest = progress.newest;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.s.charsOf(progress.level, Progress.maxLevel),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: context.s.courseOptions,
                  onSelected: (v) {
                    if (v == 'level') _chooseLevel(context);
                    if (v == 'reset') _confirmReset(context);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'level',
                      child: Text(context.s.jumpToLesson),
                    ),
                    PopupMenuItem(
                      value: 'reset',
                      child: Text(context.s.resetProgress),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress.level / Progress.maxLevel,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      progress.level == Progress.minLevel
                          ? context.s.firstCharacters
                          : context.s.newestCharacter,
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final c
                            in progress.level == Progress.minLevel
                                ? progress.unlocked
                                : [newest])
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _CharIntro(char: c),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.s.kochTip,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => startLesson(context),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(context.s.startLesson(progress.level - 1)),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WordCopyScreen(
                            title: context.s.copyGroups,
                            words: wordsFrom(progress.unlocked),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.keyboard),
                      label: Text(context.s.copyWordsGroups),
                    ),
                    if (progress.upcoming != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        context.s.upNext(progress.upcoming!),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(context.s.yourCharacters, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in progress.unlocked)
                  _AccuracyTile(char: c, stats: progress.statsFor(c)),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _chooseLevel(BuildContext context) async {
    final progress = AppScope.of(context).progress;
    var level = progress.level.toDouble();
    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.s.jumpToLessonTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.s.lessonChars(
                  level.round(),
                  kochOrder.substring(0, level.round()),
                ),
              ),
              Slider(
                value: level,
                min: Progress.minLevel.toDouble(),
                max: Progress.maxLevel.toDouble(),
                divisions: Progress.maxLevel - Progress.minLevel,
                label: context.s.n(level.round()),
                onChanged: (v) => setState(() => level = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.s.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, level.round()),
              child: Text(context.s.set),
            ),
          ],
        ),
      ),
    );
    if (result != null) progress.setLevel(result);
  }

  Future<void> _confirmReset(BuildContext context) async {
    final progress = AppScope.of(context).progress;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.s.resetProgressQuestion),
        content: Text(context.s.resetProgressBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.s.reset),
          ),
        ],
      ),
    );
    if (ok == true) progress.reset();
  }
}

class _CharIntro extends StatelessWidget {
  const _CharIntro({required this.char});

  final String char;

  @override
  Widget build(BuildContext context) {
    final player = AppScope.of(context).player;
    final pattern = encodeChar(char)!;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => player.playPattern(pattern),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Text(
              char,
              style: Theme.of(context).textTheme.displayMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            MorsePattern(pattern),
            const SizedBox(height: 8),
            const Icon(Icons.volume_up, size: 20),
          ],
        ),
      ),
    );
  }
}

class _AccuracyTile extends StatelessWidget {
  const _AccuracyTile({required this.char, required this.stats});

  final String char;
  final CharStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = AppScope.of(context).player;
    final color = stats.attempts == 0
        ? theme.colorScheme.surfaceContainerHighest
        : Color.lerp(
            Colors.red,
            Colors.green,
            stats.accuracy,
          )!.withValues(alpha: 0.35);
    return Tooltip(
      message: stats.attempts == 0
          ? context.s.notPractisedYet
          : '${stats.correct}/${stats.attempts} correct',
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => player.playText(char),
          child: SizedBox(
            width: 56,
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(char, style: theme.textTheme.titleLarge),
                Text(
                  stats.attempts == 0
                      ? '—'
                      : context.s.percent((stats.accuracy * 100).round()),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
