import 'dart:async';
import 'dart:collection';

import 'package:clock/clock.dart';

import 'key_decoder.dart';

/// The kinds of telegraph key the app can emulate.
enum KeyType {
  straight('Straight key', 'Hold for as long as the element lasts.'),
  tapButtons('Dit & dah buttons', 'Tap one button per dit or dah.'),
  sideswiper(
    'Sideswiper (cootie)',
    'Two manual contacts; alternate sides, you time every element.',
  ),
  bug(
    'Bug (semi-automatic)',
    'Left makes automatic dits, right is a manual dah.',
  ),
  singleLever(
    'Single-lever paddle',
    'Automatic dits on the left, dahs on the right. No squeezing.',
  ),
  iambicA(
    'Iambic paddle – mode A',
    'Squeeze both paddles to alternate dits and dahs.',
  ),
  iambicB(
    'Iambic paddle – mode B',
    'Like mode A, plus one extra element when a squeeze is released.',
  );

  const KeyType(this.label, this.description);

  final String label;
  final String description;

  bool get hasTwoContacts => this != KeyType.straight;
}

/// One side of a key. A straight key only uses [left].
enum Contact { left, right }

/// Emulates a telegraph key or electronic keyer.
///
/// Feed it contact presses and releases; it switches the tone on and off,
/// times automatic elements, and reports each finished letter's pattern.
class Keyer {
  Keyer({
    required this.type,
    required this.unitMs,
    required this.onTone,
    required this.onLetter,
    this.onWordGap,
    this.onPending,
  }) : _decoder = KeyDecoder(dotMs: unitMs);

  final KeyType type;

  /// Dot length for automatic elements (and the starting guess for manual
  /// ones).
  final double unitMs;

  final void Function(bool on) onTone;
  final void Function(String pattern) onLetter;
  final void Function()? onWordGap;

  /// Called with the pattern of the letter in progress whenever it grows.
  final void Function(String pending)? onPending;

  final KeyDecoder _decoder;
  final _held = {Contact.left: false, Contact.right: false};
  final _pattern = StringBuffer();
  final Queue<String> _tapQueue = Queue();
  Timer? _elementTimer;
  Timer? _letterTimer;
  Timer? _wordTimer;
  bool _disposed = false;

  // Automatic keyer state.
  bool _running = false;
  String? _current;
  String? _last;
  String? _memory;
  bool _squeezed = false;
  Contact _lastPressed = Contact.left;

  // Manual contact state.
  bool _manualOn = false;
  Stopwatch? _manualWatch;

  /// Current estimate of the operator's dot length on manual keys.
  double get manualDotMs => _decoder.dotMs;

  String get pendingPattern => _pattern.toString();

  void press(Contact c) {
    if (_disposed || _held[c]!) return;
    _held[c] = true;
    _lastPressed = c;
    _cancelGapTimers();
    switch (type) {
      case KeyType.straight:
      case KeyType.sideswiper:
        _manualDown();
      case KeyType.bug:
        c == Contact.left ? _autoPress(c) : _manualDown();
      case KeyType.tapButtons:
        _tapQueue.add(_elementFor(c));
        if (!_running) _runNext();
      case KeyType.singleLever:
      case KeyType.iambicA:
      case KeyType.iambicB:
        _autoPress(c);
    }
  }

  void release(Contact c) {
    if (_disposed || !_held[c]!) return;
    _held[c] = false;
    switch (type) {
      case KeyType.straight:
        _manualUp();
      case KeyType.sideswiper:
        if (!_held[Contact.left]! && !_held[Contact.right]!) _manualUp();
      case KeyType.bug:
        if (c == Contact.right) _manualUp(forceDah: true);
      case KeyType.tapButtons:
      case KeyType.singleLever:
      case KeyType.iambicA:
      case KeyType.iambicB:
        break;
    }
  }

  /// Ends the letter in progress immediately.
  void flush() {
    _cancelGapTimers();
    _commitLetter();
  }

  void dispose() {
    _disposed = true;
    _elementTimer?.cancel();
    _cancelGapTimers();
    onTone(false);
  }

  // --- Manual contacts -----------------------------------------------------

  void _manualDown() {
    if (_manualOn) return;
    _manualOn = true;
    _manualWatch = clock.stopwatch()..start();
    onTone(true);
  }

  void _manualUp({bool forceDah = false}) {
    if (!_manualOn) return;
    _manualOn = false;
    onTone(false);
    final ms = _manualWatch!.elapsedMicroseconds / 1000;
    final symbol = forceDah ? '-' : _decoder.classify(ms);
    _appendSymbol(symbol);
    _armGapTimers(forceDah ? unitMs : _decoder.dotMs);
  }

  // --- Automatic elements --------------------------------------------------

  String _elementFor(Contact c) => c == Contact.left ? '.' : '-';

  void _autoPress(Contact c) {
    final element = _elementFor(c);
    if (_running) {
      if (_held[Contact.left]! && _held[Contact.right]!) _squeezed = true;
      // Paddle memory: an opposite paddle tapped mid-element is remembered.
      if (element != _current && type != KeyType.bug) _memory = element;
    } else {
      _runNext();
    }
  }

  String? _chooseNext() {
    if (_memory != null) {
      final m = _memory;
      _memory = null;
      return m;
    }
    final left = _held[Contact.left]!;
    final right = _held[Contact.right]!;
    switch (type) {
      case KeyType.tapButtons:
        return _tapQueue.isEmpty ? null : _tapQueue.removeFirst();
      case KeyType.bug:
        return left ? '.' : null;
      case KeyType.singleLever:
        if (_held[_lastPressed]!) return _elementFor(_lastPressed);
        if (left) return '.';
        if (right) return '-';
        return null;
      case KeyType.iambicA:
      case KeyType.iambicB:
        if (left && right) return _last == '.' ? '-' : '.';
        if (left) return '.';
        if (right) return '-';
        return null;
      case KeyType.straight:
      case KeyType.sideswiper:
        return null;
    }
  }

  void _runNext() {
    if (_disposed) return;
    final element = _chooseNext();
    if (element == null) {
      _running = false;
      _current = null;
      _armGapTimers(unitMs);
      return;
    }
    _running = true;
    _current = element;
    _squeezed = _held[Contact.left]! && _held[Contact.right]!;
    _appendSymbol(element);
    onTone(true);
    final length = element == '-' ? unitMs * 3 : unitMs;
    _elementTimer = Timer(_ms(length), () {
      onTone(false);
      _elementTimer = Timer(_ms(unitMs), () {
        _last = element;
        if (type == KeyType.iambicB &&
            _squeezed &&
            _memory == null &&
            !_held[Contact.left]! &&
            !_held[Contact.right]!) {
          // Mode B: a squeeze released mid-element earns one more element.
          _memory = element == '.' ? '-' : '.';
        }
        _runNext();
      });
    });
  }

  // --- Letters and gaps ----------------------------------------------------

  void _appendSymbol(String s) {
    _pattern.write(s);
    onPending?.call(_pattern.toString());
  }

  void _armGapTimers(double dotMs) {
    _cancelGapTimers();
    // A letter gap is 3 units; 2.5 is forgiving without merging letters.
    _letterTimer = Timer(_ms(dotMs * 2.5), _commitLetter);
    if (onWordGap != null) {
      _wordTimer = Timer(_ms(dotMs * 6), onWordGap!);
    }
  }

  void _cancelGapTimers() {
    _letterTimer?.cancel();
    _wordTimer?.cancel();
  }

  void _commitLetter() {
    if (_pattern.isEmpty) return;
    final p = _pattern.toString();
    _pattern.clear();
    onPending?.call('');
    onLetter(p);
  }

  static Duration _ms(double ms) => Duration(microseconds: (ms * 1000).round());
}
