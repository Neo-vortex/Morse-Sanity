import 'dart:math';

import '../l10n/strings.dart';

/// Picks one of Dit's lines for a moment. The lines themselves live in [S]
/// so Dit sounds like Dit in every language.
class Voice {
  Voice._();

  static final _r = Random();

  static String _pick(List<String> lines) => lines[_r.nextInt(lines.length)];

  static String greeting(S s, String name, DateTime now) =>
      _pick(s.greetings(name, now.hour));

  static String homeNudge(S s, {required int streak, required bool goalMet}) {
    if (goalMet) return _pick(s.nudgeGoalMet());
    if (streak == 0) return _pick(s.nudgeNoStreak());
    return _pick(s.nudgeStreak(streak));
  }

  static String sessionStart(S s, bool sending) =>
      _pick(s.sessionStart(sending));

  static String correct(S s, int combo) => _pick(s.correctLines(combo));

  static String wrong(S s) => _pick(s.wrongLines());

  static String timeUp(S s) => _pick(s.timeUpLines());

  static String results(S s, int stars) => _pick(s.resultLines(stars));

  static String locked(S s) => _pick(s.lockedLines());
}
