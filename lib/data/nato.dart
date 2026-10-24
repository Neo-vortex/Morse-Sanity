/// The ICAO/NATO radiotelephony spelling alphabet and figures.
library;

typedef NatoEntry = ({
  String symbol,
  String word,

  /// ICAO pronunciation respelling, stressed syllables in capitals.
  String say,

  /// The same pronunciation in Persian script.
  String sayFa,
});

const List<NatoEntry> natoLetters = [
  (symbol: 'A', word: 'ALFA', say: 'AL-fah', sayFa: 'آلفا'),
  (symbol: 'B', word: 'BRAVO', say: 'BRAH-voh', sayFa: 'براوو'),
  (symbol: 'C', word: 'CHARLIE', say: 'CHAR-lee', sayFa: 'چارلی'),
  (symbol: 'D', word: 'DELTA', say: 'DELL-tah', sayFa: 'دلتا'),
  (symbol: 'E', word: 'ECHO', say: 'ECK-oh', sayFa: 'اِکو'),
  (symbol: 'F', word: 'FOXTROT', say: 'FOKS-trot', sayFa: 'فاکس‌تروت'),
  (symbol: 'G', word: 'GOLF', say: 'GOLF', sayFa: 'گلف'),
  (symbol: 'H', word: 'HOTEL', say: 'hoh-TELL', sayFa: 'هوتل'),
  (symbol: 'I', word: 'INDIA', say: 'IN-dee-ah', sayFa: 'ایندیا'),
  (symbol: 'J', word: 'JULIETT', say: 'JEW-lee-ett', sayFa: 'جولیِت'),
  (symbol: 'K', word: 'KILO', say: 'KEY-loh', sayFa: 'کیلو'),
  (symbol: 'L', word: 'LIMA', say: 'LEE-mah', sayFa: 'لیما'),
  (symbol: 'M', word: 'MIKE', say: 'MIKE', sayFa: 'مایک'),
  (symbol: 'N', word: 'NOVEMBER', say: 'no-VEM-ber', sayFa: 'نوامبر'),
  (symbol: 'O', word: 'OSCAR', say: 'OSS-cah', sayFa: 'اسکار'),
  (symbol: 'P', word: 'PAPA', say: 'pah-PAH', sayFa: 'پاپا'),
  (symbol: 'Q', word: 'QUEBEC', say: 'keh-BECK', sayFa: 'کِبِک'),
  (symbol: 'R', word: 'ROMEO', say: 'ROW-me-oh', sayFa: 'رومیو'),
  (symbol: 'S', word: 'SIERRA', say: 'see-AIR-rah', sayFa: 'سی‌یرا'),
  (symbol: 'T', word: 'TANGO', say: 'TANG-go', sayFa: 'تانگو'),
  (symbol: 'U', word: 'UNIFORM', say: 'YOU-nee-form', sayFa: 'یونیفرم'),
  (symbol: 'V', word: 'VICTOR', say: 'VIK-tah', sayFa: 'ویکتور'),
  (symbol: 'W', word: 'WHISKEY', say: 'WISS-key', sayFa: 'ویسکی'),
  (symbol: 'X', word: 'XRAY', say: 'ECKS-ray', sayFa: 'اِکس‌ری'),
  (symbol: 'Y', word: 'YANKEE', say: 'YANG-key', sayFa: 'یَنکی'),
  (symbol: 'Z', word: 'ZULU', say: 'ZOO-loo', sayFa: 'زولو'),
];

const List<NatoEntry> natoDigits = [
  (symbol: '0', word: 'ZERO', say: 'ZE-ro', sayFa: 'زیرو'),
  (symbol: '1', word: 'ONE', say: 'WUN', sayFa: 'وان'),
  (symbol: '2', word: 'TWO', say: 'TOO', sayFa: 'تو'),
  (symbol: '3', word: 'THREE', say: 'TREE', sayFa: 'تری'),
  (symbol: '4', word: 'FOUR', say: 'FOW-er', sayFa: 'فاوِر'),
  (symbol: '5', word: 'FIVE', say: 'FIFE', sayFa: 'فایف'),
  (symbol: '6', word: 'SIX', say: 'SIX', sayFa: 'سیکس'),
  (symbol: '7', word: 'SEVEN', say: 'SEV-en', sayFa: 'سِوِن'),
  (symbol: '8', word: 'EIGHT', say: 'AIT', sayFa: 'اِیت'),
  (symbol: '9', word: 'NINE', say: 'NIN-er', sayFa: 'ناینِر'),
];

final Map<String, NatoEntry> natoBySymbol = {
  for (final e in [...natoLetters, ...natoDigits]) e.symbol: e,
};

final Map<String, String> _symbolByWord = {
  for (final e in [...natoLetters, ...natoDigits]) e.word: e.symbol,
  // Common spellings that are just as good on air.
  'ALPHA': 'A',
  'JULIET': 'J',
  'X-RAY': 'X',
  'WHISKY': 'W',
  'NINER': '9',
  'FIFE': '5',
  'TREE': '3',
};

/// The symbol a code word stands for, accepting common alternate spellings.
String? natoSymbolFor(String word) =>
    _symbolByWord[word.trim().toUpperCase()] ??
    _symbolByWord[word.trim().toUpperCase().replaceAll('-', '')];

/// True if [answer] is an acceptable code word for [symbol].
bool natoMatches(String symbol, String answer) =>
    natoSymbolFor(answer) == symbol.toUpperCase();

/// Spells [text] in code words, e.g. "K2" -> "KILO TWO".
String natoSpell(String text) => text
    .toUpperCase()
    .split('')
    .map((c) => natoBySymbol[c]?.word)
    .whereType<String>()
    .join(' ');

/// Reads code words back into plain text, or null if any word is unknown.
String? natoRead(String spoken) {
  final out = StringBuffer();
  for (final w in spoken.trim().toUpperCase().split(RegExp(r'\s+'))) {
    if (w.isEmpty) continue;
    final s = natoSymbolFor(w);
    if (s == null) return null;
    out.write(s);
  }
  return out.toString();
}
