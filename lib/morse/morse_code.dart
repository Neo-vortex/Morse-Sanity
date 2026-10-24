/// International Morse code table and text <-> Morse conversion.
library;

const Map<String, String> morseTable = {
  'A': '.-',
  'B': '-...',
  'C': '-.-.',
  'D': '-..',
  'E': '.',
  'F': '..-.',
  'G': '--.',
  'H': '....',
  'I': '..',
  'J': '.---',
  'K': '-.-',
  'L': '.-..',
  'M': '--',
  'N': '-.',
  'O': '---',
  'P': '.--.',
  'Q': '--.-',
  'R': '.-.',
  'S': '...',
  'T': '-',
  'U': '..-',
  'V': '...-',
  'W': '.--',
  'X': '-..-',
  'Y': '-.--',
  'Z': '--..',
  '0': '-----',
  '1': '.----',
  '2': '..---',
  '3': '...--',
  '4': '....-',
  '5': '.....',
  '6': '-....',
  '7': '--...',
  '8': '---..',
  '9': '----.',
  '.': '.-.-.-',
  ',': '--..--',
  '?': '..--..',
  "'": '.----.',
  '!': '-.-.--',
  '/': '-..-.',
  '(': '-.--.',
  ')': '-.--.-',
  '&': '.-...',
  ':': '---...',
  ';': '-.-.-.',
  '=': '-...-',
  '+': '.-.-.',
  '-': '-....-',
  '_': '..--.-',
  '"': '.-..-.',
  r'$': '...-..-',
  '@': '.--.-.',
};

final Map<String, String> _reverseTable = {
  for (final e in morseTable.entries) e.value: e.key,
};

const String letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const String digits = '0123456789';
const String punctuation = '.,?\'!/()&:;=+-_"\$@';

/// Character order used by the Koch method (as popularised by G4FON / LCWO).
/// Each lesson introduces the next character in this sequence.
const String kochOrder = 'KMURESNAPTLWI.JZ=FOY,VG5/Q92H38B?47C1D60X';

/// Procedural signals, sent as one run-together character. Written in text
/// as `<AR>`, `<SK>` etc.
const Map<String, String> prosigns = {
  'AR': '.-.-.',
  'SK': '...-.-',
  'BT': '-...-',
  'KN': '-.--.',
  'AS': '.-...',
  'CT': '-.-.-',
  'VE': '...-.',
  'BK': '-...-.-',
  'SOS': '...---...',
  'HH': '........',
};

final _tokenRegExp = RegExp(r'<([A-Z]+)>|\S');

/// Splits a word into sendable tokens: single characters and `<XX>`
/// prosigns. Whitespace is dropped.
List<String> tokenize(String word) => _tokenRegExp
    .allMatches(word.toUpperCase())
    .map((m) => m.group(0)!)
    .toList();

/// Returns the Morse pattern for a single character, or null if unknown.
String? encodeChar(String char) => morseTable[char.toUpperCase()];

/// Like [encodeChar] but also understands `<XX>` prosign tokens.
String? encodeToken(String token) {
  if (token.length > 2 && token.startsWith('<') && token.endsWith('>')) {
    return prosigns[token.substring(1, token.length - 1).toUpperCase()];
  }
  return encodeChar(token);
}

/// Returns the character for a Morse pattern such as `.-`, or null.
String? decodePattern(String pattern) => _reverseTable[pattern];

/// Morse patterns for each word of [text], e.g. `CQ DE` ->
/// `[['-.-.', '--.-'], ['-..', '.']]`. Unknown characters are skipped.
List<List<String>> patternsFor(String text) => text
    .trim()
    .split(RegExp(r'\s+'))
    .map((w) => tokenize(w).map(encodeToken).whereType<String>().toList())
    .where((w) => w.isNotEmpty)
    .toList();

/// Encodes text to Morse. Letters are separated by a single space and words
/// by ` / `. Unknown characters are skipped.
String encode(String text) =>
    patternsFor(text).map((w) => w.join(' ')).join(' / ');

/// Decodes Morse written with `.`/`-`, spaces between letters and `/` (or
/// three or more spaces) between words. Unknown patterns become `�`.
String decode(String morse) {
  final normalized = morse
      .replaceAll('·', '.')
      .replaceAll('•', '.')
      .replaceAll(RegExp('[−–—_]'), '-')
      .trim();
  if (normalized.isEmpty) return '';
  final words = normalized.split(RegExp(r'\s*/\s*|\s{3,}'));
  return words
      .where((w) => w.trim().isNotEmpty)
      .map(
        (w) => w
            .trim()
            .split(RegExp(r'\s+'))
            .map((p) => decodePattern(p) ?? '�')
            .join(),
      )
      .join(' ');
}
