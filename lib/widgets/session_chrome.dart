import 'package:flutter/material.dart';

import '../morse/morse_code.dart';
import '../theme/app_theme.dart';
import 'morse_pattern.dart';
import 'motion.dart';
import '../l10n/strings.dart';

/// Close button, chunky progress bar and combo flame for a session.
class SessionTopBar extends StatelessWidget {
  const SessionTopBar({
    super.key,
    required this.progress,
    this.combo = 0,
    this.timeLeft,
    this.title,
  });

  final double progress;
  final int combo;
  final double? timeLeft;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: context.s.quit,
                icon: const Icon(Icons.close_rounded, size: 28),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: progress),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutBack,
                  builder: (context, v, _) => Container(
                    height: 18,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: v.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: combo >= 5 ? colors.streak : scheme.primary,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        // Glossy highlight stripe.
                        alignment: Alignment.topCenter,
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (c, a) =>
                    ScaleTransition(scale: a, child: c),
                child: combo >= 2
                    ? Padding(
                        key: ValueKey(combo),
                        padding: const EdgeInsets.only(left: 10),
                        child: Row(
                          children: [
                            Icon(
                              Icons.local_fire_department_rounded,
                              color: colors.streak,
                            ),
                            Text(
                              context.s.n(combo),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colors.streak,
                                fontFamily: displayFont,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(width: 10),
              ),
            ],
          ),
          if (timeLeft != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 6, 0, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 18,
                    color: timeLeft! < 0.3
                        ? scheme.error
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: timeLeft,
                        minHeight: 6,
                        color: timeLeft! < 0.3 ? scheme.error : scheme.tertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                title!,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Circular action button with a soft lip.
class RoundAction extends StatelessWidget {
  const RoundAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.big = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = big ? 68.0 : 56.0;
    final face = big ? scheme.secondary : scheme.surfaceContainerLowest;
    final fg = big ? scheme.onSecondary : scheme.onSurface;
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: face,
              shape: BoxShape.circle,
              border: big
                  ? null
                  : Border.all(color: scheme.outlineVariant, width: 2),
              boxShadow: [
                BoxShadow(
                  color: big
                      ? Color.lerp(face, Colors.black, 0.3)!
                      : scheme.outlineVariant,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: fg, size: big ? 34 : 26),
          ),
        ),
      ),
    );
  }
}

/// Field showing what the user has typed on the on-screen keyboard.
class AnswerField extends StatelessWidget {
  const AnswerField({super.key, required this.text, required this.placeholder});

  final String text;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant, width: 2),
      ),
      child: Text(
        text.isEmpty ? placeholder : text,
        // Answers are Latin text; keep them left-to-right.
        textDirection: text.isEmpty ? null : TextDirection.ltr,
        style: text.isEmpty
            ? theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              )
            : theme.textTheme.headlineSmall?.copyWith(letterSpacing: 2),
      ),
    );
  }
}

/// Bottom panel revealing the answer after a round.
class FeedbackPanel extends StatelessWidget {
  const FeedbackPanel({
    super.key,
    required this.correct,
    required this.title,
    required this.answer,
    required this.onContinue,
    this.detail,
  });

  final bool correct;
  final String title;
  final String answer;
  final String? detail;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.colors;
    final bg = correct ? colors.successContainer : scheme.errorContainer;
    final fg = correct ? colors.success : scheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: fg,
                size: 30,
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(color: fg),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.s.answerIs(answer),
            style: theme.textTheme.titleMedium?.copyWith(color: fg),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final word in patternsFor(answer))
                Wrap(
                  spacing: 6,
                  children: [
                    for (final p in word) MorsePattern(p, size: 8, color: fg),
                  ],
                ),
            ],
          ),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(
              detail!,
              style: theme.textTheme.bodyMedium?.copyWith(color: fg),
            ),
          ],
          const SizedBox(height: 14),
          ChunkyButton(
            label: context.s.continueLabel,
            onPressed: onContinue,
            color: fg,
            foreground: correct ? colors.onSuccess : scheme.onError,
          ),
        ],
      ),
    );
  }
}
