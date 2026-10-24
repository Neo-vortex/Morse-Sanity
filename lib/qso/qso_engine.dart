import 'dart:math';

import '../data/codes.dart';
import '../data/cw_qso_templates.dart';

/// Where a simulated contact stands, from the other operator's side.
enum QsoState {
  /// They are calling CQ; waiting for the user to answer.
  idle,

  /// Greetings exchanged (transient: they reply with a report).
  greeting,

  /// They sent their report; waiting for the user's report.
  reportSent,

  /// They got the user's report and described conditions; waiting for the
  /// user's conditions comment.
  reportReceived,

  /// Conditions discussed; waiting for small talk (optional).
  conditions,

  /// Small talk done; waiting for the user's sign-off.
  smalltalk,

  /// They are signing off; waiting for the user's 73.
  signOff,

  /// Contact complete.
  done,
}

/// What a user message is trying to do.
enum QsoIntent { greeting, report, conditions, smalltalk, signOff, unclear }

/// Band conditions for the session; they colour the operator's phrasing and
/// the report they give.
enum BandCondition { clear, lightQsb, heavyQsb, qrm, qrn }

final _rstPattern = RegExp(r'^[1-5][1-9]([1-9])?$');

/// True for a valid RST report (readability 1–5, strength 1–9, optional
/// tone 1–9) or the contest shorthand 5NN.
bool isValidRst(String report) {
  final r = report.toUpperCase();
  return r == '5NN' || _rstPattern.hasMatch(r);
}

/// Expands "N" (cut number for 9) in shorthand reports: 5NN → 599.
String normalizeRst(String report) {
  final r = report.toUpperCase();
  return r == '5NN' ? '599' : r;
}

/// Finds the first valid RST report in [text], if any.
String? extractRst(String text) {
  for (final token in _tokens(text)) {
    if (isValidRst(token)) return token.toUpperCase();
  }
  return null;
}

List<String> _tokens(String text) => text
    .toUpperCase()
    .replaceAll(RegExp(r'[<>?,.!]'), ' ')
    .split(RegExp(r'\s+'))
    .where((t) => t.isNotEmpty)
    .toList();

/// The intents found in a message, plus any report it carried.
class IntentMatch {
  const IntentMatch(this.intents, {this.rst});

  final Set<QsoIntent> intents;
  final String? rst;

  bool has(QsoIntent i) => intents.contains(i);
  bool get isUnclear => intents.isEmpty;
}

/// Keyword and prosign matching; no language model involved.
class IntentMatcher {
  const IntentMatcher();

  static const _signOff = {
    '73',
    'SK',
    'GB',
    'CUL',
    'CUAGN',
    'BCNU',
    'GN',
    'QRT',
    'CL',
    'EE',
  };
  static const _conditions = {
    'QSB',
    'QRM',
    'QRN',
    'CONDX',
    'FADING',
    'NOISE',
    'STATIC',
    'CLR',
    'CLEAR',
    'QRK',
    'SIGS',
    'SIG',
  };
  static const _smalltalk = {
    'RIG',
    'ANT',
    'WX',
    'PWR',
    'WATTS',
    'W',
    'AGE',
    'TEMP',
    'DIPOLE',
    'YAGI',
    'VERTICAL',
    'SUNNY',
    'RAIN',
    'RAINY',
    'CLOUDY',
    'SNOW',
    'COLD',
    'WARM',
    'HOT',
    'WINDY',
    'KEY',
    'PADDLE',
    'BUG',
    'RETIRED',
    'WORK',
    'JOB',
    'YRS',
    'LICENSED',
    'OP',
  };
  static const _greeting = {
    'GM',
    'GA',
    'GE',
    'HI',
    'HELLO',
    'HELO',
    'TNX',
    'TKS',
    'TU',
    'DE',
    'CALL',
    'OM',
    'YL',
    'FB',
    'NAME',
    'QTH',
  };

  IntentMatch classify(String text, {String? theirCall}) {
    final tokens = _tokens(text);
    final set = <QsoIntent>{};
    final rst = extractRst(text);
    if (tokens.any(_signOff.contains)) set.add(QsoIntent.signOff);
    if (rst != null) set.add(QsoIntent.report);
    if (tokens.any(_conditions.contains)) set.add(QsoIntent.conditions);
    if (tokens.any(_smalltalk.contains)) set.add(QsoIntent.smalltalk);
    final call = theirCall?.toUpperCase();
    if (tokens.any(_greeting.contains) ||
        (call != null && tokens.contains(call))) {
      set.add(QsoIntent.greeting);
    }
    return IntentMatch(set, rst: rst);
  }
}

/// The simulated operator and the conditions for one contact.
class QsoSession {
  const QsoSession({
    required this.myCall,
    required this.theirCall,
    required this.name,
    required this.qth,
    required this.rig,
    required this.wx,
    required this.rst,
    required this.condition,
  });

  /// Builds a random but plausible session. Reports lean towards good ones
  /// and are dragged down by fading or noise.
  factory QsoSession.generate(Random r, {required String myCall}) {
    final condition = BandCondition.values[_weighted(r, const [4, 3, 2, 2, 2])];
    var readability = 5;
    var strength = 9 - _weighted(r, const [4, 4, 3, 2, 1]);
    switch (condition) {
      case BandCondition.clear:
      case BandCondition.lightQsb:
        break;
      case BandCondition.heavyQsb:
        strength = max(3, strength - 2);
      case BandCondition.qrm:
      case BandCondition.qrn:
        readability = r.nextInt(3) == 0 ? 4 : 5;
    }
    final rst = '$readability${strength}9';
    var theirCall = randomCallsign(r);
    if (theirCall == myCall) theirCall = randomCallsign(r);
    return QsoSession(
      myCall: myCall,
      theirCall: theirCall,
      name: qsoNames[r.nextInt(qsoNames.length)],
      qth: qsoPlaces[r.nextInt(qsoPlaces.length)],
      rig: qsoRigs[r.nextInt(qsoRigs.length)],
      wx: qsoWeather[r.nextInt(qsoWeather.length)],
      rst: rst,
      condition: condition,
    );
  }

  final String myCall;
  final String theirCall;
  final String name;
  final String qth;
  final String rig;
  final String wx;

  /// The report they give the user.
  final String rst;
  final BandCondition condition;

  static int _weighted(Random r, List<int> weights) {
    var roll = r.nextInt(weights.reduce((a, b) => a + b));
    for (var i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll < 0) return i;
    }
    return weights.length - 1;
  }
}

/// One line in the contact log.
class QsoMessage {
  const QsoMessage({required this.fromUser, required this.text});

  final bool fromUser;
  final String text;
}

/// Finite-state machine for a short CW contact. Pure Dart: feed it the
/// user's lines and it returns the other operator's replies.
class QsoEngine {
  QsoEngine({
    required this.session,
    Random? random,
    this.maxExchanges = 5,
    this.matcher = const IntentMatcher(),
  }) : _r = random ?? Random();

  final QsoSession session;
  final int maxExchanges;
  final IntentMatcher matcher;
  final Random _r;

  QsoState _state = QsoState.idle;
  int _exchanges = 0;
  String? _userRst;
  final List<QsoMessage> _log = [];

  QsoState get state => _state;
  int get exchanges => _exchanges;
  List<QsoMessage> get log => List.unmodifiable(_log);

  /// The report the user gave, normalised (5NN becomes 599).
  String? get userRst => _userRst;
  bool get isDone => _state == QsoState.done;

  /// What the other operator is waiting for, for UI hints.
  QsoIntent? get expected => switch (_state) {
    QsoState.idle => QsoIntent.greeting,
    QsoState.greeting || QsoState.reportSent => QsoIntent.report,
    QsoState.reportReceived => QsoIntent.conditions,
    QsoState.conditions => QsoIntent.smalltalk,
    QsoState.smalltalk || QsoState.signOff => QsoIntent.signOff,
    QsoState.done => null,
  };

  /// Example replies for what they're waiting for, for the coach.
  List<String> examples() {
    final key = expected?.name;
    if (key == null) return const [];
    return [for (final t in qsoUserExamples[key] ?? const <String>[]) _fill(t)];
  }

  /// Their opening CQ.
  String start() => _say(_fill(_pick(qsoCqTemplates)));

  /// Handles one user line and returns the other operator's reply.
  String reply(String userText) {
    if (_state == QsoState.done) {
      throw StateError('The QSO is already over.');
    }
    final text = userText.trim().toUpperCase();
    _log.add(QsoMessage(fromUser: true, text: text));
    final match = matcher.classify(text, theirCall: session.theirCall);

    // A 73 after the greeting ends the contact politely at any point.
    if (match.has(QsoIntent.signOff) && _state != QsoState.idle) {
      _exchanges++;
      _state = QsoState.done;
      return _say(_fill(_pick(qsoFinalTemplates)));
    }

    // Only lines that move the contact forward count as exchanges.
    final next = _advance(match);
    if (next == null) return _say(_pick(qsoUnclearTemplates));
    _exchanges++;

    // Keep it short: past the cap, they start wrapping up.
    if (_exchanges >= maxExchanges &&
        _state != QsoState.signOff &&
        _state != QsoState.done) {
      _state = QsoState.signOff;
      return _say(_fill(_pick(qsoWrapUpTemplates)));
    }
    return _say(next);
  }

  /// Ends the contact early (the user walked away).
  void abandon() => _state = QsoState.done;

  String? _advance(IntentMatch m) {
    switch (_state) {
      case QsoState.idle:
        if (!m.has(QsoIntent.greeting)) return null;
        _state = QsoState.greeting;
        // They answer the call and send their report straight away.
        _state = QsoState.reportSent;
        return _fill(_pick(qsoGreetingTemplates));
      case QsoState.greeting:
      case QsoState.reportSent:
        if (!m.has(QsoIntent.report) || m.rst == null) return null;
        _userRst = normalizeRst(m.rst!);
        _state = QsoState.reportReceived;
        return _fill(_pick(qsoReportReceivedTemplates));
      case QsoState.reportReceived:
        if (m.has(QsoIntent.conditions)) {
          _state = QsoState.conditions;
          return _fill(_pick(qsoConditionsTemplates));
        }
        // Skipping straight to small talk is fine too.
        if (m.has(QsoIntent.smalltalk)) {
          _state = QsoState.smalltalk;
          return _fill(_pick(qsoSmalltalkTemplates));
        }
        return null;
      case QsoState.conditions:
        if (!m.has(QsoIntent.smalltalk) &&
            !m.has(QsoIntent.conditions) &&
            !m.has(QsoIntent.greeting)) {
          return null;
        }
        _state = QsoState.smalltalk;
        return _fill(_pick(qsoSmalltalkTemplates));
      case QsoState.smalltalk:
        // More chat after small talk: they start to wrap up.
        _state = QsoState.signOff;
        return _fill(_pick(qsoWrapUpTemplates));
      case QsoState.signOff:
        // They already said 73; a friendly line from the user ends it.
        _state = QsoState.done;
        return _fill(_pick(qsoFinalTemplates));
      case QsoState.done:
        return null;
    }
  }

  String _say(String text) {
    _log.add(QsoMessage(fromUser: false, text: text));
    return text;
  }

  T _pick<T>(List<T> pool) => pool[_r.nextInt(pool.length)];

  String _fill(String template) {
    final phrases = qsoConditionPhrases[session.condition.name]!;
    return template
        .replaceAll('{my_call}', session.myCall)
        .replaceAll('{their_call}', session.theirCall)
        .replaceAll('{rst}', session.rst)
        .replaceAll('{user_rst}', _userRst ?? '')
        .replaceAll('{name}', session.name)
        .replaceAll('{qth}', session.qth)
        .replaceAll('{rig}', session.rig)
        .replaceAll('{wx}', session.wx)
        .replaceAll('{condition}', _pick(phrases));
  }
}
