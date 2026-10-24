import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morse_sanity/morse/keyer.dart';

/// Drives a keyer under fake time and records what it produced.
class _Harness {
  _Harness(this.async, KeyType type, {double unitMs = 60}) {
    keyer = Keyer(
      type: type,
      unitMs: unitMs,
      onTone: (on) => tone.add(on),
      onLetter: letters.add,
      onWordGap: () => wordGaps++,
    );
  }

  final FakeAsync async;
  late final Keyer keyer;
  final tone = <bool>[];
  final letters = <String>[];
  int wordGaps = 0;

  void hold(Contact c, int ms) {
    keyer.press(c);
    async.elapse(Duration(milliseconds: ms));
    keyer.release(c);
  }

  void wait(int ms) => async.elapse(Duration(milliseconds: ms));
}

void main() {
  test('straight key classifies presses and commits on a gap', () {
    fakeAsync((async) {
      final h = _Harness(async, KeyType.straight);
      h.hold(Contact.left, 60);
      h.wait(60);
      h.hold(Contact.left, 180);
      h.wait(400);
      expect(h.letters, ['.-']);
      expect(h.tone, [true, false, true, false]);
      h.wait(400);
      expect(h.wordGaps, 1);
    });
  });

  test('dit/dah buttons queue taps', () {
    fakeAsync((async) {
      final h = _Harness(async, KeyType.tapButtons);
      h.hold(Contact.right, 10);
      h.hold(Contact.left, 10);
      h.hold(Contact.right, 10);
      h.wait(1500);
      expect(h.letters, ['-.-']);
    });
  });

  test('sideswiper times both contacts manually', () {
    fakeAsync((async) {
      final h = _Harness(async, KeyType.sideswiper);
      h.hold(Contact.left, 180);
      h.wait(60);
      h.hold(Contact.right, 60);
      h.wait(60);
      h.hold(Contact.left, 60);
      h.wait(400);
      expect(h.letters, ['-..']);
    });
  });

  test('bug repeats dits on the left, manual dah on the right', () {
    fakeAsync((async) {
      final h = _Harness(async, KeyType.bug);
      // Held for exactly three dit+gap cycles.
      h.hold(Contact.left, 330);
      h.wait(130);
      h.hold(Contact.right, 100);
      h.wait(400);
      expect(h.letters, ['...-']);
    });
  });

  test('single lever repeats the held side', () {
    fakeAsync((async) {
      final h = _Harness(async, KeyType.singleLever);
      h.hold(Contact.right, 450); // dah+gap = 240ms, so two dahs start
      h.wait(600);
      expect(h.letters, ['--']);
    });
  });

  test('iambic squeeze alternates elements starting with first paddle', () {
    fakeAsync((async) {
      final h = _Harness(async, KeyType.iambicA);
      h.keyer.press(Contact.right);
      h.wait(10);
      h.keyer.press(Contact.left);
      // dah(180)+gap(60) dit(60)+gap(60) dah(180)+gap(60) dit... -> release
      // during the 4th element.
      h.wait(590);
      h.keyer.release(Contact.left);
      h.keyer.release(Contact.right);
      h.wait(600);
      expect(h.letters, ['-.-.']);
    });
  });

  test('iambic B adds one element after releasing a squeeze', () {
    String run(KeyType type) {
      late List<String> letters;
      fakeAsync((async) {
        final h = _Harness(async, type);
        h.keyer.press(Contact.left);
        h.keyer.press(Contact.right);
        // dit(60)+gap(60), then release during the dah.
        h.wait(150);
        h.keyer.release(Contact.left);
        h.keyer.release(Contact.right);
        h.wait(800);
        letters = h.letters;
      });
      return letters.single;
    }

    expect(run(KeyType.iambicA), '.-');
    expect(run(KeyType.iambicB), '.-.');
  });

  test('iambic paddle memory keeps a tap made mid-element', () {
    fakeAsync((async) {
      final h = _Harness(async, KeyType.iambicA);
      h.keyer.press(Contact.right);
      h.wait(30);
      h.hold(Contact.left, 20); // tapped and released during the dah
      h.wait(20);
      h.keyer.release(Contact.right);
      h.wait(800);
      expect(h.letters, ['-.']);
    });
  });
}
