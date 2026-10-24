import 'dart:math';

import '../morse/morse_code.dart';
import '../morse/timing.dart';
import 'course.dart';

/// Everything a receive or send session needs to run, whether it comes
/// from a course level or a custom challenge.
class SessionConfig {
  SessionConfig({
    required this.title,
    required this.track,
    required this.nextItem,
    required this.rounds,
    required this.typed,
    this.characters = const {},
    this.timeLimit,
    this.hintsAllowed = true,
    this.timing,
    this.level,
  });

  factory SessionConfig.fromLevel(Level level) => SessionConfig(
    title: '${level.section} · ${level.title}',
    track: level.track,
    nextItem: level.nextItem,
    rounds: level.rounds,
    typed: level.isTyped,
    characters: {
      for (final item in level.pool) ...tokenize(item),
      if (level.generator != null) ...'$letters$digits/'.split(''),
    },
    timeLimit: level.timeLimit,
    hintsAllowed: !level.isChallenge,
    level: level,
  );

  final String title;
  final Track track;
  final String Function(Random r) nextItem;
  final int rounds;

  /// Answers are typed words rather than one key per item.
  final bool typed;

  /// Characters/prosigns that can appear; highlighted on the keyboard.
  final Set<String> characters;
  final Duration? timeLimit;
  final bool hintsAllowed;

  /// Overrides the speed from settings.
  final MorseTiming? timing;

  /// The course level this session plays, if any.
  final Level? level;

  bool get needsDigits => characters.any(digits.contains);
  bool get needsSymbols => characters.any(punctuation.contains);
  bool get needsProsigns => characters.any((c) => c.startsWith('<'));
}

/// Outcome of one round, for the results page.
class RoundResult {
  RoundResult({
    required this.item,
    required this.answer,
    required this.correct,
  });

  final String item;
  final String answer;
  final bool correct;
}
