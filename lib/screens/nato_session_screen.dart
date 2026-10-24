import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../copy/voice.dart';
import '../course/course.dart';
import '../course/rewards.dart';
import '../course/session_config.dart';
import '../data/nato.dart';
import '../l10n/strings.dart';
import '../services/morse_player.dart';
import '../theme/app_theme.dart';
import '../widgets/dit.dart';
import '../widgets/motion.dart';
import '../widgets/session_chrome.dart';
import '../widgets/session_results.dart';

/// The kinds of exercise a NATO round can be.
enum _Kind { pickWord, pickSymbol, typeWord, spell, decode }

/// One round of a NATO level.
class NatoSessionScreen extends StatefulWidget {
  const NatoSessionScreen({
    super.key,
    required this.level,
    this.onFinished,
    this.onNext,
    this.onRetry,
  });

  final Level level;
  final String? Function(List<RoundResult> results)? onFinished;
  final VoidCallback? onNext;
  final VoidCallback? onRetry;

  @override
  State<NatoSessionScreen> createState() => _NatoSessionScreenState();
}

class _NatoSessionScreenState extends State<NatoSessionScreen> {
  final _random = Random();
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  late MorsePlayer _player;
  late SessionConfig _config;
  bool _started = false;

  /// Show the introduction cards before the first round.
  bool _intro = false;

  final _results = <RoundResult>[];
  late _Kind _kind;
  String _item = '';
  List<String> _options = [];
  final _spelled = <int>[]; // indexes into _bank
  List<String> _bank = [];
  String? _chosen;
  RoundResult? _feedback;
  int _combo = 0;
  String _line = '';
  DitMood _mood = DitMood.idle;
  int _shake = 0;
  int _confetti = 0;
  bool _finished = false;
  String? _message;
  SessionReward? _reward;
  Timer? _advance;
  Timer? _clock;
  DateTime? _deadline;

  Level get _level => widget.level;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _player = AppScope.of(context).player;
    if (!_started) {
      _started = true;
      _config = SessionConfig.fromLevel(_level);
      _intro =
          _level.natoMode == NatoMode.learn &&
          _level.newItems.isNotEmpty &&
          !_level.isChallenge;
      _line = Voice.sessionStart(context.s, false);
      if (!_intro) _nextRound();
    }
  }

  @override
  void dispose() {
    _advance?.cancel();
    _clock?.cancel();
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  _Kind _pickKind() {
    switch (_level.natoMode!) {
      case NatoMode.spell:
        return _Kind.spell;
      case NatoMode.decode:
        return _Kind.decode;
      case NatoMode.learn:
        // Recognise first, then recall from memory.
        if (_level.isChallenge) {
          return _random.nextInt(10) < 7 ? _Kind.typeWord : _Kind.pickSymbol;
        }
        if (_results.length < 4) return _Kind.pickWord;
        final roll = _random.nextInt(10);
        return roll < 4
            ? _Kind.pickWord
            : roll < 7
            ? _Kind.pickSymbol
            : _Kind.typeWord;
    }
  }

  void _nextRound() {
    _advance?.cancel();
    _clock?.cancel();
    if (_results.length >= _level.rounds) {
      _finish();
      return;
    }
    var item = _level.nextItem(_random);
    if (item == _item) item = _level.nextItem(_random);
    final kind = _pickKind();
    setState(() {
      _intro = false;
      _item = item;
      _kind = kind;
      _chosen = null;
      _feedback = null;
      _mood = DitMood.thinking;
      _spelled.clear();
      _input.clear();
      _options = _buildOptions(kind, item);
      _bank = kind == _Kind.spell ? _buildBank(item) : const [];
    });
    if (kind == _Kind.typeWord || kind == _Kind.decode) {
      _inputFocus.requestFocus();
    }
    final limit = _level.timeLimit;
    if (limit != null) {
      _deadline = DateTime.now().add(limit);
      _clock = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted) return;
        if (DateTime.now().isAfter(_deadline!)) {
          _answer('', timedOut: true);
        } else {
          setState(() {});
        }
      });
    } else {
      _deadline = null;
    }
  }

  /// Four choices: the right one plus distractors from the level, topped up
  /// from the whole alphabet.
  List<String> _buildOptions(_Kind kind, String item) {
    if (kind != _Kind.pickWord && kind != _Kind.pickSymbol) return const [];
    final digits = RegExp(r'\d').hasMatch(item);
    final everything = digits ? natoDigits : natoLetters;
    final pool = {
      ..._level.pool.where((p) => p != item),
      ...everything.map((e) => e.symbol).where((p) => p != item),
    }.toList();
    final others = [...pool.take(_level.pool.length)]..shuffle(_random);
    final extra = [...pool.skip(_level.pool.length)]..shuffle(_random);
    final picks = [...others, ...extra].take(3).toList();
    final symbols = [item, ...picks]..shuffle(_random);
    return kind == _Kind.pickWord
        ? [for (final s in symbols) natoBySymbol[s]!.word]
        : symbols;
  }

  /// Code words for the item, plus a few decoys, shuffled.
  List<String> _buildBank(String item) {
    final words = natoSpell(item).split(' ');
    final decoys =
        [
            ...natoLetters,
            ...natoDigits,
          ].map((e) => e.word).where((w) => !words.contains(w)).toList()
          ..shuffle(_random);
    return [...words, ...decoys.take(min(4, max(2, words.length ~/ 2)))]
      ..shuffle(_random);
  }

  String get _expected => switch (_kind) {
    _Kind.pickWord || _Kind.typeWord => natoBySymbol[_item]!.word,
    _Kind.pickSymbol => _item,
    _Kind.spell => natoSpell(_item),
    _Kind.decode => _item,
  };

  /// What the round asked about, as shown on the results page.
  String get _display => switch (_kind) {
    _Kind.pickWord || _Kind.typeWord => '$_item → $_expected',
    _Kind.pickSymbol => '${natoBySymbol[_item]!.word} → $_item',
    _Kind.spell => '$_item → ${natoSpell(_item)}',
    _Kind.decode => '${natoSpell(_item)} → $_item',
  };

  bool _isCorrect(String answer) {
    final a = answer.trim().toUpperCase();
    return switch (_kind) {
      _Kind.pickWord || _Kind.typeWord => natoMatches(_item, a),
      _Kind.pickSymbol => a == _item,
      _Kind.spell => natoRead(a) == _item,
      _Kind.decode => a.replaceAll(' ', '') == _item,
    };
  }

  void _answer(String answer, {bool timedOut = false}) {
    if (_feedback != null || _finished) return;
    _clock?.cancel();
    final s = context.s;
    final correct = !timedOut && _isCorrect(answer);
    final scope = AppScope.of(context);
    _player.chime(correct: correct);
    if (scope.settings.hapticsEnabled) {
      correct ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
    }
    final result = RoundResult(
      item: _display,
      answer: timedOut ? s.timeUpSuffix : answer.trim().toUpperCase(),
      correct: correct,
    );
    setState(() {
      _chosen = answer;
      _feedback = result;
      _results.add(result);
      if (correct) {
        _combo++;
        _mood = _combo >= 5 ? DitMood.celebrating : DitMood.happy;
        _line = Voice.correct(s, _combo);
        if (_combo % 5 == 0) _confetti++;
      } else {
        _combo = 0;
        _mood = DitMood.sad;
        _line = timedOut ? Voice.timeUp(s) : Voice.wrong(s);
        _shake++;
      }
    });
    if (correct) {
      _advance = Timer(const Duration(milliseconds: 900), _nextRound);
    }
  }

  void _tapBank(int i) {
    if (_feedback != null || _spelled.contains(i)) return;
    setState(() => _spelled.add(i));
    final target = natoSpell(_item).split(' ').length;
    if (_spelled.length == target) {
      _answer(_spelled.map((j) => _bank[j]).join(' '));
    }
  }

  void _finish() {
    final progress = AppScope.of(context).progress;
    final message = widget.onFinished?.call(_results);
    final xp = xpFor(_results, isLevel: true);
    final extended = progress.addXp(xp);
    setState(() {
      _finished = true;
      _message = message;
      _reward = SessionReward(
        xp: xp,
        streakExtended: extended,
        streak: progress.streak,
      );
    });
  }

  void _retry() {
    if (widget.onRetry != null) {
      widget.onRetry!();
      return;
    }
    setState(() {
      _results.clear();
      _finished = false;
      _combo = 0;
    });
    _nextRound();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _finished
            ? SessionResults(
                config: _config,
                results: _results,
                message: _message,
                reward: _reward,
                onRetry: _retry,
                onNext: widget.onNext,
              )
            : _intro
            ? _Intro(level: _level, onStart: _nextRound)
            : _buildRound(context),
      ),
    );
  }

  Widget _buildRound(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final feedback = _feedback;
    double? timeLeft;
    if (_deadline != null && _level.timeLimit != null && feedback == null) {
      final ms = _deadline!.difference(DateTime.now()).inMilliseconds;
      timeLeft = (ms / _level.timeLimit!.inMilliseconds).clamp(0.0, 1.0);
    }
    final question = switch (_kind) {
      _Kind.pickWord => s.natoPickWord,
      _Kind.pickSymbol => s.natoPickSymbol,
      _Kind.typeWord => s.natoTypeWord,
      _Kind.spell => s.natoSpell,
      _Kind.decode => s.natoDecode,
    };

    return Column(
      children: [
        SessionTopBar(
          progress: _results.length / _level.rounds,
          combo: _combo,
          timeLeft: timeLeft,
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  MorseConfetti(
                    trigger: _confetti,
                    child: Shake(
                      trigger: _shake,
                      child: Dit(size: 84, mood: _mood),
                    ),
                  ),
                  SpeechBubble(
                    text: feedback == null ? question : _line,
                    tailLeft: false,
                  ),
                  const SizedBox(height: 18),
                  _Prompt(kind: _kind, item: _item),
                  const SizedBox(height: 18),
                  if (_kind == _Kind.spell) _buildSpelled(theme),
                ],
              ),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: feedback != null && !feedback.correct
              ? FeedbackPanel(
                  key: const ValueKey('feedback'),
                  correct: false,
                  title: s.notQuite,
                  answer: _expected,
                  morse: false,
                  onContinue: _nextRound,
                )
              : Padding(
                  key: ValueKey('answer-$_kind-$_item'),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                  child: _buildAnswer(context),
                ),
        ),
      ],
    );
  }

  Widget _buildSpelled(ThemeData theme) {
    final scheme = theme.colorScheme;
    final target = natoSpell(_item).split(' ').length;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant, width: 2),
      ),
      child: Wrap(
        textDirection: TextDirection.ltr,
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final i in _spelled)
            Pressable(
              onTap: _feedback == null
                  ? () => setState(() => _spelled.remove(i))
                  : null,
              child: _WordChip(text: _bank[i], filled: true),
            ),
          for (var k = _spelled.length; k < target; k++)
            const _WordChip(text: '', filled: false),
        ],
      ),
    );
  }

  Widget _buildAnswer(BuildContext context) {
    final s = context.s;
    final scheme = Theme.of(context).colorScheme;
    final colors = context.colors;
    final feedback = _feedback;
    switch (_kind) {
      case _Kind.pickWord:
      case _Kind.pickSymbol:
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.6,
          children: [
            for (final o in _options)
              _OptionTile(
                text: o,
                big: _kind == _Kind.pickSymbol,
                state: feedback == null
                    ? null
                    : o == _expected
                    ? colors.success
                    : o == _chosen
                    ? scheme.error
                    : null,
                onTap: feedback == null ? () => _answer(o) : null,
              ),
          ],
        );
      case _Kind.typeWord:
      case _Kind.decode:
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                focusNode: _inputFocus,
                enabled: feedback == null,
                textDirection: TextDirection.ltr,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: (v) => _answer(v),
                style: const TextStyle(fontFamily: monoFont, fontSize: 18),
                decoration: InputDecoration(
                  hintText: _kind == _Kind.typeWord
                      ? s.natoTypeHint
                      : s.natoDecodeHint,
                  filled: true,
                  fillColor: scheme.surfaceContainerLowest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 120,
              child: ChunkyButton(
                label: s.check,
                height: 52,
                onPressed: feedback == null ? () => _answer(_input.text) : null,
              ),
            ),
          ],
        );
      case _Kind.spell:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              textDirection: TextDirection.ltr,
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _bank.length; i++)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _spelled.contains(i) ? 0.25 : 1,
                    child: Pressable(
                      onTap: feedback == null && !_spelled.contains(i)
                          ? () => _tapBank(i)
                          : null,
                      child: _WordChip(
                        text: _bank[i],
                        filled: false,
                        bank: true,
                      ),
                    ),
                  ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: _spelled.isEmpty || feedback != null
                    ? null
                    : () => setState(() => _spelled.removeLast()),
                icon: const Icon(Icons.undo_rounded),
                label: Text(s.undo),
              ),
            ),
          ],
        );
    }
  }
}

/// The question: a big character, a code word, or a word to spell/decode.
class _Prompt extends StatelessWidget {
  const _Prompt({required this.kind, required this.item});

  final _Kind kind;
  final String item;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entry = natoBySymbol[item];
    final Widget content = switch (kind) {
      _Kind.pickWord || _Kind.typeWord => Text(
        item,
        style: theme.textTheme.displayLarge?.copyWith(
          fontFamily: displayFont,
          fontWeight: FontWeight.w700,
        ),
      ),
      _Kind.pickSymbol => Column(
        children: [
          Text(
            entry!.word,
            textDirection: TextDirection.ltr,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontFamily: monoFont,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            s.fa ? '${entry.say} · ${entry.sayFa}' : entry.say,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      _Kind.spell => Text(
        item,
        textDirection: TextDirection.ltr,
        style: theme.textTheme.displaySmall?.copyWith(
          fontFamily: monoFont,
          letterSpacing: 4,
        ),
      ),
      _Kind.decode => Wrap(
        textDirection: TextDirection.ltr,
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final w in natoSpell(item).split(' '))
            _WordChip(text: w, filled: true),
        ],
      ),
    };
    return PopIn(key: ValueKey('$kind-$item'), child: content);
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.text,
    required this.big,
    required this.state,
    required this.onTap,
  });

  final String text;
  final bool big;

  /// Feedback colour after answering.
  final Color? state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final face =
        state?.withValues(alpha: 0.18) ?? scheme.surfaceContainerLowest;
    final border = state ?? scheme.outlineVariant;
    return Pressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: face,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border, width: 2),
          boxShadow: [BoxShadow(color: border, offset: const Offset(0, 4))],
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          textDirection: TextDirection.ltr,
          style: big
              ? theme.textTheme.headlineMedium?.copyWith(
                  fontFamily: displayFont,
                )
              : theme.textTheme.titleMedium?.copyWith(fontFamily: monoFont),
        ),
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  const _WordChip({
    required this.text,
    required this.filled,
    this.bank = false,
  });

  final String text;
  final bool filled;
  final bool bank;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final empty = text.isEmpty;
    return Container(
      constraints: const BoxConstraints(minWidth: 56),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: empty
            ? Colors.transparent
            : filled
            ? scheme.primaryContainer
            : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: empty ? scheme.outlineVariant : scheme.outline,
          width: empty ? 1.5 : 1.5,
        ),
        boxShadow: bank
            ? [
                BoxShadow(
                  color: scheme.outlineVariant,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Text(
        empty ? ' ' : text,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        style: TextStyle(
          fontFamily: monoFont,
          fontWeight: FontWeight.w500,
          color: filled ? scheme.onPrimaryContainer : scheme.onSurface,
        ),
      ),
    );
  }
}

/// "Meet your new code words" cards shown before a learning level.
class _Intro extends StatelessWidget {
  const _Intro({required this.level, required this.onStart});

  final Level level;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: IconButton(
            tooltip: s.quit,
            icon: const Icon(Icons.close_rounded, size: 28),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            children: [
              Row(
                children: [
                  const Dit(size: 72, mood: DitMood.happy),
                  const SizedBox(width: 8),
                  Expanded(child: SpeechBubble(text: s.natoMeetBody)),
                ],
              ),
              const SizedBox(height: 16),
              Text(s.natoMeetTitle, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              for (var i = 0; i < level.newItems.length; i++)
                PopIn(
                  delay: Duration(milliseconds: 120 * i),
                  child: _IntroCard(entry: natoBySymbol[level.newItems[i]]!),
                ),
              if (level.pool.length > level.newItems.length) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final p in level.pool)
                      if (!level.newItems.contains(p))
                        Chip(
                          label: Text(
                            '$p · ${natoBySymbol[p]!.word}',
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(fontFamily: monoFont),
                          ),
                          backgroundColor: scheme.surfaceContainer,
                        ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: ChunkyButton(
            label: s.start,
            icon: Icons.play_arrow_rounded,
            onPressed: onStart,
          ),
        ),
      ],
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.entry});

  final NatoEntry entry;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Text(
              entry.symbol,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: scheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.word,
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontFamily: monoFont,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  '${s.sayItLikeThis}: ${entry.say}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (s.fa)
                  Text(
                    entry.sayFa,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.secondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
