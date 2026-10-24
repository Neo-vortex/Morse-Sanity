import 'dart:math';

import '../data/codes.dart';
import '../data/words.dart';

/// Whether a level trains copying (listening) or sending (keying).
enum Track {
  receive('Receive'),
  send('Send');

  const Track(this.label);
  final String label;
}

/// One playable level of the course.
class Level {
  Level({
    required this.track,
    required this.number,
    required this.section,
    required this.title,
    required List<String> pool,
    this.newItems = const [],
    this.isChallenge = false,
    this.generator,
    int? rounds,
  }) : _pool = pool,
       rounds = rounds ?? (_isMultiChar(pool) || generator != null ? 10 : 20);

  final Track track;

  /// 1-based position within its track.
  final int number;
  final String section;
  final String title;

  /// Items introduced in this level; asked about more often.
  final List<String> newItems;
  final List<String> _pool;
  final bool isChallenge;

  /// Produces fresh items (e.g. random callsigns) instead of a fixed pool.
  final String Function(Random r)? generator;
  final int rounds;

  String get id => '${track.name}-$number';

  /// True when answers are whole words rather than single characters.
  bool get isTyped => generator != null || _isMultiChar(_pool);

  /// Time allowed per item in challenge levels.
  Duration? get timeLimit {
    if (!isChallenge) return null;
    if (!isTyped) return const Duration(seconds: 6);
    final longest = _pool.isEmpty ? 8 : _pool.map((p) => p.length).reduce(max);
    return Duration(seconds: 8 + longest * (track == Track.send ? 3 : 1));
  }

  String nextItem(Random r) {
    if (generator != null) return generator!(r);
    // New items come up about a third of the time.
    if (newItems.isNotEmpty && r.nextDouble() < 0.35) {
      return newItems[r.nextInt(newItems.length)];
    }
    return _pool[r.nextInt(_pool.length)];
  }

  /// Every single character/prosign that can appear in this level.
  List<String> get pool => _pool;

  static bool _isMultiChar(List<String> pool) =>
      pool.any((p) => p.length > 1 && !(p.startsWith('<') && p.endsWith('>')));
}

/// Stars for an accuracy score: 70% to pass, 80% and 90% for more.
int starsFor(double accuracy) => accuracy >= 0.9
    ? 3
    : accuracy >= 0.8
    ? 2
    : accuracy >= 0.7
    ? 1
    : 0;

/// Letters ordered easiest-first (short, common patterns early).
const letterOrder = 'ETIMANSOHKRUDGWLFBCPVYJQZX';

class _Builder {
  _Builder(this.track);

  final Track track;
  final levels = <Level>[];

  void add({
    required String section,
    required String title,
    required List<String> pool,
    List<String> newItems = const [],
    bool challenge = false,
    String Function(Random r)? generator,
    int? rounds,
  }) {
    levels.add(
      Level(
        track: track,
        number: levels.length + 1,
        section: section,
        title: title,
        pool: pool,
        newItems: newItems,
        isChallenge: challenge,
        generator: generator,
        rounds: rounds,
      ),
    );
  }

  /// Introduces [groups] of characters one level at a time, with a review
  /// level every [reviewEvery] groups and a challenge at the end.
  void characterSection(
    String section,
    List<List<String>> groups, {
    int reviewEvery = 4,
    int challengeEvery = 8,
  }) {
    final learned = <String>[];
    for (var i = 0; i < groups.length; i++) {
      learned.addAll(groups[i]);
      add(
        section: section,
        title: groups[i].join(' '),
        pool: [...learned],
        newItems: groups[i],
      );
      final n = i + 1;
      if (n % reviewEvery == 0 && n != groups.length) {
        add(section: section, title: 'Review', pool: [...learned]);
      }
      if (n % challengeEvery == 0 && n != groups.length) {
        add(
          section: section,
          title: 'Challenge',
          pool: [...learned],
          challenge: true,
        );
      }
    }
    add(section: section, title: 'Review all', pool: [...learned]);
    add(
      section: section,
      title: 'Challenge',
      pool: [...learned],
      challenge: true,
    );
  }

  /// Splits [items] into levels of [perLevel], each adding to the last.
  void codeSection(String section, List<String> items, int perLevel) {
    final learned = <String>[];
    for (var i = 0; i < items.length; i += perLevel) {
      final group = items.sublist(i, min(i + perLevel, items.length));
      learned.addAll(group);
      add(
        section: section,
        title: group.join(' '),
        pool: [...learned],
        newItems: group,
      );
    }
    add(section: section, title: 'Challenge', pool: items, challenge: true);
  }
}

List<String> _wordsWhere(bool Function(int length) test) =>
    englishWords.where((w) => test(w.length)).toList();

List<Level> _build(Track track) {
  final b = _Builder(track);

  b.characterSection('Letters', [
    ['E', 'T'],
    for (final c in letterOrder.substring(2).split('')) [c],
  ]);
  b.characterSection('Numbers', [
    ['1', '2'],
    ['3', '4'],
    ['5', '6'],
    ['7', '8'],
    ['9', '0'],
  ], reviewEvery: 3);
  b.characterSection('Punctuation', [
    ['.', ','],
    ['?', '/'],
    ['=', '+'],
    ['-', "'"],
    ['(', ')'],
    [':', ';'],
    ['"', '@'],
    ['!', '&'],
  ]);
  b.characterSection('Prosigns', [
    ['<AR>', '<SK>'],
    ['<BT>', '<KN>'],
    ['<AS>', '<CT>', '<VE>'],
    ['<BK>', '<SOS>', '<HH>'],
  ], reviewEvery: 2);

  b.codeSection('Q-codes', [for (final q in qCodes) q.code], 6);
  b.codeSection('Abbreviations', [for (final a in abbreviations) a.code], 6);

  final wordGroups = [
    ('Short words', _wordsWhere((l) => l <= 3), 3),
    ('Medium words', _wordsWhere((l) => l == 4), 5),
    ('Long words', _wordsWhere((l) => l == 5), 5),
    ('Very long words', _wordsWhere((l) => l >= 6), 5),
    ('All words', englishWords, 5),
  ];
  for (final (name, words, count) in wordGroups) {
    for (var i = 1; i <= count; i++) {
      b.add(section: 'Words', title: '$name $i', pool: words);
    }
  }
  b.add(
    section: 'Words',
    title: 'Challenge',
    pool: englishWords,
    challenge: true,
  );

  final callsignLevels = [
    ('Simple calls', (Random r) => randomCallsign(r, maxSuffix: 1)),
    ('Two-letter suffix', (Random r) => randomCallsign(r, maxSuffix: 2)),
    ('Full calls', (Random r) => randomCallsign(r)),
    ('Full calls 2', (Random r) => randomCallsign(r)),
    ('Portable calls', (Random r) => '${randomCallsign(r)}/P'),
  ];
  for (final (title, gen) in callsignLevels) {
    b.add(section: 'Callsigns', title: title, pool: const [], generator: gen);
  }
  b.add(
    section: 'Callsigns',
    title: 'Challenge',
    pool: const [],
    generator: (r) => randomCallsign(r),
    challenge: true,
  );

  const perLevel = 5;
  for (var i = 0; i < sentences.length; i += perLevel) {
    b.add(
      section: 'Sentences',
      title: 'Sentences ${i ~/ perLevel + 1}',
      pool: sentences.sublist(0, min(i + perLevel, sentences.length)),
      newItems: sentences.sublist(i, min(i + perLevel, sentences.length)),
      rounds: 6,
    );
  }
  b.add(
    section: 'Sentences',
    title: 'Challenge',
    pool: sentences,
    challenge: true,
    rounds: 6,
  );

  return b.levels;
}

final Map<Track, List<Level>> courseLevels = {
  for (final t in Track.values) t: _build(t),
};

/// Section names in course order.
List<String> sectionsOf(Track t) =>
    courseLevels[t]!.map((l) => l.section).toSet().toList();
