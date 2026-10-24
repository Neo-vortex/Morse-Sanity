import 'course.dart';
import 'session_config.dart';

/// XP for a finished session: one per correct answer, plus a bonus of five
/// per star on course levels.
int xpFor(List<RoundResult> results, {required bool isLevel}) {
  if (results.isEmpty) return 0;
  final correct = results.where((r) => r.correct).length;
  final bonus = isLevel ? starsFor(correct / results.length) * 5 : 0;
  return correct + bonus;
}

/// What a session earned, for the results page.
class SessionReward {
  const SessionReward({
    required this.xp,
    required this.streakExtended,
    required this.streak,
  });

  final int xp;
  final bool streakExtended;
  final int streak;
}
