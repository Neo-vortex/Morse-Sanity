import 'dart:math';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../copy/voice.dart';
import '../course/course.dart';
import '../course/session_config.dart';
import '../data/nato.dart';
import '../morse/morse_code.dart';
import '../services/progress.dart';
import '../services/settings.dart';
import '../theme/app_theme.dart';
import '../widgets/dit.dart';
import '../widgets/morse_pattern.dart';
import '../widgets/motion.dart';
import '../widgets/on_the_air_card.dart';
import '../widgets/session_results.dart';
import 'receive_session_screen.dart';
import 'send_session_screen.dart';
import '../l10n/strings.dart';
import 'nato_session_screen.dart';

bool isLevelUnlocked(Level level, Progress progress, Settings settings) {
  if (settings.unlockAll || level.number == 1) return true;
  final prev = courseLevels[level.track]![level.number - 2];
  return progress.starsFor(prev.id) > 0;
}

/// Opens [level], replacing the current route when [replace] is set (for
/// "try again" and "next level" from a results page).
void openLevel(BuildContext context, Level level, {bool replace = false}) {
  final scope = AppScope.of(context);
  final levels = courseLevels[level.track]!;
  final next = level.number < levels.length ? levels[level.number] : null;

  String? onFinished(List<RoundResult> results) {
    final correct = results.where((r) => r.correct).length;
    final stars = starsFor(correct / results.length);
    final before = scope.progress.starsFor(level.id);
    scope.progress.recordLevel(level.id, stars);
    // The opening context (often a closed bottom sheet) may be gone by now.
    final s = S.of(scope.settings.language.locale);
    if (stars > 0 && before == 0 && next != null) {
      return s.levelUnlocked(next.number, next.title);
    }
    if (stars > before && before > 0) return s.newBest(stars);
    if (stars == 0 && level.isChallenge) return s.challengeRetry;
    return null;
  }

  Route<void> route(Level l) => MaterialPageRoute<void>(
    builder: (routeContext) {
      final config = SessionConfig.fromLevel(l);
      void retry() => openLevel(routeContext, l, replace: true);
      final onNext = next == null
          ? null
          : () => openLevel(routeContext, next, replace: true);
      if (l.track == Track.nato) {
        return NatoSessionScreen(
          level: l,
          onFinished: onFinished,
          onRetry: retry,
          onNext: onNext,
        );
      }
      return l.track == Track.receive
          ? ReceiveSessionScreen(
              config: config,
              onFinished: onFinished,
              onRetry: retry,
              onNext: onNext,
            )
          : SendSessionScreen(
              config: config,
              onFinished: onFinished,
              onRetry: retry,
              onNext: onNext,
            );
    },
  );

  final nav = Navigator.of(context);
  replace ? nav.pushReplacement(route(level)) : nav.push(route(level));
}

/// Visual identity for each course section.
({IconData icon, Color Function(ColorScheme, AppColors) color}) sectionStyle(
  String section,
) => switch (section) {
  'Letters' => (icon: Icons.abc, color: (s, c) => s.secondary),
  'Numbers' => (icon: Icons.pin_outlined, color: (s, c) => c.streak),
  'Punctuation' => (icon: Icons.more_horiz, color: (s, c) => s.tertiary),
  'Prosigns' => (icon: Icons.campaign_outlined, color: (s, c) => c.success),
  'Q-codes' => (icon: Icons.radio, color: (s, c) => s.secondary),
  'Abbreviations' => (icon: Icons.short_text, color: (s, c) => c.streak),
  'Words' => (icon: Icons.menu_book_outlined, color: (s, c) => s.tertiary),
  'Callsigns' => (icon: Icons.cell_tower, color: (s, c) => c.success),
  'Similar sounds' => (
    icon: Icons.compare_arrows,
    color: (s, c) => c.challenge,
  ),
  'Mixed review' => (icon: Icons.shuffle, color: (s, c) => c.streak),
  'Radio words' => (
    icon: Icons.settings_input_antenna,
    color: (s, c) => s.secondary,
  ),
  'QSO practice' => (icon: Icons.forum_outlined, color: (s, c) => c.success),
  'Alphabet A–I' => (
    icon: Icons.looks_one_outlined,
    color: (s, c) => s.secondary,
  ),
  'Alphabet J–R' => (icon: Icons.looks_two_outlined, color: (s, c) => c.streak),
  'Alphabet S–Z' => (icon: Icons.looks_3_outlined, color: (s, c) => s.tertiary),
  'Spelling' => (icon: Icons.spellcheck_rounded, color: (s, c) => c.success),
  'Decoding' => (
    icon: Icons.manage_search_rounded,
    color: (s, c) => c.challenge,
  ),
  _ => (icon: Icons.chat_bubble_outline, color: (s, c) => s.secondary),
};

/// The level map: a winding path per section, for receive and send.
class CourseScreen extends StatefulWidget {
  const CourseScreen({super.key});

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  Track _track = Track.receive;
  final _currentKey = GlobalKey();
  late String _nudge;
  bool _scrolled = false;
  int _currentLevelNumber = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    _nudge = Voice.homeNudge(
      context.s,
      streak: scope.progress.streak,
      goalMet: scope.progress.xpToday >= scope.settings.dailyGoal,
    );
    if (!_scrolled) {
      _scrolled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    }
  }

  void _scrollToCurrent() {
    final ctx = _currentKey.currentContext;
    // Near the top the map already shows the current level; keep Dit's
    // greeting in view.
    if (ctx == null || _currentLevelNumber <= 3) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.4,
      duration: context.reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.progress, scope.settings]),
      builder: (context, _) {
        final levels = courseLevels[_track]!;
        final current = levels.firstWhere(
          (l) =>
              scope.progress.starsFor(l.id) == 0 &&
              isLevelUnlocked(l, scope.progress, scope.settings),
          orElse: () => levels.last,
        );
        _currentLevelNumber = current.number;

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Dit(
                          size: 76,
                          mood: scope.progress.practisedToday
                              ? DitMood.happy
                              : DitMood.idle,
                          signal: scope.player.signal,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: SpeechBubble(
                            text:
                                '${Voice.greeting(context.s, scope.settings.operatorName, DateTime.now())}\n$_nudge',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SegmentedButton<Track>(
                      segments: [
                        ButtonSegment(
                          value: Track.receive,
                          label: Text(context.s.receive),
                          icon: const Icon(Icons.hearing),
                        ),
                        ButtonSegment(
                          value: Track.send,
                          label: Text(context.s.send),
                          icon: const Icon(Icons.touch_app),
                        ),
                        ButtonSegment(
                          value: Track.nato,
                          label: Text(context.s.nato),
                          icon: const Icon(Icons.record_voice_over_outlined),
                        ),
                      ],
                      selected: {_track},
                      onSelectionChanged: (s) {
                        setState(() => _track = s.first);
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _scrollToCurrent(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            for (final section in sectionsOf(_track)) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
                sliver: SliverToBoxAdapter(
                  child: _SectionBanner(
                    section: section,
                    levels: levels.where((l) => l.section == section).toList(),
                    progress: scope.progress,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _SectionPath(
                  levels: levels.where((l) => l.section == section).toList(),
                  current: current,
                  currentKey: _currentKey,
                ),
              ),
            ],
            // After the last section: invite them onto the air.
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
              sliver: SliverToBoxAdapter(
                child: OnTheAirCard(compactTitle: context.s.qsoInviteTitle),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        );
      },
    );
  }
}

class _SectionBanner extends StatelessWidget {
  const _SectionBanner({
    required this.section,
    required this.levels,
    required this.progress,
  });

  final String section;
  final List<Level> levels;
  final Progress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = sectionStyle(section);
    final color = style.color(theme.colorScheme, context.colors);
    final passed = levels.where((l) => progress.starsFor(l.id) > 0).length;
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : const Color(0xFF1A2233);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Color.lerp(color, Colors.black, 0.3)!,
            offset: const Offset(0, 4),
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
                  context.s.sectionName(section),
                  style: theme.textTheme.titleLarge?.copyWith(color: onColor),
                ),
                const SizedBox(height: 2),
                Text(
                  context.s.sectionBlurb(section),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: onColor.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: passed / levels.length,
                    minHeight: 6,
                    color: onColor,
                    backgroundColor: onColor.withValues(alpha: 0.25),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            children: [
              Icon(style.icon, color: onColor, size: 34),
              Text(
                context.s.n('$passed/${levels.length}'),
                style: theme.textTheme.labelLarge?.copyWith(color: onColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Levels laid out on a gentle S-curve joined by dot-dash trails.
class _SectionPath extends StatelessWidget {
  const _SectionPath({
    required this.levels,
    required this.current,
    required this.currentKey,
  });

  final List<Level> levels;
  final Level current;
  final GlobalKey currentKey;

  static const _rowHeight = 112.0;
  static const _node = 74.0;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final amplitude = min(width * 0.26, 110.0);
        final points = [
          for (var i = 0; i < levels.length; i++)
            Offset(
              width / 2 + sin(i * pi / 3) * amplitude,
              i * _rowHeight + _rowHeight / 2 + 8,
            ),
        ];
        final done = [
          for (final l in levels) scope.progress.starsFor(l.id) > 0,
        ];
        return SizedBox(
          height: levels.length * _rowHeight + 16,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _TrailPainter(
                    points: points,
                    done: done,
                    doneColor: scheme.secondary,
                    todoColor: scheme.outlineVariant,
                  ),
                ),
              ),
              for (var i = 0; i < levels.length; i++) ...[
                Positioned(
                  left: points[i].dx - _node / 2,
                  top: points[i].dy - _node / 2,
                  child: _LevelNode(
                    key: levels[i].id == current.id ? currentKey : null,
                    level: levels[i],
                    isCurrent: levels[i].id == current.id,
                  ),
                ),
                if (levels[i].id == current.id)
                  Positioned(
                    // Dit perches on the side the path is swinging away from.
                    left:
                        points[i].dx +
                        (sin(i * pi / 3) > 0 ? -_node - 64 : _node / 2 + 14),
                    top: points[i].dy - 52,
                    child: IgnorePointer(
                      child: Dit(
                        size: 58,
                        mood: DitMood.happy,
                        signal: scope.player.signal,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TrailPainter extends CustomPainter {
  _TrailPainter({
    required this.points,
    required this.done,
    required this.doneColor,
    required this.todoColor,
  });

  final List<Offset> points;
  final List<bool> done;
  final Color doneColor;
  final Color todoColor;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final mid = (a.dy + b.dy) / 2;
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx, mid, b.dx, mid, b.dx, b.dy);
      final paint = Paint()
        ..color = done[i] ? doneColor : todoColor
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round;
      // Walk the curve laying down a repeating · − pattern.
      for (final metric in path.computeMetrics()) {
        var d = 44.0; // skip the part hidden under the node
        var dash = false;
        while (d < metric.length - 44) {
          final len = dash ? 16.0 : 0.1;
          final p1 = metric.getTangentForOffset(d)!.position;
          final p2 = metric
              .getTangentForOffset(min(d + len, metric.length))!
              .position;
          canvas.drawLine(p1, p2, paint);
          d += len + 13;
          dash = !dash;
        }
      }
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) =>
      old.done != done ||
      old.points != points ||
      old.doneColor != doneColor ||
      old.todoColor != todoColor;
}

class _LevelNode extends StatelessWidget {
  const _LevelNode({super.key, required this.level, required this.isCurrent});

  final Level level;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.colors;
    final stars = scope.progress.starsFor(level.id);
    final unlocked = isLevelUnlocked(level, scope.progress, scope.settings);

    final Color face;
    final Color fg;
    final IconData? icon;
    if (!unlocked) {
      face = scheme.surfaceContainerHighest;
      fg = scheme.onSurfaceVariant.withValues(alpha: 0.6);
      icon = Icons.lock_rounded;
    } else if (level.isChallenge) {
      face = colors.challenge;
      fg = Colors.white;
      icon = Icons.emoji_events_rounded;
    } else if (stars == 3) {
      face = colors.star;
      fg = const Color(0xFF3D2A00);
      icon = null;
    } else if (stars > 0) {
      face = scheme.secondary;
      fg = scheme.onSecondary;
      icon = null;
    } else {
      face = scheme.primary;
      fg = scheme.onPrimary;
      icon = null;
    }
    final lip = Color.lerp(face, Colors.black, 0.25)!;

    Widget node = Container(
      width: _SectionPath._node,
      height: _SectionPath._node,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: face,
        boxShadow: [BoxShadow(color: lip, offset: const Offset(0, 6))],
      ),
      alignment: Alignment.center,
      child: icon != null
          ? Icon(icon, color: fg, size: 32)
          : Text(
              level.title.length <= 5 ? level.title : context.s.n(level.number),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                color: fg,
                fontSize: level.title.length <= 2 ? 26 : 18,
              ),
            ),
    );
    if (isCurrent) node = Pulse(color: face, child: node);

    return SizedBox(
      width: _SectionPath._node,
      height: _SectionPath._node,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Pressable(
            onTap: () {
              if (unlocked) {
                _showPreview(context);
              } else {
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    SnackBar(content: Text(Voice.locked(context.s))),
                  );
              }
            },
            child: node,
          ),
          if (stars > 0 || isCurrent)
            Positioned(
              bottom: -26,
              child: stars > 0
                  ? Stars(stars, size: 18)
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.inverseSurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        context.s.startBadge,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onInverseSurface,
                          letterSpacing: tracking(1),
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  void _showPreview(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _LevelPreview(level: level),
    );
  }
}

/// Bottom sheet describing a level before you start it.
class _LevelPreview extends StatelessWidget {
  const _LevelPreview({required this.level});

  final Level level;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = context.s;
    final stars = scope.progress.starsFor(level.id);
    final style = sectionStyle(level.section);
    final preview = level.newItems.isNotEmpty
        ? level.newItems
        : level.pool.take(6).toList();
    final isChars = !level.isTyped;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  level.isChallenge ? Icons.emoji_events_rounded : style.icon,
                  color: level.isChallenge
                      ? context.colors.challenge
                      : style.color(scheme, context.colors),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.levelHeader(level.track, level.number),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      letterSpacing: tracking(1),
                    ),
                  ),
                ),
                Stars(stars, size: 22),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              s.levelHeading(level.section, level.title),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              level.isChallenge
                  ? s.previewChallenge(level.rounds)
                  : level.newItems.isNotEmpty && isChars
                  ? s.previewNew(level.rounds)
                  : s.previewRounds(level.rounds, level.section),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (isChars && preview.isNotEmpty && !level.isChallenge) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final item in preview)
                    Pressable(
                      onTap: level.track == Track.nato
                          ? null
                          : () => scope.player.playText(item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text(
                              item.replaceAll(RegExp('[<>]'), ''),
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 6),
                            if (level.track == Track.nato)
                              Text(
                                natoBySymbol[item]?.word ?? '',
                                style: const TextStyle(fontFamily: monoFont),
                              )
                            else
                              MorsePattern(encodeToken(item) ?? '', size: 8),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            ChunkyButton(
              label: stars > 0 ? s.practiseAgain : s.start,
              icon: Icons.play_arrow_rounded,
              color: level.isChallenge ? context.colors.challenge : null,
              foreground: level.isChallenge ? Colors.white : null,
              onPressed: () {
                Navigator.of(context).pop();
                openLevel(context, level);
              },
            ),
          ],
        ),
      ),
    );
  }
}
