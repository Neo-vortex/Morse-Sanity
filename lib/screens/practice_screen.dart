import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/words.dart';
import '../morse/morse_code.dart';
import '../theme/app_theme.dart';
import '../widgets/dit.dart';
import '../widgets/motion.dart';
import 'custom_challenge_screen.dart';
import 'learn_screen.dart';
import 'quiz_screen.dart';
import 'send_session_screen.dart';
import 'word_copy_screen.dart';
import '../l10n/strings.dart';

enum CharSet {
  learned,
  letters,
  digits,
  all;

  String label(S s) => switch (this) {
    learned => s.charSetKoch,
    letters => s.charSetLetters,
    digits => s.charSetNumbers,
    all => s.charSetAll,
  };
}

/// Free practice drills outside the level course.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  CharSet _set = CharSet.letters;

  List<String> _characters() {
    switch (_set) {
      case CharSet.learned:
        return AppScope.of(context).progress.unlocked;
      case CharSet.letters:
        return letters.split('');
      case CharSet.digits:
        return digits.split('');
      case CharSet.all:
        return (letters + digits + punctuation).split('');
    }
  }

  void _open(Widget screen) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.colors;
    final s = context.s;
    final setLabel = _set.label(s);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Pressable(
          scale: 0.97,
          onTap: () => _open(const CustomChallengeScreen()),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
            decoration: BoxDecoration(
              color: scheme.secondary,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Color.lerp(scheme.secondary, Colors.black, 0.3)!,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.customChallenge,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: scheme.onSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.customChallengeBlurb,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSecondary.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const Dit(size: 72, mood: DitMood.happy, lit: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DrillTile(
                icon: Icons.school_rounded,
                color: colors.challenge,
                title: s.kochMethod,
                subtitle: s.kochSub,
                onTap: () => _open(
                  Scaffold(
                    appBar: AppBar(title: Text(s.kochMethod)),
                    body: const LearnScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DrillTile(
                icon: Icons.edit_rounded,
                color: colors.streak,
                title: s.freeKeying,
                subtitle: s.freeKeyingSub,
                onTap: () => _open(const SendSessionScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(s.quickDrills, style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final c in CharSet.values)
              ChoiceChip(
                label: Text(c.label(s)),
                selected: _set == c,
                onSelected: (_) => setState(() => _set = c),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _DrillCard(
          icon: Icons.hearing_rounded,
          color: scheme.secondary,
          title: s.listenIdentify,
          subtitle: s.listenIdentifySub,
          onTap: () => _open(
            QuizScreen(
              title: s.drillTitle(s.listenIdentify, setLabel),
              characters: _characters(),
            ),
          ),
        ),
        _DrillCard(
          icon: Icons.visibility_rounded,
          color: colors.challenge,
          title: s.readCode,
          subtitle: s.readCodeSub,
          onTap: () => _open(
            QuizScreen(
              title: s.drillTitle(s.readCode, setLabel),
              characters: _characters(),
              prompt: QuizPrompt.visual,
            ),
          ),
        ),
        _DrillCard(
          icon: Icons.keyboard_rounded,
          color: colors.success,
          title: s.copyWords,
          subtitle: s.copyWordsSub,
          onTap: () => _open(
            WordCopyScreen(
              title: s.drillTitle(s.copyWords, setLabel),
              words: _set == CharSet.all
                  ? practiceWords
                  : wordsFrom(_characters()),
            ),
          ),
        ),
      ],
    );
  }
}

/// Square-ish tile with a big coloured icon.
class _DrillTile extends StatelessWidget {
  const _DrillTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: scheme.outlineVariant, width: 1.5),
          boxShadow: [
            BoxShadow(color: scheme.outlineVariant, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconBlob(icon: icon, color: color),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBlob extends StatelessWidget {
  const _IconBlob({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }
}

class _DrillCard extends StatelessWidget {
  const _DrillCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Pressable(
        onTap: onTap,
        scale: 0.97,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: scheme.outlineVariant, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: scheme.outlineVariant,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              _IconBlob(icon: icon, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
