import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morse_sanity/data/words.dart';
import 'package:morse_sanity/morse/key_decoder.dart';
import 'package:morse_sanity/morse/morse_code.dart';
import 'package:morse_sanity/morse/timing.dart';
import 'package:morse_sanity/morse/tone_generator.dart';

void main() {
  group('morse_code', () {
    test('encodes text with letter and word separators', () {
      expect(encode('sos'), '... --- ...');
      expect(encode('Hi there'), '.... .. / - .... . .-. .');
      expect(encode('  a   b  '), '.- / -...');
    });

    test('skips unknown characters', () {
      expect(encode('A#B'), '.- -...');
      expect(encode('###'), '');
    });

    test('decodes Morse, tolerating alternate glyphs', () {
      expect(decode('... --- ...'), 'SOS');
      expect(decode('.... .. / - .... . .-. .'), 'HI THERE');
      expect(decode('.-   -...'), 'A B');
      expect(decode('·− −···'), 'AB');
      expect(decode('......'), '�');
      expect(decode(''), '');
    });

    test('round-trips every character', () {
      for (final c in morseTable.keys) {
        expect(decode(encode(c)), c, reason: 'character $c');
      }
    });

    test('patterns are unique', () {
      expect(morseTable.values.toSet().length, morseTable.length);
    });

    test('Koch order covers letters and digits exactly once', () {
      expect(kochOrder.split('').toSet().length, kochOrder.length);
      for (final c in (letters + digits).split('')) {
        expect(kochOrder, contains(c));
      }
      for (final c in kochOrder.split('')) {
        expect(encodeChar(c), isNotNull, reason: c);
      }
    });
  });

  group('MorseTiming', () {
    test('PARIS is 50 units at standard spacing', () {
      const t = MorseTiming(charWpm: 20);
      expect(t.unitMs, 60);
      final elements = t.elementsForText('PARIS');
      final total = elements.fold<double>(0, (s, e) => s + e.durationMs);
      // 43 units for the word itself plus the 7-unit word gap that would
      // follow it in running text.
      expect(total + t.wordGapMs, closeTo(50 * t.unitMs, 0.001));
    });

    test('Farnsworth stretches only the gaps', () {
      const std = MorseTiming(charWpm: 20);
      const slow = MorseTiming(charWpm: 20, effectiveWpm: 10);
      expect(slow.dotMs, std.dotMs);
      expect(slow.dashMs, std.dashMs);
      expect(slow.charGapMs, greaterThan(std.charGapMs));
      expect(slow.wordGapMs, greaterThan(std.wordGapMs));

      // At 10 WPM effective, one PARIS (incl. word gap) takes 6 seconds.
      final elements = slow.elementsForText('PARIS');
      final total =
          elements.fold<double>(0, (s, e) => s + e.durationMs) + slow.wordGapMs;
      expect(total, closeTo(6000, 1));
    });

    test('effective speed is capped at character speed', () {
      const t = MorseTiming(charWpm: 15, effectiveWpm: 30);
      expect(t.effectiveWpm, 15);
    });

    test('pattern elements alternate on and off', () {
      const t = MorseTiming(charWpm: 20);
      final e = t.elementsForPattern('-.');
      expect(e.map((x) => x.on), [true, false, true]);
      expect(e.map((x) => x.durationMs), [180, 60, 60]);
    });
  });

  group('ToneGenerator', () {
    test('produces a valid WAV of the right length', () {
      const gen = ToneGenerator(sampleRate: 8000);
      final wav = gen.render(const [
        MorseElement(on: true, durationMs: 100),
        MorseElement(on: false, durationMs: 100),
      ], leadInMs: 0);
      final bd = ByteData.sublistView(wav);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(bd.getUint32(24, Endian.little), 8000);
      expect(bd.getUint32(40, Endian.little), 1600 * 2);
      expect(wav.length, 44 + 1600 * 2);

      final samples = Int16List.sublistView(wav, 44);
      final toneEnergy = samples.sublist(0, 800).any((s) => s.abs() > 1000);
      final silence = samples.sublist(800).every((s) => s == 0);
      expect(toneEnergy, isTrue);
      expect(silence, isTrue);
    });
  });

  group('KeyDecoder', () {
    test('classifies dots and dashes and decodes letters', () {
      final d = KeyDecoder(dotMs: 60);
      expect(d.addPress(55), '.');
      expect(d.addPress(190), '-');
      expect(d.pendingPattern, '.-');
      expect(d.commitLetter(), (pattern: '.-', char: 'A'));
      expect(d.commitLetter(), isNull);
    });

    test('adapts to a slower operator', () {
      final d = KeyDecoder(dotMs: 60);
      for (var i = 0; i < 20; i++) {
        d.addPress(150); // slow dots look like dashes at first
        d.addPress(450);
      }
      expect(d.dotMs, closeTo(150, 25));
      d.commitLetter();
      expect(d.addPress(150), '.');
      expect(d.addPress(450), '-');
    });

    test('gap thresholds scale with dot length', () {
      final d = KeyDecoder(dotMs: 100);
      expect(d.isLetterGap(100), isFalse);
      expect(d.isLetterGap(300), isTrue);
      expect(d.isWordGap(300), isFalse);
      expect(d.isWordGap(700), isTrue);
    });
  });

  group('wordsFrom', () {
    test('only returns words using the given characters', () {
      final words = wordsFrom('THEAND'.split(''));
      for (final w in words) {
        expect(w.split('').every('THEAND'.contains), isTrue, reason: w);
      }
    });

    test('falls back to five-character groups for tiny sets', () {
      final words = wordsFrom(['K', 'M']);
      expect(words, isNotEmpty);
      expect(words.every((w) => RegExp(r'^[KM]{5}$').hasMatch(w)), isTrue);
    });
  });
}
