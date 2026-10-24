import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';
import '../morse/keyer.dart';
import '../morse/timing.dart';
import '../morse/tone_generator.dart';

/// On-screen keyboard arrangements for typing answers. Changing layout
/// stops you from memorising key positions instead of sounds.
enum KeyboardLayout {
  qwerty('QWERTY', ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM']),
  qwertz('QWERTZ', ['QWERTZUIOP', 'ASDFGHJKL', 'YXCVBNM']),
  azerty('AZERTY', ['AZERTYUIOP', 'QSDFGHJKLM', 'WXCVBN']),
  alphabetical('Alphabetical', ['ABCDEFGHIJ', 'KLMNOPQRS', 'TUVWXYZ']),
  dvorak('Dvorak', ['PYFGCRL', 'AOEUIDHTNS', 'QJKXBMWVZ']),
  colemak('Colemak', ['QWFPGJLUY', 'ARSTDHNEIO', 'ZXCVBKM']),
  workman('Workman', ['QDRWBJFUP', 'ASHTGYNEOI', 'ZXMCVKL']),
  random('Random (reshuffled each level)', []);

  const KeyboardLayout(this.label, this.rows);
  final String label;
  final List<String> rows;
}

/// User-adjustable settings, persisted across launches.
class Settings extends ChangeNotifier {
  Settings(this._prefs);

  final SharedPreferences _prefs;

  int _int(String k, int d) => _prefs.getInt('settings.$k') ?? d;
  double _double(String k, double d) => _prefs.getDouble('settings.$k') ?? d;
  bool _bool(String k, bool d) => _prefs.getBool('settings.$k') ?? d;

  void _setInt(String k, int v) {
    _prefs.setInt('settings.$k', v);
    notifyListeners();
  }

  void _setDouble(String k, double v) {
    _prefs.setDouble('settings.$k', v);
    notifyListeners();
  }

  void _setBool(String k, bool v) {
    _prefs.setBool('settings.$k', v);
    notifyListeners();
  }

  // --- Speed ---------------------------------------------------------------

  int get charWpm => _int('charWpm', 20);
  set charWpm(int v) {
    if (effectiveWpm > v) _prefs.setInt('settings.effectiveWpm', v);
    _setInt('charWpm', v);
  }

  /// Farnsworth speed; equal to [charWpm] means standard spacing.
  int get effectiveWpm => _int('effectiveWpm', 15).clamp(1, charWpm);
  set effectiveWpm(int v) => _setInt('effectiveWpm', v > charWpm ? charWpm : v);

  MorseTiming get timing =>
      MorseTiming(charWpm: charWpm, effectiveWpm: effectiveWpm);

  // --- Output --------------------------------------------------------------

  double get frequency => _double('frequency', 600);
  set frequency(double v) => _setDouble('frequency', v);

  double get volume => _double('volume', 0.7);
  set volume(double v) => _setDouble('volume', v);

  /// Background noise loudness from 0 (off) to 1.
  double get noiseLevel => _double('noise', 0);
  set noiseLevel(double v) => _setDouble('noise', v);

  /// Colour of the simulated radio noise.
  NoiseType get noiseType =>
      NoiseType.values[_int(
        'noiseType',
        NoiseType.receiver.index,
      ).clamp(0, NoiseType.values.length - 1)];
  set noiseType(NoiseType v) => _setInt('noiseType', v.index);

  bool get soundEnabled => _bool('sound', true);
  set soundEnabled(bool v) => _setBool('sound', v);

  /// Blinking light on screen.
  bool get flashEnabled => _bool('flash', true);
  set flashEnabled(bool v) => _setBool('flash', v);

  /// Camera flashlight blinks with the code.
  bool get torchEnabled => _bool('torch', false);
  set torchEnabled(bool v) => _setBool('torch', v);

  /// Device vibrates with the code.
  bool get vibrationEnabled => _bool('vibration', false);
  set vibrationEnabled(bool v) => _setBool('vibration', v);

  /// Short haptic ticks on button presses.
  bool get hapticsEnabled => _bool('haptics', true);
  set hapticsEnabled(bool v) => _setBool('haptics', v);

  /// Chimes for correct and wrong answers.
  bool get interfaceSounds => _bool('uiSounds', true);
  set interfaceSounds(bool v) => _setBool('uiSounds', v);

  // --- Sending -------------------------------------------------------------

  KeyType get keyType =>
      KeyType.values[_int('keyType', 0).clamp(0, KeyType.values.length - 1)];
  set keyType(KeyType v) => _setInt('keyType', v.index);

  /// Puts dahs on the left paddle (for left-handed operators).
  bool get swapPaddles => _bool('swapPaddles', false);
  set swapPaddles(bool v) => _setBool('swapPaddles', v);

  // --- Language ------------------------------------------------------------

  /// Chosen language code, or empty to follow the device.
  String get languageCode => _prefs.getString('settings.language') ?? '';
  set languageCode(String v) {
    _prefs.setString('settings.language', v);
    notifyListeners();
  }

  /// The language actually shown: the user's choice, else the device's.
  AppLanguage get language {
    if (languageCode.isNotEmpty) return AppLanguage.fromCode(languageCode);
    final device = PlatformDispatcher.instance.locale.languageCode;
    return AppLanguage.fromCode(device);
  }

  // --- Profile -------------------------------------------------------------

  String get operatorName => _prefs.getString('settings.name') ?? '';
  set operatorName(String v) {
    _prefs.setString('settings.name', v.trim());
    notifyListeners();
  }

  /// Daily XP target (one XP per correct answer plus level bonuses).
  int get dailyGoal => _int('dailyGoal', 30);
  set dailyGoal(int v) => _setInt('dailyGoal', v);

  bool get onboarded => _bool('onboarded', false);
  set onboarded(bool v) => _setBool('onboarded', v);

  /// Light, dark or follow the system.
  ThemeMode get themeMode =>
      ThemeMode.values[_int(
        'themeMode',
        0,
      ).clamp(0, ThemeMode.values.length - 1)];
  set themeMode(ThemeMode v) => _setInt('themeMode', v.index);

  // --- QSO practice --------------------------------------------------------

  /// The user's callsign for simulated contacts (a practice call if empty).
  String get callsign => _prefs.getString('settings.callsign') ?? '';
  set callsign(String v) {
    _prefs.setString('settings.callsign', v.trim().toUpperCase());
    notifyListeners();
  }

  bool get qsoCopyByEar => _bool('qsoCopyByEar', false);
  set qsoCopyByEar(bool v) => _setBool('qsoCopyByEar', v);

  /// QSO log shows dots and dashes (and you key replies) instead of letters.
  bool get qsoCodeMode => _bool('qsoCodeMode', false);
  set qsoCodeMode(bool v) => _setBool('qsoCodeMode', v);

  /// In code mode: one telegraph key instead of separate dit/dah buttons.
  bool get qsoSingleKey => _bool('qsoSingleKey', false);
  set qsoSingleKey(bool v) => _setBool('qsoSingleKey', v);

  bool get qsoPlayMine => _bool('qsoPlayMine', true);
  set qsoPlayMine(bool v) => _setBool('qsoPlayMine', v);

  /// Whether the QSO coach has been shown once (it opens by itself the first
  /// time).
  bool get qsoCoachSeen => _bool('qsoCoachSeen', false);
  set qsoCoachSeen(bool v) => _setBool('qsoCoachSeen', v);

  // --- Course --------------------------------------------------------------

  KeyboardLayout get keyboardLayout =>
      KeyboardLayout.values[_int(
        'keyboard',
        0,
      ).clamp(0, KeyboardLayout.values.length - 1)];
  set keyboardLayout(KeyboardLayout v) => _setInt('keyboard', v.index);

  /// Lets every course level be played without passing earlier ones.
  bool get unlockAll => _bool('unlockAll', false);
  set unlockAll(bool v) => _setBool('unlockAll', v);
}
