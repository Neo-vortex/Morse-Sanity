import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../copy/voice.dart';
import '../course/rewards.dart';
import '../course/session_config.dart';
import '../morse/morse_code.dart';
import '../services/morse_player.dart';
import '../theme/app_theme.dart';
import '../widgets/dit.dart';
import '../widgets/morse_keyboard.dart';
import '../widgets/morse_pattern.dart';
import '../widgets/motion.dart';
import '../widgets/session_chrome.dart';
import '../widgets/session_results.dart';
import '../l10n/strings.dart';

/// Listen to an item and answer on the on-screen keyboard.
class ReceiveSessionScreen extends StatefulWidget {
  const ReceiveSessionScreen({
    super.key,
    required this.config,
    this.onFinished,
    this.onNext,
    this.onRetry,
  });

  final SessionConfig config;

  /// Called with the results; may return a message for the results page.
  final String? Function(List<RoundResult> results)? onFinished;
  final VoidCallback? onNext;

  /// Replaces the built-in retry (e.g. to rebuild with fresh settings).
  final VoidCallback? onRetry;

  @override
  State<ReceiveSessionScreen> createState() => _ReceiveSessionScreenState();
}

class _ReceiveSessionScreenState extends State<ReceiveSessionScreen> {
  final _random = Random();
  final _focusNode = FocusNode();
  late MorsePlayer _player;
  late List<List<String>> _rows;
  bool _started = false;

  final _results = <RoundResult>[];
  String _item = '';
  String _typed = '';
  int _combo = 0;
  String _line = '';
  DitMood _mood = DitMood.idle;
  int _confetti = 0;
  int _shake = 0;

  /// 0 none, 1 pattern of the item, 2 patterns on keys, 3 answer revealed.
  int _hintLevel = 0;
  RoundResult? _feedback;
  bool _finished = false;
  String? _message;
  SessionReward? _reward;

  Timer? _advanceTimer;
  Timer? _playTimer;
  Timer? _clockTimer;
  DateTime? _deadline;

  SessionConfig get _config => widget.config;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    _player = scope.player;
    if (!_started) {
      _started = true;
      _line = Voice.sessionStart(context.s, false);
      _rows = keyboardRows(
        scope.settings.keyboardLayout,
        digitsRow: _config.needsDigits,
        symbolRows: _config.needsSymbols,
        prosignRow: _config.needsProsigns,
        random: _random,
      );
      _nextRound();
    }
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _playTimer?.cancel();
    _clockTimer?.cancel();
    _focusNode.dispose();
    _player.stop();
    super.dispose();
  }

  void _nextRound() {
    _advanceTimer?.cancel();
    _clockTimer?.cancel();
    if (_results.length >= _config.rounds) {
      _finish();
      return;
    }
    var item = _config.nextItem(_random);
    if (item == _item) item = _config.nextItem(_random);
    setState(() {
      _item = item;
      _typed = '';
      _hintLevel = 0;
      _feedback = null;
      _deadline = null;
      _mood = DitMood.listening;
    });
    _playTimer = Timer(const Duration(milliseconds: 350), () {
      _play();
      final limit = _config.timeLimit;
      if (limit != null) {
        _deadline = DateTime.now().add(limit);
        _clockTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
          if (!mounted) return;
          if (DateTime.now().isAfter(_deadline!)) {
            _answer(_typed, timedOut: true);
          } else {
            setState(() {});
          }
        });
      }
    });
  }

  void _play() => _player.playText(_item, timing: _config.timing);

  void _onKey(String key) {
    if (_feedback != null) return;
    if (!_config.typed) {
      _answer(key);
    } else {
      setState(() => _typed += key);
    }
  }

  void _backspace() {
    if (_typed.isEmpty || _feedback != null) return;
    setState(() => _typed = _typed.substring(0, _typed.length - 1));
  }

  void _answer(String answer, {bool timedOut = false}) {
    if (_feedback != null || _finished) return;
    _clockTimer?.cancel();
    final normalized = answer.trim().replaceAll(RegExp(r'\s+'), ' ');
    final correct =
        !timedOut &&
        _hintLevel < 3 &&
        normalized.toUpperCase() == _item.toUpperCase();
    final scope = AppScope.of(context);
    if (!_config.typed) {
      scope.progress.record(_item, correct: correct);
    }
    _player.chime(correct: correct);
    if (scope.settings.hapticsEnabled) {
      correct ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
    }
    final result = RoundResult(
      item: _item,
      answer: timedOut
          ? '$normalized ${context.s.timeUpSuffix}'.trim()
          : normalized,
      correct: correct,
    );
    setState(() {
      _feedback = result;
      _results.add(result);
      if (correct) {
        _combo++;
        _mood = _combo >= 5 ? DitMood.celebrating : DitMood.happy;
        _line = Voice.correct(context.s, _combo);
        if (_combo % 5 == 0) _confetti++;
      } else {
        _combo = 0;
        _mood = DitMood.sad;
        _line = timedOut ? Voice.timeUp(context.s) : Voice.wrong(context.s);
        _shake++;
      }
    });
    if (correct) {
      _advanceTimer = Timer(const Duration(milliseconds: 900), _nextRound);
    } else {
      _play();
    }
  }

  void _hint() {
    if (!_config.hintsAllowed || _hintLevel >= 3) return;
    setState(() {
      _hintLevel++;
      _mood = DitMood.thinking;
      _line = context.s.hintLines[_hintLevel];
    });
  }

  void _finish() {
    _player.stop();
    final progress = AppScope.of(context).progress;
    final message = widget.onFinished?.call(_results);
    final xp = xpFor(_results, isLevel: _config.level != null);
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
      _message = null;
      _item = '';
      _combo = 0;
    });
    _nextRound();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _finished) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter) {
      // An empty Enter shouldn't count as a wrong answer.
      if (_feedback != null) {
        _nextRound();
      } else if (_typed.trim().isNotEmpty) {
        _answer(_typed);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space) {
      _config.typed && _feedback == null ? _onKey(' ') : _play();
      return KeyEventResult.handled;
    }
    final ch = event.character?.toUpperCase();
    if (ch != null && morseTable.containsKey(ch)) {
      _onKey(ch);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Focus(
        autofocus: true,
        focusNode: _focusNode,
        onKeyEvent: _onKeyEvent,
        child: SafeArea(
          child: _finished
              ? SessionResults(
                  config: _config,
                  results: _results,
                  message: _message,
                  reward: _reward,
                  onRetry: _retry,
                  onNext: widget.onNext,
                )
              : _buildRound(context),
        ),
      ),
    );
  }

  Widget _buildRound(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final feedback = _feedback;

    double? timeLeft;
    if (_deadline != null && _config.timeLimit != null && feedback == null) {
      final ms = _deadline!.difference(DateTime.now()).inMilliseconds;
      timeLeft = (ms / _config.timeLimit!.inMilliseconds).clamp(0.0, 1.0);
    }

    final keyColors = <String, Color>{};
    if (feedback != null && !_config.typed) {
      keyColors[feedback.item] = context.colors.success.withValues(alpha: 0.7);
      if (!feedback.correct && feedback.answer != feedback.item) {
        keyColors[feedback.answer] = scheme.error.withValues(alpha: 0.6);
      }
    }

    return Column(
      children: [
        SessionTopBar(
          progress: _results.length / _config.rounds,
          combo: _combo,
          timeLeft: timeLeft,
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildStage(theme, feedback),
            ),
          ),
        ),
        if (_config.typed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AnswerField(
              text: _typed,
              placeholder: context.s.typeWhatYouHear,
            ),
          ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, a) => SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.4),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: FadeTransition(opacity: a, child: child),
          ),
          child: feedback != null && !feedback.correct
              ? FeedbackPanel(
                  key: const ValueKey('feedback'),
                  correct: false,
                  title:
                      feedback.answer.isEmpty ||
                          feedback.answer.endsWith(context.s.timeUpSuffix)
                      ? context.s.timesUpTitle
                      : context.s.notQuite,
                  answer: _item,
                  onContinue: _nextRound,
                )
              : Padding(
                  key: const ValueKey('keyboard'),
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                  child: MorseKeyboard(
                    rows: _rows,
                    onKey: _onKey,
                    highlight: _config.characters,
                    showPatterns: _hintLevel >= 2,
                    enabled: feedback == null,
                    keyColors: keyColors,
                    onBackspace: _config.typed ? _backspace : null,
                    onSpace: _config.typed ? () => _onKey(' ') : null,
                    onSubmit: _config.typed ? () => _answer(_typed) : null,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildStage(ThemeData theme, RoundResult? feedback) {
    final scheme = theme.colorScheme;
    final showAnswer = (feedback?.correct ?? false) || _hintLevel >= 3;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MorseConfetti(
          trigger: _confetti,
          child: Shake(
            trigger: _shake,
            child: Pressable(
              onTap: _play,
              child: ValueListenableBuilder<bool>(
                valueListenable: _player.isPlaying,
                builder: (context, playing, _) => Dit(
                  size: 132,
                  mood: playing && feedback == null ? DitMood.listening : _mood,
                  signal: AppScope.of(context).settings.flashEnabled
                      ? _player.signal
                      : null,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (_line.isNotEmpty) SpeechBubble(text: _line, tailLeft: false),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RoundAction(
              icon: Icons.volume_up_rounded,
              tooltip: context.s.playAgain,
              onTap: _play,
              big: true,
            ),
            if (_config.hintsAllowed && feedback == null) ...[
              const SizedBox(width: 16),
              Badge(
                isLabelVisible: _hintLevel > 0,
                label: Text(context.s.n('$_hintLevel/3')),
                child: RoundAction(
                  icon: Icons.lightbulb_outline_rounded,
                  tooltip: context.s.hintTooltips[_hintLevel],
                  onTap: _hintLevel < 3 ? _hint : null,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: Column(
            children: [
              if (_hintLevel >= 1 || feedback != null)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    for (final word in patternsFor(_item))
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final p in word)
                            MorsePattern(p, size: 10, color: scheme.secondary),
                        ],
                      ),
                  ],
                ),
              if (showAnswer) ...[
                const SizedBox(height: 10),
                PopIn(
                  child: Text(
                    _item,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: feedback?.correct ?? false
                          ? context.colors.success
                          : null,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
