import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:torch_light/torch_light.dart';
import 'package:vibration/vibration.dart';

import '../morse/timing.dart';
import '../morse/tone_generator.dart';
import 'settings.dart';

/// Plays Morse through every enabled output: audio, the on-screen lamp,
/// the camera flashlight and vibration.
class MorsePlayer {
  MorsePlayer(this.settings, {this.audioEnabled = true});

  final Settings settings;

  /// Disabled in tests, where no platform plugins are available.
  final bool audioEnabled;

  /// True while the signal is keyed, for on-screen lamps.
  final ValueNotifier<bool> signal = ValueNotifier(false);

  /// True while a playback sequence is running.
  final ValueNotifier<bool> isPlaying = ValueNotifier(false);

  static const _leadInMs = 40.0;

  AudioPlayer? _player;
  AudioPlayer? _sidetone;
  AudioPlayer? _chimePlayer;
  String? _sidetoneKey;
  int _session = 0;
  bool _torchOn = false;

  AudioPlayer get _playbackPlayer => _player ??= AudioPlayer();

  bool get _platformOutputs => audioEnabled && !kIsWeb;

  /// Plays [text] (which may contain `<XX>` prosigns). [timing] overrides
  /// the speed from settings, e.g. for custom challenges.
  ///
  /// [onToken] is called with the index of each character (as counted by
  /// `tokensFor`) as it starts sounding, for live highlighting.
  Future<void> playText(
    String text, {
    MorseTiming? timing,
    ValueChanged<int>? onToken,
  }) {
    final tracked = (timing ?? settings.timing).trackedElementsForText(text);
    return _play(tracked.elements, tokenOf: tracked.tokenOf, onToken: onToken);
  }

  Future<void> playPattern(String pattern, {MorseTiming? timing}) =>
      _play((timing ?? settings.timing).elementsForPattern(pattern));

  Future<void> _play(
    List<MorseElement> elements, {
    List<int>? tokenOf,
    ValueChanged<int>? onToken,
  }) async {
    await stop();
    if (elements.isEmpty) return;
    final session = ++_session;
    isPlaying.value = true;

    if (audioEnabled && settings.soundEnabled) {
      final wav = ToneGenerator(
        frequency: settings.frequency,
        volume: settings.volume,
        noiseLevel: settings.noiseLevel,
        noiseType: settings.noiseType,
      ).render(elements, leadInMs: _leadInMs);
      try {
        await _playbackPlayer.play(BytesSource(wav, mimeType: 'audio/wav'));
      } catch (e) {
        debugPrint('Morse audio playback failed: $e');
      }
    }

    if (_platformOutputs && settings.vibrationEnabled) {
      // Vibration takes a whole pattern up front: [wait, buzz, wait, ...].
      final pattern = <int>[_leadInMs.round()];
      var pendingOff = 0.0;
      for (final e in elements) {
        if (e.on) {
          if (pattern.length > 1) pattern.add(pendingOff.round());
          pattern.add(e.durationMs.round());
          pendingOff = 0;
        } else {
          pendingOff += e.durationMs;
        }
      }
      unawaited(_guard(() => Vibration.vibrate(pattern: pattern)));
    }

    // Walk the same timeline to drive the lamp/torch and know when done.
    await Future<void>.delayed(Duration(milliseconds: _leadInMs.round()));
    var lastToken = -1;
    for (var i = 0; i < elements.length; i++) {
      final e = elements[i];
      if (session != _session) return;
      if (onToken != null && tokenOf != null && tokenOf[i] != lastToken) {
        lastToken = tokenOf[i];
        onToken(lastToken);
      }
      signal.value = e.on && settings.flashEnabled;
      _setTorch(e.on && settings.torchEnabled);
      await Future<void>.delayed(
        Duration(microseconds: (e.durationMs * 1000).round()),
      );
    }
    if (session != _session) return;
    signal.value = false;
    _setTorch(false);
    isPlaying.value = false;
  }

  Future<void> stop() async {
    _session++;
    signal.value = false;
    isPlaying.value = false;
    _setTorch(false);
    if (_platformOutputs && settings.vibrationEnabled) {
      unawaited(_guard(Vibration.cancel));
    }
    if (_player != null) {
      await _guard(_player!.stop);
    }
  }

  /// Starts the signal while the user holds a key.
  Future<void> keyDown() async {
    signal.value = settings.flashEnabled;
    _setTorch(settings.torchEnabled);
    if (_platformOutputs && settings.vibrationEnabled) {
      unawaited(_guard(() => Vibration.vibrate(duration: 2000)));
    }
    if (!audioEnabled || !settings.soundEnabled) return;
    try {
      final player = _sidetone ??= AudioPlayer();
      final key =
          '${settings.frequency}/${settings.volume}/'
          '${settings.noiseLevel}/${settings.noiseType.name}';
      if (_sidetoneKey != key) {
        // A steady tone long enough for any real key press; it is paused on
        // release and rewound on the next press.
        final wav = ToneGenerator(
          frequency: settings.frequency,
          volume: settings.volume,
          rampMs: 3,
          noiseLevel: settings.noiseLevel,
          noiseType: settings.noiseType,
        ).render(const [MorseElement(on: true, durationMs: 4000)], leadInMs: 0);
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setSource(BytesSource(wav, mimeType: 'audio/wav'));
        _sidetoneKey = key;
      }
      await player.seek(Duration.zero);
      await player.resume();
    } catch (e) {
      debugPrint('Sidetone failed: $e');
    }
  }

  Future<void> keyUp() async {
    signal.value = false;
    _setTorch(false);
    if (_platformOutputs && settings.vibrationEnabled) {
      unawaited(_guard(Vibration.cancel));
    }
    if (_sidetone != null) await _guard(_sidetone!.pause);
  }

  /// Short feedback sound for a right or wrong answer.
  Future<void> chime({required bool correct}) async {
    if (!audioEnabled || !settings.interfaceSounds) return;
    // "Correct" is a quick high-pitched R (·−·, "roger"); "wrong" is a soft
    // low double blip.
    final wav = ToneGenerator(volume: settings.volume * 0.5).renderTones(
      correct
          ? const [(1175, 45), (0, 30), (1568, 110), (0, 30), (1175, 45)]
          : const [(233, 110), (0, 50), (196, 180)],
    );
    await _guard(
      () => (_chimePlayer ??= AudioPlayer()).play(
        BytesSource(wav, mimeType: 'audio/wav'),
      ),
    );
  }

  /// Rising arpeggio for finishing a level; [stars] adds notes.
  Future<void> fanfare(int stars) async {
    if (!audioEnabled || !settings.interfaceSounds) return;
    final notes = <(double, double)>[
      (523, 90),
      (659, 90),
      if (stars >= 1) (784, 90),
      if (stars >= 2) (1047, 120),
      if (stars >= 3) ...[(0, 40), (1319, 90), (1568, 220)],
    ];
    final wav = ToneGenerator(volume: settings.volume * 0.5).renderTones(notes);
    await _guard(
      () => (_chimePlayer ??= AudioPlayer()).play(
        BytesSource(wav, mimeType: 'audio/wav'),
      ),
    );
  }

  void _setTorch(bool on) {
    if (!_platformOutputs || on == _torchOn) return;
    if (on && !settings.torchEnabled) return;
    _torchOn = on;
    unawaited(_guard(on ? TorchLight.enableTorch : TorchLight.disableTorch));
  }

  static Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('Output failed: $e');
    }
  }

  void dispose() {
    _session++;
    _setTorch(false);
    _player?.dispose();
    _sidetone?.dispose();
    _chimePlayer?.dispose();
    signal.dispose();
    isPlaying.dispose();
  }
}
