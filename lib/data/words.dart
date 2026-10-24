import 'dart:math';

import 'word_bank.dart';

/// Common English words plus everyday ham-radio abbreviations and Q-codes.
const List<String> practiceWords = [
  'THE', 'AND', 'FOR', 'ARE', 'BUT', 'NOT', 'YOU', 'ALL', 'ANY', 'CAN',
  'HAD', 'HER', 'WAS', 'ONE', 'OUR', 'OUT', 'DAY', 'GET', 'HAS', 'HIM',
  'HIS', 'HOW', 'MAN', 'NEW', 'NOW', 'OLD', 'SEE', 'TWO', 'WAY', 'WHO',
  'BOY', 'DID', 'ITS', 'LET', 'PUT', 'SAY', 'SHE', 'TOO', 'USE', 'SUN',
  'RAIN', 'WIND', 'TIME', 'NAME', 'WORK', 'HOME', 'GOOD', 'MAKE', 'LIKE',
  'JUST', 'KNOW', 'TAKE', 'YEAR', 'SOME', 'THEM', 'THAN', 'THEN', 'LOOK',
  'ONLY', 'COME', 'OVER', 'ALSO', 'BACK', 'WELL', 'EVEN', 'WANT', 'GIVE',
  'MOST', 'MORSE', 'RADIO', 'SIGNAL', 'WATER', 'LIGHT', 'SOUND', 'SPEED',
  'ANTENNA', 'STATION', 'WEATHER', 'POWER', 'KEY', 'TONE', 'CODE',
  // Ham radio abbreviations
  'CQ', 'DE', 'RST', 'QTH', 'QSL', 'QRZ', 'QRM', 'QRN', 'QSB', 'QRS',
  'QRQ', 'QRP', 'QSO', 'TNX', 'TU', 'FB', 'OM', 'YL', 'GM', 'GA', 'GE',
  'ES', 'HR', 'UR', 'WX', 'ANT', 'RIG', 'PSE', 'AGN', 'BK', 'SK', 'KN',
  '73', '88', '5NN',
];

/// Plain English words for the course's word levels.
const List<String> englishWords = [
  // 2 letters
  'IT', 'IS', 'TO', 'IN', 'AT', 'ON', 'AN', 'BE', 'DO', 'GO', 'HE', 'ME',
  'MY', 'NO', 'OF', 'OR', 'SO', 'UP', 'US', 'WE', 'AM', 'AS', 'BY', 'IF',
  // 3 letters
  'THE', 'AND', 'FOR', 'ARE', 'BUT', 'NOT', 'YOU', 'ALL', 'ANY', 'CAN',
  'HAD', 'HER', 'WAS', 'ONE', 'OUR', 'OUT', 'DAY', 'GET', 'HAS', 'HIM',
  'HOW', 'MAN', 'NEW', 'NOW', 'OLD', 'SEE', 'TWO', 'WAY', 'WHO', 'SUN',
  // 4 letters
  'RAIN', 'WIND', 'TIME', 'NAME', 'WORK', 'HOME', 'GOOD', 'MAKE', 'LIKE',
  'JUST', 'KNOW', 'TAKE', 'YEAR', 'SOME', 'THEM', 'THAN', 'THEN', 'LOOK',
  'ONLY', 'COME', 'OVER', 'ALSO', 'BACK', 'WELL', 'EVEN', 'WANT', 'GIVE',
  // 5 letters
  'ABOUT', 'AFTER', 'AGAIN', 'BELOW', 'COULD', 'EVERY', 'FIRST', 'GREAT',
  'HOUSE', 'LARGE', 'LEARN', 'NEVER', 'OTHER', 'PLACE', 'RIGHT', 'SMALL',
  'STILL', 'THEIR', 'THERE', 'THESE', 'THING', 'THINK', 'THREE', 'UNDER',
  'WHERE', 'WHICH', 'WORLD', 'WOULD', 'WRITE', 'MORSE', 'RADIO', 'SOUND',
  // 6+ letters
  'BEFORE', 'FRIEND', 'LISTEN', 'LETTER', 'NUMBER', 'PEOPLE', 'SHOULD',
  'SIMPLE', 'SUMMER', 'WINTER', 'BETTER', 'ALWAYS', 'AROUND', 'CHANGE',
  'FAMILY', 'SCHOOL', 'SPRING', 'STRONG', 'ANTENNA', 'STATION', 'WEATHER',
  'SIGNAL', 'PRACTICE', 'TELEGRAPH',
];

/// Every practice word, deduplicated: curated words, Basic English,
/// frequency-ranked common words and radio vocabulary.
final List<String> allWords = {
  ...englishWords,
  ...basicEnglishWords,
  ...commonWords,
  ...radioWords,
}.toList();

/// Words made only from [chars]. Falls back to random five-character groups
/// (the classic Koch drill) when too few real words qualify.
List<String> wordsFrom(Iterable<String> chars, {Random? random, int min = 8}) {
  final set = chars.toSet();
  final matches = {
    ...practiceWords,
    ...allWords,
  }.where((w) => w.split('').every(set.contains)).toList();
  if (matches.length >= min) return matches;
  final r = random ?? Random();
  final pool = set.toList();
  return [
    ...matches,
    for (var i = 0; i < 30; i++)
      List.generate(5, (_) => pool[r.nextInt(pool.length)]).join(),
  ];
}
