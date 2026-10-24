import '../data/codes.dart';
import '../l10n/strings.dart';
import 'qso_engine.dart';

/// One explained token from a CW line.
class GlossEntry {
  const GlossEntry(this.token, this.meaning);

  final String token;
  final String meaning;
}

/// Plain tokens heard on air that aren't in the abbreviation chart.
const _extraEnglish = {
  'KN': 'Over, only you reply',
  'SK': 'End of contact',
  'BT': 'Break, new thought',
  'AR': 'End of message',
  'E': 'Dit dit: a friendly goodbye',
  'SIGS': 'Signals',
  'CLR': 'Clear',
  'QRZ': 'Who is calling me?',
  'TNX': 'Thanks',
  'HW': 'How (do you copy)?',
};

const _extraPersian = {
  'KN': 'تمام، فقط تو جواب بده',
  'SK': 'پایان ارتباط',
  'BT': 'وقفه، فکر تازه',
  'AR': 'پایان پیام',
  'E': 'دیت دیت: خداحافظی دوستانه',
  'SIGS': 'سیگنال‌ها',
  'CLR': 'صاف و بی‌مزاحمت',
  'QRZ': 'چه کسی صدایم می‌کند؟',
  'TNX': 'ممنون',
  'HW': 'چطور دریافت می‌کنی؟',
};

final Map<String, String> _chart = {
  for (final e in [...abbreviations, ...qCodes]) e.code: e.meaning,
  for (final e in prosignEntries) e.code: e.meaning,
};

/// Explains every known abbreviation, report and callsign in [line], in the
/// order they appear and without repeats.
List<GlossEntry> glossLine(String line, S s, {QsoSession? session}) {
  final out = <GlossEntry>[];
  final seen = <String>{};
  for (final raw in line.toUpperCase().split(RegExp(r'\s+'))) {
    final token = raw.replaceAll(RegExp(r'[?,.!]'), '');
    if (token.isEmpty || !seen.add(token)) continue;
    final meaning = _meaning(token, s, session);
    if (meaning != null) out.add(GlossEntry(token, meaning));
  }
  return out;
}

String? _meaning(String token, S s, QsoSession? session) {
  if (session != null) {
    if (token == session.theirCall) return s.qsoTheirCallsign;
    if (token == session.myCall) return s.qsoYourCallsign;
  }
  if (isValidRst(token)) {
    final rst = normalizeRst(token);
    return s.rstMeaning(
      int.parse(rst[0]),
      int.parse(rst[1]),
      rst.length > 2 ? int.parse(rst[2]) : null,
      shorthand: token == '5NN',
    );
  }
  final english = _chart[token] ?? _chart['<$token>'] ?? _extraEnglish[token];
  if (english == null) return null;
  if (!s.fa) return english;
  return s.persianCodeMeaning(token) ??
      s.persianCodeMeaning('<$token>') ??
      _extraPersian[token] ??
      english;
}
