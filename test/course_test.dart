import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:morse_sanity/course/course.dart';
import 'package:morse_sanity/course/session_config.dart';
import 'package:morse_sanity/data/words.dart';
import 'package:morse_sanity/morse/morse_code.dart';

void main() {
  test('both tracks have the same well-formed levels', () {
    final receive = courseLevels[Track.receive]!;
    final send = courseLevels[Track.send]!;
    expect(receive.length, send.length);
    expect(receive.length, greaterThan(90));
    expect(receive.map((l) => l.id).toSet().length, receive.length);
    for (var i = 0; i < receive.length; i++) {
      expect(receive[i].number, i + 1);
      expect(receive[i].title, send[i].title);
    }
  });

  test('every level produces encodable items', () {
    final r = Random(1);
    for (final level in courseLevels[Track.receive]!) {
      for (var i = 0; i < 20; i++) {
        final item = level.nextItem(r);
        expect(encode(item), isNotEmpty, reason: '${level.title}: $item');
      }
    }
  });

  test('letters come first, starting with E and T', () {
    final first = courseLevels[Track.receive]!.first;
    expect(first.section, 'Letters');
    expect(first.newItems, ['E', 'T']);
    expect(first.isTyped, isFalse);
    expect(first.timeLimit, isNull);
  });

  test('sections end with a timed challenge without hints', () {
    final levels = courseLevels[Track.receive]!;
    for (final section in sectionsOf(Track.receive)) {
      final last = levels.lastWhere((l) => l.section == section);
      expect(last.isChallenge, isTrue, reason: section);
      expect(last.timeLimit, isNotNull);
      expect(SessionConfig.fromLevel(last).hintsAllowed, isFalse);
    }
  });

  test('character sections use the keyboard, word sections are typed', () {
    const characters = {
      'Letters',
      'Similar sounds',
      'Punctuation',
      'Prosigns',
      'Mixed review',
    };
    const typed = {
      'Q-codes',
      'Abbreviations',
      'Words',
      'Radio words',
      'Callsigns',
      'Sentences',
      'QSO practice',
    };
    for (final l in courseLevels[Track.receive]!) {
      if (characters.contains(l.section)) {
        expect(l.isTyped, isFalse, reason: '${l.section} ${l.title}');
      } else if (typed.contains(l.section)) {
        expect(l.isTyped, isTrue, reason: '${l.section} ${l.title}');
      }
    }
    final numberGroups = courseLevels[Track.receive]!.where(
      (l) => l.title.startsWith('Number groups'),
    );
    expect(numberGroups.every((l) => l.isTyped), isTrue);
  });

  test('the course is bigger than the competition', () {
    // Morse Mania lists 270 levels and 52 challenges in total.
    final all = [for (final t in Track.values) ...courseLevels[t]!];
    expect(all.length, greaterThan(270));
    expect(all.where((l) => l.isChallenge).length, greaterThanOrEqualTo(52));
  });

  test('the word pool is large and Morse-friendly', () {
    expect(allWords.length, greaterThan(1500));
    expect(allWords.toSet().length, allWords.length);
    for (final w in allWords) {
      expect(RegExp(r'^[A-Z]+$').hasMatch(w), isTrue, reason: w);
    }
  });

  test('stars thresholds', () {
    expect(starsFor(0.69), 0);
    expect(starsFor(0.7), 1);
    expect(starsFor(0.8), 2);
    expect(starsFor(0.9), 3);
  });

  test('prosigns tokenize and encode as one character', () {
    expect(tokenize('CQ<AR>'), ['C', 'Q', '<AR>']);
    expect(encode('<SK>'), '...-.-');
    expect(encode('TU <SK>'), '- ..- / ...-.-');
  });
}
