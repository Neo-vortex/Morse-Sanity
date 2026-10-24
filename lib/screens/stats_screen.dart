import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../course/course.dart';
import '../morse/morse_code.dart';
import '../services/progress.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';

/// Course progress and per-character accuracy.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool _send = false;

  @override
  Widget build(BuildContext context) {
    final progress = AppScope.of(context).progress;
    final s = context.s;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.statistics),
        actions: [
          IconButton(
            tooltip: s.resetAllProgress,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmReset(progress),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: progress,
        builder: (context, _) {
          final theme = Theme.of(context);
          final chars = [
            ...letters.split(''),
            ...digits.split(''),
            ...punctuation.split(''),
            for (final p in prosigns.keys) '<$p>',
          ];
          final practised = chars
              .map((c) => progress.statsFor(c, send: _send))
              .where((s) => s.attempts > 0)
              .toList();
          final attempts = practised.fold<int>(0, (a, s) => a + s.attempts);
          final correct = practised.fold<int>(0, (a, s) => a + s.correct);
          final weakest =
              chars
                  .where((c) => progress.statsFor(c, send: _send).attempts >= 3)
                  .toList()
                ..sort(
                  (a, b) => progress
                      .statsFor(a, send: _send)
                      .accuracy
                      .compareTo(progress.statsFor(b, send: _send).accuracy),
                );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  _Highlight(
                    icon: Icons.bolt_rounded,
                    color: theme.colorScheme.primary,
                    label: s.totalXp,
                    value: s.n(progress.totalXp),
                  ),
                  const SizedBox(width: 12),
                  _Highlight(
                    icon: Icons.local_fire_department_rounded,
                    color: context.colors.streak,
                    label: s.bestStreak,
                    value: s.days(progress.bestStreak),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final track in Track.values)
                _TrackCard(track: track, progress: progress),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.characterAccuracy,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: false, label: Text(s.receive)),
                      ButtonSegment(value: true, label: Text(s.send)),
                    ],
                    selected: {_send},
                    onSelectionChanged: (s) => setState(() => _send = s.first),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                attempts == 0
                    ? s.noCharsYet
                    : s.answersSummary(
                        attempts,
                        (correct / attempts * 100).round(),
                      ),
                style: theme.textTheme.bodyMedium,
              ),
              if (weakest.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  s.needsWork(
                    weakest
                        .take(5)
                        .map((c) => c.replaceAll(RegExp('[<>]'), ''))
                        .join('  '),
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in chars)
                    _AccuracyCell(
                      char: c,
                      stats: progress.statsFor(c, send: _send),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmReset(Progress progress) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.s.resetAllQuestion),
        content: Text(context.s.resetAllBody),
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

class _TrackCard extends StatelessWidget {
  const _TrackCard({required this.track, required this.progress});

  final Track track;
  final Progress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final levels = courseLevels[track]!;
    final passed = levels.where((l) => progress.starsFor(l.id) > 0).length;
    final perfect = levels.where((l) => progress.starsFor(l.id) == 3).length;
    final stars = levels.fold<int>(0, (s, l) => s + progress.starsFor(l.id));
    final challenges = levels.where((l) => l.isChallenge).toList();
    final challengesPassed = challenges
        .where((l) => progress.starsFor(l.id) > 0)
        .length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.s.trackCourse(track),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: passed / levels.length,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              context.s.trackSummary(
                passed,
                levels.length,
                perfect,
                challengesPassed,
                challenges.length,
                stars,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccuracyCell extends StatelessWidget {
  const _AccuracyCell({required this.char, required this.stats});

  final String char;
  final CharStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = char.replaceAll(RegExp('[<>]'), '');
    final color = stats.attempts == 0
        ? theme.colorScheme.surfaceContainerHighest
        : Color.lerp(
            Colors.red,
            Colors.green,
            stats.accuracy,
          )!.withValues(alpha: 0.4);
    return Tooltip(
      message: stats.attempts == 0
          ? context.s.notPractised
          : context.s.correctOf(stats.correct, stats.attempts),
      child: Container(
        width: 48,
        height: 52,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              child: Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  decoration: char.startsWith('<')
                      ? TextDecoration.overline
                      : null,
                ),
              ),
            ),
            Text(
              stats.attempts == 0
                  ? '—'
                  : context.s.percent((stats.accuracy * 100).round()),
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: theme.textTheme.titleLarge),
                  Text(label, style: theme.textTheme.labelMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
