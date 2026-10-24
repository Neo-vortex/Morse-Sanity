import 'morse_code.dart';

/// Turns straight-key press/release durations into dots, dashes and letters.
///
/// The decoder starts from the expected dot length for the configured speed
/// and adapts towards the user's actual rhythm as they key.
class KeyDecoder {
  KeyDecoder({required this._dotMs});

  double _dotMs;
  final StringBuffer _pattern = StringBuffer();

  /// Current estimate of the operator's dot length.
  double get dotMs => _dotMs;

  /// Pattern keyed so far for the letter in progress, e.g. `.-`.
  String get pendingPattern => _pattern.toString();

  /// Registers a key press of [ms] milliseconds; returns `.` or `-`.
  String addPress(double ms) {
    final symbol = classify(ms);
    _pattern.write(symbol);
    return symbol;
  }

  /// Classifies a press of [ms] milliseconds as `.` or `-` and adapts the
  /// dot estimate, without adding it to the pending pattern.
  String classify(double ms) {
    // Threshold sits between a dot (1 unit) and a dash (3 units).
    final isDash = ms > _dotMs * 2;
    final observedDot = isDash ? ms / 3 : ms;
    _dotMs = (_dotMs * 0.8 + observedDot * 0.2).clamp(30.0, 600.0);
    return isDash ? '-' : '.';
  }

  /// True if a silence of [ms] means the current letter is finished.
  bool isLetterGap(double ms) => ms > _dotMs * 2;

  /// True if a silence of [ms] means the current word is finished.
  bool isWordGap(double ms) => ms > _dotMs * 5;

  /// Finishes the current letter, returning the decoded pattern and
  /// character (null if the pattern is not valid Morse).
  ({String pattern, String? char})? commitLetter() {
    if (_pattern.isEmpty) return null;
    final p = _pattern.toString();
    _pattern.clear();
    return (pattern: p, char: decodePattern(p));
  }

  void reset(double dotMs) {
    _dotMs = dotMs;
    _pattern.clear();
  }
}
