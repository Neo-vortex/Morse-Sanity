import 'dart:math';

import '../data/codes.dart';
import '../data/word_bank.dart';
import '../data/words.dart';
import '../morse/morse_code.dart';

/// Whether a level trains copying (listening) or sending (keying).
enum Track {
  receive('Receive'),
  send('Send'),
  nato('NATO');

  const Track(this.label);
  final String label;
}

/// Exercise style of a NATO-alphabet level.
enum NatoMode {
  /// Learn code words: pick or type the word for a letter and vice versa.
  learn,

  /// Spell a word or callsign in code words.
  spell,

  /// Read code words back into plain text.
  decode,
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
    this.natoMode,
    int? rounds,
  }) : _pool = pool,
       rounds = rounds ?? (_isMultiChar(pool) || generator != null ? 10 : 20);

  final Track track;

  /// What kind of exercise a NATO-track level is; null on Morse tracks.
  final NatoMode? natoMode;

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
    switch (natoMode) {
      case NatoMode.learn:
        return const Duration(seconds: 10);
      case NatoMode.spell:
        return const Duration(seconds: 30);
      case NatoMode.decode:
        return const Duration(seconds: 25);
      case null:
        break;
    }
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
    NatoMode? natoMode,
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
        natoMode: natoMode,
        rounds: rounds,
      ),
    );
  }

  /// Introduces [groups] of characters one level at a time, with review
  /// and challenge levels mixed in, ending in a review and a challenge.
  void characterSection(
    String section,
    List<List<String>> groups, {
    int reviewEvery = 3,
    int challengeEvery = 5,
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
      if (n == groups.length) break;
      if (n % reviewEvery == 0) {
        add(section: section, title: 'Review', pool: [...learned]);
      }
      if (n % challengeEvery == 0) {
        add(
          section: section,
          title: 'Challenge',
          pool: [...learned],
          challenge: true,
        );
      }
    }
    add(section: section, title: 'Review all', pool: [...learned]);
    challenge(section, [...learned]);
  }

  /// Splits [items] into levels of [perLevel], each adding to the last, with
  /// a challenge every [challengeEvery] levels and at the end.
  void codeSection(
    String section,
    List<String> items,
    int perLevel, {
    int challengeEvery = 4,
  }) {
    final learned = <String>[];
    var count = 0;
    for (var i = 0; i < items.length; i += perLevel) {
      final group = items.sublist(i, min(i + perLevel, items.length));
      learned.addAll(group);
      add(
        section: section,
        title: group.join(' '),
        pool: [...learned],
        newItems: group,
      );
      count++;
      final last = i + perLevel >= items.length;
      if (!last && count % challengeEvery == 0) {
        challenge(section, [...learned]);
      }
    }
    challenge(section, items);
  }

  /// A run of numbered levels drawing from the same pool or generator.
  void drill(
    String section,
    String name,
    int count, {
    List<String> pool = const [],
    String Function(Random r)? generator,
    int? rounds,
  }) {
    for (var i = 1; i <= count; i++) {
      add(
        section: section,
        title: count == 1 ? name : '$name $i',
        pool: pool,
        generator: generator,
        rounds: rounds,
      );
    }
  }

  void challenge(
    String section,
    List<String> pool, {
    String Function(Random r)? generator,
    int? rounds,
  }) {
    add(
      section: section,
      title: 'Challenge',
      pool: pool,
      generator: generator,
      challenge: true,
      rounds: rounds,
    );
  }
}

List<String> _wordsWhere(List<String> words, bool Function(int length) test) =>
    words.where((w) => test(w.length)).toList();

String _digitGroup(Random r, int length) =>
    List.generate(length, (_) => '${r.nextInt(10)}').join();

List<Level> _build(Track track) {
  final b = _Builder(track);

  b.characterSection('Letters', [
    ['E', 'T'],
    for (final c in letterOrder.substring(2).split('')) [c],
  ]);

  // Letters that are easy to mix up, drilled side by side.
  const similar = [
    ['E', 'I', 'S', 'H'],
    ['T', 'M', 'O'],
    ['A', 'N', 'R', 'K'],
    ['U', 'V', 'F', 'L'],
    ['D', 'B', 'G', 'Z'],
    ['W', 'J', 'P'],
    ['C', 'Y', 'Q', 'X'],
    ['H', 'S', 'V', 'B'],
  ];
  for (var i = 0; i < similar.length; i++) {
    b.add(
      section: 'Similar sounds',
      title: similar[i].join(' '),
      pool: similar[i],
    );
    if (i == 3) {
      b.challenge('Similar sounds', [for (final g in similar.take(4)) ...g]);
    }
  }
  b.challenge('Similar sounds', letters.split(''));

  b.characterSection(
    'Numbers',
    [
      ['1', '2'],
      ['3', '4'],
      ['5', '6'],
      ['7', '8'],
      ['9', '0'],
    ],
    reviewEvery: 2,
    challengeEvery: 3,
  );
  for (final n in [3, 4, 5]) {
    b.add(
      section: 'Numbers',
      title: 'Number groups ${n - 2}',
      pool: const [],
      generator: (r) => _digitGroup(r, n),
    );
  }
  b.challenge('Numbers', const [], generator: (r) => _digitGroup(r, 5));

  b.characterSection('Punctuation', [
    ['.', ','],
    ['?', '/'],
    ['=', '+'],
    ['-', "'"],
    ['(', ')'],
    [':', ';'],
    ['"', '@'],
    ['!', '&'],
  ], challengeEvery: 4);
  b.characterSection(
    'Prosigns',
    [
      ['<AR>', '<SK>'],
      ['<BT>', '<KN>'],
      ['<AS>', '<CT>', '<VE>'],
      ['<BK>', '<SOS>', '<HH>'],
    ],
    reviewEvery: 2,
    challengeEvery: 2,
  );

  final lettersDigits = (letters + digits).split('');
  final everything = [
    ...lettersDigits,
    ...punctuation.split(''),
    for (final p in prosignEntries) p.code,
  ];
  b.drill('Mixed review', 'Letters & numbers', 3, pool: lettersDigits);
  b.challenge('Mixed review', lettersDigits);
  b.drill('Mixed review', 'Everything', 3, pool: everything);
  b.challenge('Mixed review', everything);

  b.codeSection(
    'Q-codes',
    [for (final q in qCodes) q.code],
    4,
    challengeEvery: 3,
  );
  b.codeSection('Abbreviations', [for (final a in abbreviations) a.code], 6);

  final words = allWords;
  final wordGroups = [
    ('Short words', _wordsWhere(words, (l) => l <= 3)),
    ('Medium words', _wordsWhere(words, (l) => l == 4)),
    ('Long words', _wordsWhere(words, (l) => l == 5)),
    ('Very long words', _wordsWhere(words, (l) => l == 6 || l == 7)),
    ('Marathon words', _wordsWhere(words, (l) => l >= 8)),
    ('All words', words),
  ];
  for (final (name, pool) in wordGroups) {
    b.drill('Words', name, name == 'Marathon words' ? 4 : 5, pool: pool);
    b.challenge('Words', pool);
  }

  final radio = [...radioWords]..sort((a, b) => a.length.compareTo(b.length));
  final quarter = (radio.length / 4).ceil();
  for (var i = 0; i < 4; i++) {
    final tier = radio.sublist(0, min((i + 1) * quarter, radio.length));
    b.drill('Radio words', 'Radio words ${i * 2 + 1}', 1, pool: tier);
    b.drill('Radio words', 'Radio words ${i * 2 + 2}', 1, pool: tier);
    if (i == 1) b.challenge('Radio words', tier);
  }
  b.challenge('Radio words', radioWords);

  final callsignLevels = [
    ('Simple calls', (Random r) => randomCallsign(r, maxSuffix: 1)),
    ('Two-letter suffix', (Random r) => randomCallsign(r, maxSuffix: 2)),
    ('Full calls', (Random r) => randomCallsign(r)),
    ('Full calls 2', (Random r) => randomCallsign(r)),
    ('Portable calls', (Random r) => '${randomCallsign(r)}/P'),
    ('Mobile calls', (Random r) => '${randomCallsign(r)}/M'),
    ('DX calls', (Random r) => randomCallsign(r)),
    (
      'Call pairs',
      (Random r) => '${randomCallsign(r)} DE ${randomCallsign(r)}',
    ),
  ];
  for (var i = 0; i < callsignLevels.length; i++) {
    final (title, gen) = callsignLevels[i];
    b.add(section: 'Callsigns', title: title, pool: const [], generator: gen);
    if (i == 3) {
      b.challenge('Callsigns', const [], generator: (r) => randomCallsign(r));
    }
  }
  b.challenge(
    'Callsigns',
    const [],
    generator: (r) => '${randomCallsign(r)} DE ${randomCallsign(r)}',
  );

  const perLevel = 5;
  for (var i = 0; i < sentences.length; i += perLevel) {
    final n = i ~/ perLevel + 1;
    b.add(
      section: 'Sentences',
      title: 'Sentences $n',
      pool: sentences.sublist(0, min(i + perLevel, sentences.length)),
      newItems: sentences.sublist(i, min(i + perLevel, sentences.length)),
      rounds: 6,
    );
    if (n == 5) {
      b.challenge('Sentences', sentences.sublist(0, i + perLevel), rounds: 6);
    }
  }
  b.challenge('Sentences', sentences, rounds: 6);

  final qso = [
    ('QSO openers', qsoOpener),
    ('Signal reports', qsoReport),
    ('Names & places', qsoNamePlace),
    ('Rigs & weather', qsoStation),
    ('Sign-offs', qsoSignOff),
    ('Full QSO', qsoAny),
  ];
  for (var i = 0; i < qso.length; i++) {
    final (title, gen) = qso[i];
    b.add(
      section: 'QSO practice',
      title: title,
      pool: const [],
      generator: gen,
      rounds: 6,
    );
    if (i == 2) {
      b.challenge('QSO practice', const [], generator: qsoAny, rounds: 6);
    }
  }
  b.challenge('QSO practice', const [], generator: qsoAny, rounds: 6);

  return b.levels;
}

/// The NATO spelling-alphabet track: learn the code words three at a time,
/// then numbers, then spell and decode real words and callsigns.
List<Level> _buildNato() {
  final b = _Builder(Track.nato);
  final learned = <String>[];

  void learnSection(
    String section,
    List<List<String>> groups, {
    bool wholeAlphabet = false,
  }) {
    for (final g in groups) {
      learned.addAll(g);
      b.add(
        section: section,
        title: g.join(' '),
        pool: [...learned],
        newItems: g,
        natoMode: NatoMode.learn,
        rounds: 12,
      );
    }
    b.add(
      section: section,
      title: 'Review',
      pool: [...learned],
      natoMode: NatoMode.learn,
      rounds: 15,
    );
    if (wholeAlphabet) {
      b.add(
        section: section,
        title: 'Whole alphabet',
        pool: [...learned],
        natoMode: NatoMode.learn,
        rounds: 20,
      );
    }
    b.add(
      section: section,
      title: 'Challenge',
      pool: [...learned],
      natoMode: NatoMode.learn,
      challenge: true,
      rounds: 15,
    );
  }

  learnSection('Alphabet A–I', [
    ['A', 'B', 'C'],
    ['D', 'E', 'F'],
    ['G', 'H', 'I'],
  ]);
  learnSection('Alphabet J–R', [
    ['J', 'K', 'L'],
    ['M', 'N', 'O'],
    ['P', 'Q', 'R'],
  ]);
  learnSection('Alphabet S–Z', [
    ['S', 'T', 'U'],
    ['V', 'W', 'X'],
    ['Y', 'Z'],
  ], wholeAlphabet: true);

  learned.clear();
  learnSection('Numbers', [
    ['0', '1', '2', '3', '4'],
    ['5', '6', '7', '8', '9'],
  ]);

  final letterWords = allWords
      .where((w) => RegExp(r'^[A-Z]+$').hasMatch(w))
      .toList();
  List<String> byLength(int lo, int hi) =>
      letterWords.where((w) => w.length >= lo && w.length <= hi).toList();
  final spellings = [
    ('Short words', byLength(2, 3), null),
    ('Medium words', byLength(4, 5), null),
    ('Long words', byLength(6, 8), null),
    ('Spell callsigns', const <String>[], (Random r) => randomCallsign(r)),
  ];
  for (final (title, pool, gen) in spellings) {
    b.add(
      section: 'Spelling',
      title: title,
      pool: pool,
      generator: gen,
      natoMode: NatoMode.spell,
      rounds: 8,
    );
  }
  b.add(
    section: 'Spelling',
    title: 'Challenge',
    pool: byLength(3, 6),
    natoMode: NatoMode.spell,
    challenge: true,
    rounds: 8,
  );

  final decodings = [
    ('Decode words', byLength(3, 4), null),
    ('Decode words 2', byLength(5, 7), null),
    ('Decode callsigns', const <String>[], (Random r) => randomCallsign(r)),
  ];
  for (final (title, pool, gen) in decodings) {
    b.add(
      section: 'Decoding',
      title: title,
      pool: pool,
      generator: gen,
      natoMode: NatoMode.decode,
      rounds: 8,
    );
  }
  b.add(
    section: 'Decoding',
    title: 'Challenge',
    pool: const [],
    generator: (r) => r.nextBool()
        ? randomCallsign(r)
        : letterWords[r.nextInt(letterWords.length)],
    natoMode: NatoMode.decode,
    challenge: true,
    rounds: 8,
  );
  return b.levels;
}

final Map<Track, List<Level>> courseLevels = {
  for (final t in Track.values) t: t == Track.nato ? _buildNato() : _build(t),
};

/// Section names in course order.
List<String> sectionsOf(Track t) =>
    courseLevels[t]!.map((l) => l.section).toSet().toList();
