import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:morse_sanity/course/course.dart';
import 'package:morse_sanity/data/nato.dart';

void main() {
  test('covers A–Z and 0–9 exactly once', () {
    expect(
      natoLetters.map((e) => e.symbol).join(),
      'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
    );
    expect(natoDigits.map((e) => e.symbol).join(), '0123456789');
    final words = [...natoLetters, ...natoDigits].map((e) => e.word);
    expect(words.toSet().length, 36);
  });

  test('accepts common alternate spellings', () {
    expect(natoMatches('A', 'alfa'), isTrue);
    expect(natoMatches('A', 'ALPHA'), isTrue);
    expect(natoMatches('J', 'JULIET'), isTrue);
    expect(natoMatches('X', 'X-RAY'), isTrue);
    expect(natoMatches('9', 'NINER'), isTrue);
    expect(natoMatches('B', 'BETA'), isFalse);
  });

  test('spells and reads back', () {
    expect(natoSpell('K2abc'), 'KILO TWO ALFA BRAVO CHARLIE');
    expect(natoRead('kilo two alpha bravo charlie'), 'K2ABC');
    expect(natoRead('KILO BANANA'), isNull);
  });

  test('the NATO track is a full course', () {
    final levels = courseLevels[Track.nato]!;
    expect(levels.length, greaterThanOrEqualTo(25));
    expect(levels.where((l) => l.isChallenge).length, greaterThanOrEqualTo(6));
    expect(levels.every((l) => l.natoMode != null), isTrue);
    // Every letter and digit is introduced somewhere.
    final introduced = {for (final l in levels) ...l.newItems};
    expect(introduced.length, 36);
  });

  test('every NATO level produces something spellable', () {
    final r = Random(5);
    for (final level in courseLevels[Track.nato]!) {
      for (var i = 0; i < 10; i++) {
        final item = level.nextItem(r);
        expect(natoSpell(item), isNotEmpty, reason: '${level.title}: $item');
        expect(natoRead(natoSpell(item)), item.toUpperCase());
      }
    }
  });
}
