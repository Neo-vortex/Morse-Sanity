import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/dit.dart';
import '../widgets/motion.dart';
import 'home_screen.dart';
import '../l10n/strings.dart';
import '../widgets/language_picker.dart';

/// Daily XP goals offered during onboarding and in settings.
const dailyGoals = [10, 30, 60, 120];

/// First-run welcome: Dit introduces itself, asks your name and a goal.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  final _name = TextEditingController();
  int _page = 0;
  int _goal = 30;
  int _confetti = 0;

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    super.dispose();
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (_page < 2) {
      _pages.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    final settings = AppScope.of(context).settings;
    settings.operatorName = _name.text;
    settings.dailyGoal = _goal;
    settings.onboarded = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = AppScope.of(context).player;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  _IntroPage(
                    onSayHi: () {
                      player.playText('HI');
                      setState(() => _confetti++);
                    },
                    confetti: _confetti,
                  ),
                  _NamePage(controller: _name, onDone: _next),
                  _GoalPage(
                    selected: _goal,
                    onSelect: (g) => setState(() => _goal = g),
                  ),
                ],
              ),
            ),
            _MorseDots(count: 3, current: _page),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: ChunkyButton(
                label: _page == 2 ? context.s.letsGo : context.s.continueLabel,
                icon: _page == 2 ? Icons.bolt : null,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page indicator drawn as Morse: the current page is a dah.
class _MorseDots extends StatelessWidget {
  const _MorseDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == current ? 30 : 10,
            height: 10,
            decoration: BoxDecoration(
              color: i == current ? scheme.primary : scheme.outlineVariant,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
      ],
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({required this.onSayHi, required this.confetti});

  final VoidCallback onSayHi;
  final int confetti;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = AppScope.of(context).player;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Language first, so everything after is in the right one.
          const Align(
            alignment: AlignmentDirectional.centerEnd,
            child: LanguagePicker(),
          ),
          const SizedBox(height: 8),
          MorseConfetti(
            trigger: confetti,
            child: Pressable(
              onTap: onSayHi,
              child: PopIn(
                child: Dit(
                  size: 170,
                  mood: confetti > 0 ? DitMood.happy : DitMood.idle,
                  signal: player.signal,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(context.s.hiImDit, style: theme.textTheme.displaySmall),
          const SizedBox(height: 12),
          Text(
            context.s.introBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: onSayHi,
            icon: const Icon(Icons.waving_hand),
            label: Text(context.s.tapToSayHi),
          ),
        ],
      ),
    );
  }
}

class _NamePage extends StatelessWidget {
  const _NamePage({required this.controller, required this.onDone});

  final TextEditingController controller;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Row(
            children: [
              const Dit(size: 84, mood: DitMood.thinking),
              const SizedBox(width: 8),
              Expanded(child: SpeechBubble(text: context.s.nameBubble)),
            ],
          ),
          const SizedBox(height: 32),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onDone(),
            style: theme.textTheme.headlineSmall,
            decoration: InputDecoration(
              hintText: context.s.namePlaceholder,
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerLowest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.s.nameSkip,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalPage extends StatelessWidget {
  const _GoalPage({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Row(
            children: [
              const Dit(size: 84, mood: DitMood.happy),
              const SizedBox(width: 8),
              Expanded(child: SpeechBubble(text: context.s.goalBubble)),
            ],
          ),
          const SizedBox(height: 24),
          for (final g in dailyGoals)
            GoalTile(
              name: context.s.goalName(g),
              blurb: context.s.goalBlurb(g),
              xp: g,
              selected: selected == g,
              onTap: () => onSelect(g),
            ),
        ],
      ),
    );
  }
}

/// Selectable daily-goal card.
class GoalTile extends StatelessWidget {
  const GoalTile({
    super.key,
    required this.name,
    required this.blurb,
    required this.xp,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String blurb;
  final int xp;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Pressable(
        onTap: onTap,
        scale: 0.97,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primaryContainer
                : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2.5 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleMedium),
                    Text(
                      blurb,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                context.s.xp(xp),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: displayFont,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
