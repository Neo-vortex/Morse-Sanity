import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../copy/voice.dart';
import '../course/course.dart';
import '../course/rewards.dart';
import '../course/session_config.dart';
import '../morse/morse_code.dart';
import '../theme/app_theme.dart';
import 'dit.dart';
import 'motion.dart';
import '../l10n/strings.dart';

/// Star rating row.
class Stars extends StatelessWidget {
  const Stars(this.count, {super.key, this.size = 16});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Icon(
            i < count ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: i < count
                ? context.colors.star
                : Theme.of(context).colorScheme.outlineVariant,
          ),
      ],
    );
  }
}

/// End-of-session celebration (or consolation) with stars, XP and mistakes.
class SessionResults extends StatefulWidget {
  const SessionResults({
    super.key,
    required this.config,
    required this.results,
    required this.onRetry,
    this.reward,
    this.message,
    this.onNext,
  });

  final SessionConfig config;
  final List<RoundResult> results;
  final VoidCallback onRetry;
  final VoidCallback? onNext;
  final SessionReward? reward;
  final String? message;

  @override
  State<SessionResults> createState() => _SessionResultsState();
}

class _SessionResultsState extends State<SessionResults> {
  int _confetti = 0;
  bool _celebrated = false;
  String? _headline;

  int get _correct => widget.results.where((r) => r.correct).length;
  double get _accuracy =>
      widget.results.isEmpty ? 0 : _correct / widget.results.length;
  int get _stars => starsFor(_accuracy);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _headline ??= Voice.results(context.s, _stars);
    if (!_celebrated) {
      _celebrated = true;
      final player = AppScope.of(context).player;
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        player.fanfare(_stars);
        if (_stars == 3) setState(() => _confetti++);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.colors;
    final player = AppScope.of(context).player;
    final mistakes = widget.results.where((r) => !r.correct).toList();
    final passed = _stars > 0;
    final reward = widget.reward;

    return MorseConfetti(
      trigger: _confetti,
      particles: 70,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          Center(
            child: Dit(
              size: 130,
              mood: _stars == 3
                  ? DitMood.celebrating
                  : passed
                  ? DitMood.happy
                  : DitMood.sad,
              lit: passed,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: EdgeInsets.only(
                    left: 4,
                    right: 4,
                    bottom: i == 1 ? 14 : 0,
                  ),
                  child: PopIn(
                    delay: Duration(milliseconds: 350 + i * 220),
                    from: 0,
                    child: Icon(
                      i < _stars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: i == 1 ? 68 : 54,
                      color: i < _stars ? colors.star : scheme.outlineVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _headline!,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.message!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              _StatTile(
                label: s.accuracy,
                color: passed ? colors.success : scheme.error,
                icon: Icons.track_changes_rounded,
                child: CountUp(
                  value: (_accuracy * 100).round(),
                  suffix: '%',
                  format: s.n,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              if (reward != null) ...[
                const SizedBox(width: 10),
                _StatTile(
                  label: s.xpEarned,
                  color: scheme.primary,
                  icon: Icons.bolt_rounded,
                  child: CountUp(
                    value: reward.xp,
                    prefix: '+',
                    format: s.n,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(width: 10),
                _StatTile(
                  label: reward.streakExtended ? s.streakPlusOne : s.streak,
                  color: colors.streak,
                  icon: Icons.local_fire_department_rounded,
                  child: Text(
                    s.n(reward.streak),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          if (widget.onNext != null && passed) ...[
            ChunkyButton(
              label: s.nextLevel,
              icon: Icons.arrow_forward_rounded,
              onPressed: widget.onNext,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: widget.onRetry,
              icon: const Icon(Icons.replay_rounded),
              label: Text(s.tryAgain),
            ),
          ] else ...[
            ChunkyButton(
              label: s.tryAgain,
              icon: Icons.replay_rounded,
              onPressed: widget.onRetry,
            ),
          ],
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(s.backToMap),
          ),
          if (mistakes.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(s.worthAnotherListen, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final m in mistakes)
              Card(
                child: ListTile(
                  onTap: () =>
                      player.playText(m.item, timing: widget.config.timing),
                  title: Text(m.item, style: theme.textTheme.titleLarge),
                  subtitle: Text(
                    '${widget.config.track == Track.nato ? '' : '${encode(m.item)}\n'}'
                    '${widget.config.track == Track.receive ? s.youTyped(m.answer.isEmpty ? '—' : m.answer) : s.youSent(m.answer.isEmpty ? '—' : m.answer)}',
                    style: const TextStyle(fontFamily: monoFont),
                  ),
                  isThreeLine: true,
                  trailing: Icon(
                    Icons.volume_up_rounded,
                    color: scheme.secondary,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.color,
    required this.icon,
    required this.child,
  });

  final String label;
  final Color color;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2.5),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
              child: Text(
                label.toUpperCase(),
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color:
                      ThemeData.estimateBrightnessForColor(color) ==
                          Brightness.dark
                      ? Colors.white
                      : const Color(0xFF1A2233),
                  letterSpacing: tracking(0.6),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 4),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
