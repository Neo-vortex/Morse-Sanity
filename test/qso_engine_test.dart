import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:morse_sanity/l10n/strings.dart';
import 'package:morse_sanity/morse/morse_code.dart';
import 'package:morse_sanity/qso/glossary.dart';
import 'package:morse_sanity/qso/qso_engine.dart';

const _session = QsoSession(
  myCall: 'K2ABC',
  theirCall: 'DL1XYZ',
  name: 'HANS',
  qth: 'BERLIN',
  rig: 'K3',
  wx: 'SUNNY',
  rst: '579',
  condition: BandCondition.lightQsb,
);

QsoEngine _engine({int max = 5, int seed = 1}) =>
    QsoEngine(session: _session, random: Random(seed), maxExchanges: max);

void main() {
  group('RST', () {
    test('accepts valid reports and 5NN', () {
      for (final r in ['599', '579', '59', '11', '339', '5nn', '5NN']) {
        expect(isValidRst(r), isTrue, reason: r);
      }
    });

    test('rejects invalid reports', () {
      for (final r in ['699', '509', '590', '0', '5', '5999', 'ABC', '6NN']) {
        expect(isValidRst(r), isFalse, reason: r);
      }
    });

    test('normalises 5NN and extracts reports from text', () {
      expect(normalizeRst('5NN'), '599');
      expect(extractRst('R R UR RST 579 579 NAME BOB'), '579');
      expect(extractRst('TNX UR 5NN BK'), '5NN');
      expect(extractRst('QTH IS DENVER'), isNull);
    });

    test('generated sessions always carry a valid report', () {
      final r = Random(7);
      for (var i = 0; i < 200; i++) {
        final s = QsoSession.generate(r, myCall: 'K2ABC');
        expect(isValidRst(s.rst), isTrue, reason: s.rst);
        expect(s.theirCall, isNot('K2ABC'));
      }
    });
  });

  group('IntentMatcher', () {
    const m = IntentMatcher();

    test('recognises each intent', () {
      expect(
        m
            .classify('DL1XYZ DE K2ABC GE', theirCall: 'DL1XYZ')
            .has(QsoIntent.greeting),
        isTrue,
      );
      expect(m.classify('UR RST 599 599').has(QsoIntent.report), isTrue);
      expect(m.classify('HVY QSB HR').has(QsoIntent.conditions), isTrue);
      expect(m.classify('QRN HR TODAY').has(QsoIntent.conditions), isTrue);
      expect(m.classify('RIG HR IS KX2').has(QsoIntent.smalltalk), isTrue);
      expect(m.classify('TNX FER QSO 73 <SK>').has(QsoIntent.signOff), isTrue);
    });

    test('gibberish is unclear', () {
      expect(m.classify('XQZ PLMB').isUnclear, isTrue);
      expect(m.classify('   ').isUnclear, isTrue);
    });
  });

  group('QsoEngine', () {
    test('opens with a CQ that contains their call', () {
      final e = _engine();
      final cq = e.start();
      expect(cq, startsWith('CQ'));
      expect(cq, contains('DL1XYZ'));
      expect(e.state, QsoState.idle);
      expect(e.expected, QsoIntent.greeting);
    });

    test('walks through a full contact', () {
      final e = _engine()..start();

      final greet = e.reply('DL1XYZ DE K2ABC GE OM K');
      expect(e.state, QsoState.reportSent);
      expect(greet, contains('579'));
      expect(greet, contains('HANS'));
      expect(greet, contains('BERLIN'));

      final ack = e.reply('R R UR RST 5NN 5NN NAME ANN BK');
      expect(e.state, QsoState.reportReceived);
      expect(e.userRst, '599');
      expect(ack, contains('599'));

      e.reply('SUM QSB HR BT CONDX OK');
      expect(e.state, QsoState.conditions);

      e.reply('RIG HR IS KX2 ES WX COLD');
      expect(e.state, QsoState.smalltalk);
      expect(e.expected, QsoIntent.signOff);

      final last = e.reply('TNX FER QSO 73 <SK>');
      expect(e.isDone, isTrue);
      expect(last, contains('<SK>'));
    });

    test('unclear input gets QRZ/AGN and keeps the state', () {
      final e = _engine()..start();
      final r = e.reply('XQZ PLMB');
      expect(r, matches(RegExp(r'QRZ\?|AGN|RPT')));
      expect(e.state, QsoState.idle);
      expect(e.exchanges, 0);

      e.reply('DL1XYZ DE K2ABC GE');
      final again = e.reply('QTH IS DENVER'); // no report yet
      expect(again, matches(RegExp(r'QRZ\?|AGN|RPT')));
      expect(e.state, QsoState.reportSent);
    });

    test('a report must be a valid RST', () {
      final e = _engine()..start();
      e.reply('DL1XYZ DE K2ABC GE');
      e.reply('UR RST 699');
      expect(e.state, QsoState.reportSent);
    });

    test('the exchange cap forces a sign-off', () {
      final e = _engine(max: 2)..start();
      e.reply('DL1XYZ DE K2ABC GE');
      final wrap = e.reply('UR RST 599');
      expect(e.state, QsoState.signOff);
      expect(wrap, contains('73'));
      e.reply('73 TU <SK>');
      expect(e.isDone, isTrue);
    });

    test('signing off early ends the contact', () {
      final e = _engine()..start();
      e.reply('DL1XYZ DE K2ABC GE');
      e.reply('SRI MUST QRT 73');
      expect(e.isDone, isTrue);
      expect(() => e.reply('HELLO'), throwsStateError);
    });

    test('is deterministic for a given seed', () {
      List<String> run() {
        final e = _engine(seed: 42)..start();
        e.reply('DL1XYZ DE K2ABC GE');
        e.reply('UR 579');
        return [for (final m in e.log) m.text];
      }

      expect(run(), run());
    });

    test('every operator line is sendable Morse', () {
      final r = Random(3);
      for (var i = 0; i < 50; i++) {
        final e = QsoEngine(
          session: QsoSession.generate(r, myCall: 'K2ABC'),
          random: r,
        );
        final lines = [
          e.start(),
          e.reply('${e.session.theirCall} DE K2ABC GE'),
          e.reply('UR RST 599'),
          e.reply('QSB HR'),
          e.reply('RIG HR KX2'),
          e.reply('73 <SK>'),
        ];
        for (final line in lines) {
          expect(line, isNot(contains('{')), reason: line);
          for (final word in line.split(' ')) {
            for (final t in tokenize(word)) {
              expect(encodeToken(t), isNotNull, reason: '$t in $line');
            }
          }
        }
      }
    });
  });

  group('Glossary', () {
    final en = S.of(const Locale('en'));
    final fa = S.of(const Locale('fa'));

    test('explains abbreviations, reports and callsigns', () {
      final g = glossLine(
        'K2ABC DE DL1XYZ R TNX FER RPT 579 SUM QSB HR HW? BK',
        en,
        session: _session,
      );
      final byToken = {for (final e in g) e.token: e.meaning};
      expect(byToken['K2ABC'], en.qsoYourCallsign);
      expect(byToken['DL1XYZ'], en.qsoTheirCallsign);
      expect(byToken['579'], contains('readability 5'));
      expect(byToken['579'], contains('strength 7'));
      expect(byToken['QSB'], contains('fading'));
      expect(byToken['FER'], 'For');
      expect(byToken['HW'], isNotNull);
      expect(byToken.containsKey('SUM'), isTrue);
    });

    test('explains 5NN and prosigns', () {
      final g = glossLine('UR 5NN 73 <SK> KN', en);
      final byToken = {for (final e in g) e.token: e.meaning};
      expect(byToken['5NN'], contains('599'));
      expect(byToken['<SK>'], 'End of contact');
      expect(byToken['KN'], isNotNull);
    });

    test('speaks Persian too', () {
      final g = glossLine('QSB HR', fa);
      expect(g.first.meaning, 'سیگنالت ضعیف و قوی می‌شود');
    });

    test('coach examples drive a full contact', () {
      final e = _engine()..start();
      while (!e.isDone) {
        final examples = e.examples();
        expect(examples, isNotEmpty, reason: e.state.name);
        e.reply(examples.first);
      }
      expect(e.userRst, isNotNull);
    });
  });
}
