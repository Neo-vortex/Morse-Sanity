import 'dart:math';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../course/course.dart';
import '../course/session_config.dart';
import '../data/codes.dart';
import '../data/word_bank.dart' as wb;
import '../data/words.dart';
import '../morse/morse_code.dart';
import '../morse/timing.dart';
import 'receive_session_screen.dart';
import 'send_session_screen.dart';
import '../l10n/strings.dart';

// The enum below has values named like these lists; alias them.
const _punctuation = punctuation;
const _sentences = sentences;
const _qCodes = qCodes;
const _abbreviations = abbreviations;
const _radioWords = wb.radioWords;

enum ChallengeContent {
  letters('Letters'),
  numbers('Numbers'),
  punctuation('Punctuation'),
  prosigns('Prosigns'),
  qCodes('Q-codes'),
  abbreviations('Abbreviations'),
  words('Words'),
  radioWords('Radio words'),
  callsigns('Callsigns'),
  sentences('Sentences');

  const ChallengeContent(this.section);

  /// Matching course section name, used for the translated label.
  final String section;

  bool get isCharacters => index <= ChallengeContent.prosigns.index;

  List<String> get items => switch (this) {
    letters => letterOrder.split(''),
    numbers => digits.split(''),
    punctuation => _punctuation.split(''),
    prosigns => [for (final p in prosignEntries) p.code],
    qCodes => [for (final q in _qCodes) q.code],
    abbreviations => [for (final a in _abbreviations) a.code],
    words => allWords,
    radioWords => _radioWords,
    callsigns => const [],
    sentences => _sentences,
  };
}

/// Build your own drill: content, length, time limit and speed.
class CustomChallengeScreen extends StatefulWidget {
  const CustomChallengeScreen({super.key});

  @override
  State<CustomChallengeScreen> createState() => _CustomChallengeScreenState();
}

class _CustomChallengeScreenState extends State<CustomChallengeScreen> {
  Track _track = Track.receive;
  final Set<ChallengeContent> _content = {ChallengeContent.letters};
  double _rounds = 20;
  int _timeLimit = 0;
  bool _customSpeed = false;
  double _charWpm = 20;
  double _effectiveWpm = 15;

  static const _timeOptions = [0, 3, 5, 10, 20, 30];

  SessionConfig _buildConfig() {
    final pool = [for (final c in _content) ...c.items];
    final callsigns = _content.contains(ChallengeContent.callsigns);
    String next(Random r) {
      final poolWeight = pool.length;
      if (callsigns && (pool.isEmpty || r.nextInt(poolWeight + 10) < 10)) {
        return randomCallsign(r);
      }
      return pool[r.nextInt(pool.length)];
    }

    final typed = callsigns || _content.any((c) => !c.isCharacters);
    return SessionConfig(
      title: context.s.customChallenge,
      track: _track,
      nextItem: next,
      rounds: _rounds.round(),
      typed: typed,
      characters: {
        for (final item in pool) ...tokenize(item),
        if (callsigns) ...'$letters$digits/'.split(''),
      },
      timeLimit: _timeLimit == 0 ? null : Duration(seconds: _timeLimit),
      hintsAllowed: _timeLimit == 0,
      timing: _customSpeed
          ? MorseTiming(
              charWpm: _charWpm.round(),
              effectiveWpm: _effectiveWpm.round(),
            )
          : null,
    );
  }

  void _start() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) {
          final config = _buildConfig();
          return config.track == Track.receive
              ? ReceiveSessionScreen(config: config)
              : SendSessionScreen(config: config);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = AppScope.of(context).settings;
    final s = context.s;
    if (!_customSpeed) {
      _charWpm = settings.charWpm.toDouble();
      _effectiveWpm = settings.effectiveWpm.toDouble();
    }
    return Scaffold(
      appBar: AppBar(title: Text(s.customChallenge)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<Track>(
            segments: [
              ButtonSegment(
                value: Track.receive,
                label: Text(s.receive),
                icon: const Icon(Icons.hearing),
              ),
              ButtonSegment(
                value: Track.send,
                label: Text(s.send),
                icon: const Icon(Icons.touch_app),
              ),
            ],
            selected: {_track},
            onSelectionChanged: (s) => setState(() => _track = s.first),
          ),
          const SizedBox(height: 20),
          Text(s.content, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final c in ChallengeContent.values)
                FilterChip(
                  label: Text(s.sectionName(c.section)),
                  selected: _content.contains(c),
                  onSelected: (on) => setState(() {
                    if (on) {
                      _content.add(c);
                    } else if (_content.length > 1) {
                      _content.remove(c);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(s.rounds(_rounds.round()), style: theme.textTheme.titleMedium),
          Slider(
            value: _rounds,
            min: 5,
            max: 100,
            divisions: 19,
            label: s.n(_rounds.round()),
            onChanged: (v) => setState(() => _rounds = v),
          ),
          Text(s.timeLimit, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final t in _timeOptions)
                ChoiceChip(
                  label: Text(t == 0 ? s.none : s.seconds(t)),
                  selected: _timeLimit == t,
                  onSelected: (_) => setState(() => _timeLimit = t),
                ),
            ],
          ),
          if (_timeLimit > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(s.hintsOffWithTime, style: theme.textTheme.bodySmall),
            ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.customSpeed),
            subtitle: Text(
              s.speedSummary(_charWpm.round(), _effectiveWpm.round()),
            ),
            value: _customSpeed,
            onChanged: (v) => setState(() => _customSpeed = v),
          ),
          if (_customSpeed) ...[
            Text(s.characterSpeed, style: theme.textTheme.labelLarge),
            Slider(
              value: _charWpm,
              min: 5,
              max: 50,
              divisions: 45,
              label: '${_charWpm.round()}',
              onChanged: (v) => setState(() {
                _charWpm = v;
                if (_effectiveWpm > v) _effectiveWpm = v;
              }),
            ),
            Text(s.effectiveSpeed, style: theme.textTheme.labelLarge),
            Slider(
              value: _effectiveWpm,
              min: 5,
              max: 50,
              divisions: 45,
              label: '${_effectiveWpm.round()}',
              onChanged: (v) =>
                  setState(() => _effectiveWpm = min(v, _charWpm)),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.play_arrow),
            label: Text(s.start),
          ),
        ],
      ),
    );
  }
}
