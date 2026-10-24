import 'dart:math' as math;
import 'dart:typed_data';

import 'timing.dart';

/// Renders Morse elements into a mono 16-bit PCM WAV file in memory.
class ToneGenerator {
  const ToneGenerator({
    this.sampleRate = 22050,
    this.frequency = 600,
    this.volume = 0.6,
    this.rampMs = 5,
    this.noiseLevel = 0,
    this.seed,
  });

  final int sampleRate;
  final double frequency;
  final double volume;

  /// Fade-in/out length applied to every tone to avoid audible clicks.
  final double rampMs;

  /// Loudness of band-limited background noise, 0 (off) to 1.
  final double noiseLevel;

  /// Fixes the noise sequence (for tests).
  final int? seed;

  Uint8List render(List<MorseElement> elements, {double leadInMs = 50}) {
    final totalMs =
        leadInMs + elements.fold<double>(0, (sum, e) => sum + e.durationMs);
    final totalSamples = (totalMs * sampleRate / 1000).ceil();
    final pcm = Int16List(totalSamples);

    var cursor = (leadInMs * sampleRate / 1000).round();
    final rampSamples = (rampMs * sampleRate / 1000).round();
    final amplitude = volume.clamp(0.0, 1.0) * 32767;
    final step = 2 * math.pi * frequency / sampleRate;

    for (final e in elements) {
      final n = (e.durationMs * sampleRate / 1000).round();
      if (e.on) {
        for (var i = 0; i < n && cursor + i < totalSamples; i++) {
          var env = 1.0;
          if (i < rampSamples) env = i / rampSamples;
          if (n - i < rampSamples) env = math.min(env, (n - i) / rampSamples);
          pcm[cursor + i] = (math.sin(step * i) * amplitude * env).round();
        }
      }
      cursor += n;
    }
    if (noiseLevel > 0) _addNoise(pcm);
    return _wrapWav(pcm);
  }

  /// Renders a sequence of plain beeps, e.g. for answer chimes.
  Uint8List renderTones(List<(double hz, double ms)> tones) {
    final parts = [
      for (final (hz, ms) in tones)
        ToneGenerator(
          sampleRate: sampleRate,
          frequency: hz,
          volume: volume,
          rampMs: rampMs,
        ).render([MorseElement(on: true, durationMs: ms)], leadInMs: 0),
    ];
    final pcm = Int16List.fromList([
      for (final p in parts) ...Int16List.sublistView(p, 44),
    ]);
    return _wrapWav(pcm);
  }

  void _addNoise(Int16List pcm) {
    final r = math.Random(seed);
    final amp = noiseLevel.clamp(0.0, 1.0) * 0.6 * 32767;
    // White noise through a one-pole low-pass and DC-blocking high-pass
    // gives a hiss resembling a receiver's audio passband.
    var low = 0.0;
    var prevLow = 0.0;
    var high = 0.0;
    for (var i = 0; i < pcm.length; i++) {
      final white = r.nextDouble() * 2 - 1;
      low += 0.35 * (white - low);
      high = 0.97 * (high + low - prevLow);
      prevLow = low;
      final v = pcm[i] + high * amp * 1.8;
      pcm[i] = v.clamp(-32768, 32767).round();
    }
  }

  Uint8List _wrapWav(Int16List pcm) {
    final dataBytes = pcm.lengthInBytes;
    final header = ByteData(44)
      ..setUint32(0, 0x52494646) // "RIFF"
      ..setUint32(4, 36 + dataBytes, Endian.little)
      ..setUint32(8, 0x57415645) // "WAVE"
      ..setUint32(12, 0x666d7420) // "fmt "
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little) // PCM
      ..setUint16(22, 1, Endian.little) // mono
      ..setUint32(24, sampleRate, Endian.little)
      ..setUint32(28, sampleRate * 2, Endian.little)
      ..setUint16(32, 2, Endian.little)
      ..setUint16(34, 16, Endian.little)
      ..setUint32(36, 0x64617461) // "data"
      ..setUint32(40, dataBytes, Endian.little);

    final out = Uint8List(44 + dataBytes)
      ..setRange(0, 44, header.buffer.asUint8List())
      ..setRange(44, 44 + dataBytes, pcm.buffer.asUint8List());
    return out;
  }
}
