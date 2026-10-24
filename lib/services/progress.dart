import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../morse/morse_code.dart';

/// Accuracy record for one character.
class CharStats {
  CharStats({this.correct = 0, this.attempts = 0});

  int correct;
  int attempts;

  double get accuracy => attempts == 0 ? 0 : correct / attempts;

  Map<String, int> toJson() => {'c': correct, 'a': attempts};

  factory CharStats.fromJson(Map<String, dynamic> j) =>
      CharStats(correct: j['c'] as int? ?? 0, attempts: j['a'] as int? ?? 0);
}

/// Tracks Koch-method lesson level and per-character accuracy.
class Progress extends ChangeNotifier {
  Progress(this._prefs) {
    _level = (_prefs.getInt(_kLevel) ?? minLevel).clamp(minLevel, maxLevel);
    final raw = _prefs.getString(_kStats);
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      decoded.forEach((k, v) {
        _stats[k] = CharStats.fromJson(v as Map<String, dynamic>);
      });
    }
    final rawStars = _prefs.getString(_kStars);
    if (rawStars != null) {
      (jsonDecode(rawStars) as Map<String, dynamic>).forEach((k, v) {
        _stars[k] = v as int;
      });
    }
  }

  static const _kLevel = 'progress.level';
  static const _kStats = 'progress.stats';
  static const _kStars = 'progress.stars';

  /// The Koch method starts with two characters.
  static const int minLevel = 2;
  static final int maxLevel = kochOrder.length;

  /// Accuracy needed in a lesson to unlock the next character.
  static const double passMark = 0.9;

  final SharedPreferences _prefs;
  late int _level;
  final Map<String, CharStats> _stats = {};
  final Map<String, int> _stars = {};

  int get level => _level;
  bool get isComplete => _level >= maxLevel;

  /// Characters unlocked so far, in Koch order.
  List<String> get unlocked => kochOrder.substring(0, _level).split('');

  /// Most recently introduced character.
  String get newest => kochOrder[_level - 1];

  /// Next character to be unlocked, or null when everything is learned.
  String? get upcoming => isComplete ? null : kochOrder[_level];

  /// Accuracy for [char] when receiving, or when sending if [send].
  CharStats statsFor(String char, {bool send = false}) =>
      _stats[_statsKey(char, send)] ?? CharStats();

  static String _statsKey(String char, bool send) => send ? 'S:$char' : char;

  void record(String char, {required bool correct, bool send = false}) {
    final s = _stats.putIfAbsent(_statsKey(char, send), CharStats.new);
    s.attempts++;
    if (correct) s.correct++;
    _save();
    notifyListeners();
  }

  /// Applies a finished lesson score; returns true if a character unlocked.
  bool completeLesson(double accuracy) {
    if (accuracy >= passMark && !isComplete) {
      _level++;
      _save();
      notifyListeners();
      return true;
    }
    return false;
  }

  // --- XP and streaks -------------------------------------------------------

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get _today => _day(clock.now());
  String get _yesterday => _day(clock.now().subtract(const Duration(days: 1)));

  int get totalXp => _prefs.getInt('progress.xp') ?? 0;

  /// XP earned today; resets at midnight.
  int get xpToday => _prefs.getString('progress.xpDay') == _today
      ? _prefs.getInt('progress.xpToday') ?? 0
      : 0;

  /// Consecutive days with practice, counting today or yesterday.
  int get streak {
    final last = _prefs.getString('progress.streakDay');
    if (last != _today && last != _yesterday) return 0;
    return _prefs.getInt('progress.streak') ?? 0;
  }

  int get bestStreak => _prefs.getInt('progress.bestStreak') ?? 0;

  /// True if today already counts towards the streak.
  bool get practisedToday => _prefs.getString('progress.streakDay') == _today;

  /// Awards XP and keeps the daily streak alive. Returns true if this
  /// extended the streak (first practice of the day).
  bool addXp(int amount) {
    if (amount <= 0) return false;
    final today = _today;
    _prefs.setInt('progress.xp', totalXp + amount);
    _prefs.setInt('progress.xpToday', xpToday + amount);
    _prefs.setString('progress.xpDay', today);
    var extended = false;
    if (!practisedToday) {
      final next = streak + 1;
      _prefs.setInt('progress.streak', next);
      _prefs.setString('progress.streakDay', today);
      if (next > bestStreak) _prefs.setInt('progress.bestStreak', next);
      extended = true;
    }
    notifyListeners();
    return extended;
  }

  /// Best star rating (0-3) achieved on a course level.
  int starsFor(String levelId) => _stars[levelId] ?? 0;

  /// Total stars earned across all course levels.
  int get totalStars => _stars.values.fold(0, (a, b) => a + b);

  /// Records a finished course level, keeping the best result.
  void recordLevel(String levelId, int stars) {
    if (stars <= starsFor(levelId)) return;
    _stars[levelId] = stars;
    _save();
    notifyListeners();
  }

  void setLevel(int level) {
    _level = level.clamp(minLevel, maxLevel);
    _save();
    notifyListeners();
  }

  void reset() {
    _level = minLevel;
    _stats.clear();
    _stars.clear();
    for (final k in [
      'xp',
      'xpToday',
      'xpDay',
      'streak',
      'streakDay',
      'bestStreak',
    ]) {
      _prefs.remove('progress.$k');
    }
    _save();
    notifyListeners();
  }

  void _save() {
    _prefs.setInt(_kLevel, _level);
    _prefs.setString(
      _kStats,
      jsonEncode({for (final e in _stats.entries) e.key: e.value.toJson()}),
    );
    _prefs.setString(_kStars, jsonEncode(_stars));
  }
}
