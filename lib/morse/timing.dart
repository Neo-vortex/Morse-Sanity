import 'morse_code.dart';

/// A single keyed or silent interval in a Morse transmission.
class MorseElement {
  const MorseElement({required this.on, required this.durationMs});

  final bool on;
  final double durationMs;

  @override
  String toString() => '${on ? 'ON' : 'off'}(${durationMs.round()})';
}

/// Timing rules derived from words-per-minute, using the PARIS standard
/// (50 units per word) and optional Farnsworth spacing.
class MorseTiming {
  const MorseTiming({required this.charWpm, int? effectiveWpm})
    : effectiveWpm = effectiveWpm == null || effectiveWpm > charWpm
          ? charWpm
          : effectiveWpm;

  /// Speed at which individual characters are sent.
  final int charWpm;

  /// Overall speed; when lower than [charWpm] the gaps between characters and
  /// words are stretched (Farnsworth timing).
  final int effectiveWpm;

  double get unitMs => 1200 / charWpm;
  double get dotMs => unitMs;
  double get dashMs => unitMs * 3;
  double get elementGapMs => unitMs;

  /// Farnsworth delay unit, per the ARRL formula.
  double get _spacingUnitMs {
    if (effectiveWpm >= charWpm) return unitMs;
    final totalDelay =
        (60 * charWpm - 37.2 * effectiveWpm) / (charWpm * effectiveWpm) * 1000;
    return totalDelay / 19;
  }

  double get charGapMs => _spacingUnitMs * 3;
  double get wordGapMs => _spacingUnitMs * 7;

  /// Converts text into a list of on/off intervals.
  List<MorseElement> elementsForText(String text) {
    final out = <MorseElement>[];
    final words = patternsFor(text);
    for (final codes in words) {
      if (out.isNotEmpty) {
        out.add(MorseElement(on: false, durationMs: wordGapMs));
      }
      for (var c = 0; c < codes.length; c++) {
        if (c > 0) out.add(MorseElement(on: false, durationMs: charGapMs));
        out.addAll(elementsForPattern(codes[c]));
      }
    }
    return out;
  }

  /// Converts a single pattern like `-.-` into on/off intervals.
  List<MorseElement> elementsForPattern(String pattern) {
    final out = <MorseElement>[];
    for (var i = 0; i < pattern.length; i++) {
      if (i > 0) out.add(MorseElement(on: false, durationMs: elementGapMs));
      out.add(
        MorseElement(on: true, durationMs: pattern[i] == '-' ? dashMs : dotMs),
      );
    }
    return out;
  }
}
