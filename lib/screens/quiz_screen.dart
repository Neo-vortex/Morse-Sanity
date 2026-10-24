import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../morse/morse_code.dart';
import '../services/morse_player.dart';
import '../widgets/morse_pattern.dart';
import '../widgets/signal_lamp.dart';
import '../l10n/strings.dart';

enum QuizPrompt {
  /// Hear the character, pick what it was.
  audio,

  /// See the dots and dashes, pick what they spell.
  visual,
}

/// A round-based character recognition drill.
class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.title,
    required this.characters,
    this.prompt = QuizPrompt.audio,
    this.rounds = 20,
    this.focusChar,
    this.onFinished,
    this.onRestart,
  });

  final String title;
  final List<String> characters;
  final QuizPrompt prompt;
  final int rounds;

  /// A character to ask about more often (e.g. the one just introduced).
  final String? focusChar;

  /// Called with the final accuracy; may return a message to show the user.
  final String? Function(double accuracy)? onFinished;

  /// Replaces the built-in "Go again" behaviour, e.g. to start a fresh
  /// lesson with a newly unlocked character.
  final VoidCallback? onRestart;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  static const _maxGridOptions = 16;
  static const _choiceCount = 8;

  final _random = Random();
  final _focusNode = FocusNode();

  int _round = 0;
  int _correct = 0;
  int _streak = 0;
  late String _target;
  late List<String> _options;
  String? _answer;
  String? _finishMessage;
  bool _finished = false;
  Timer? _advanceTimer;
  late MorsePlayer _player;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _player = AppScope.of(context).player;
    if (_round == 0) _nextRound();
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _focusNode.dispose();
    _player.stop();
    super.dispose();
  }

  String _pickTarget() {
    final progress = AppScope.of(context).progress;
    // Weak characters and the focus character come up more often.
    final weights = [
      for (final c in widget.characters)
        1.0 +
            (1 - progress.statsFor(c).accuracy) * 2 +
            (c == widget.focusChar ? 2.5 : 0),
    ];
    var roll = _random.nextDouble() * weights.reduce((a, b) => a + b);
    for (var i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll <= 0) return widget.characters[i];
    }
    return widget.characters.last;
  }

  void _nextRound() {
    _advanceTimer?.cancel();
    if (_round >= widget.rounds) {
      _finish();
      return;
    }
    var target = _pickTarget();
    if (_round > 0 && widget.characters.length > 1 && target == _target) {
      target = _pickTarget();
    }
    setState(() {
      _round++;
      _target = target;
      _answer = null;
      _options = _buildOptions(target);
    });
    if (widget.prompt == QuizPrompt.audio) _play();
  }

  List<String> _buildOptions(String target) {
    if (widget.characters.length <= _maxGridOptions) {
      return widget.characters;
    }
    final others = [...widget.characters]
      ..remove(target)
      ..shuffle(_random);
    return [target, ...others.take(_choiceCount - 1)]..shuffle(_random);
  }

  void _play() => _player.playText(_target);

  void _onAnswer(String choice) {
    if (_answer != null || _finished) return;
    final correct = choice == _target;
    final scope = AppScope.of(context);
    scope.progress.record(_target, correct: correct);
    if (scope.settings.hapticsEnabled) {
      correct ? HapticFeedback.selectionClick() : HapticFeedback.heavyImpact();
    }
    setState(() {
      _answer = choice;
      if (correct) {
        _correct++;
        _streak++;
      } else {
        _streak = 0;
      }
    });
    if (correct) {
      _advanceTimer = Timer(const Duration(milliseconds: 700), _nextRound);
    } else {
      _play();
    }
  }

  void _finish() {
    final accuracy = _correct / widget.rounds;
    setState(() {
      _finished = true;
      _finishMessage = widget.onFinished?.call(accuracy);
    });
  }

  void _restart() {
    setState(() {
      _round = 0;
      _correct = 0;
      _streak = 0;
      _finished = false;
      _finishMessage = null;
    });
    _nextRound();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      if (_answer != null) {
        _nextRound();
      } else if (widget.prompt == QuizPrompt.audio) {
        _play();
      }
      return KeyEventResult.handled;
    }
    final ch = event.character?.toUpperCase();
    if (ch != null && _options.contains(ch)) {
      _onAnswer(ch);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: SignalLamp(size: 20)),
          ),
        ],
      ),
      body: Focus(
        autofocus: true,
        focusNode: _focusNode,
        onKeyEvent: _onKey,
        child: SafeArea(child: _finished ? _buildResults() : _buildQuiz()),
      ),
    );
  }

  Widget _buildQuiz() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final answered = _answer != null;
    final wasCorrect = _answer == _target;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(
              context.s.round(_round, widget.rounds),
              style: theme.textTheme.labelLarge,
            ),
            const Spacer(),
            if (_streak >= 3)
              Chip(
                avatar: const Icon(Icons.local_fire_department, size: 18),
                label: Text(context.s.streakChip(_streak)),
                visualDensity: VisualDensity.compact,
              ),
            const SizedBox(width: 8),
            Text(
              context.s.correctCount(_correct),
              style: theme.textTheme.labelLarge,
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: _round / widget.rounds),
        const SizedBox(height: 24),
        Card(
          color: answered
              ? (wasCorrect ? Colors.green : scheme.error).withValues(
                  alpha: 0.15,
                )
              : null,
          child: SizedBox(
            height: 200,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (answered) ...[
                  Text(
                    _target,
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  MorsePattern(encodeChar(_target)!, size: 14),
                  const SizedBox(height: 12),
                  Text(
                    wasCorrect
                        ? context.s.correct
                        : context.s.youChose(_answer!),
                    style: theme.textTheme.titleMedium,
                  ),
                ] else if (widget.prompt == QuizPrompt.visual) ...[
                  MorsePattern(encodeChar(_target)!, size: 20),
                  const SizedBox(height: 16),
                  Text(
                    context.s.whatCharacter,
                    style: theme.textTheme.titleMedium,
                  ),
                ] else ...[
                  IconButton.filledTonal(
                    iconSize: 56,
                    tooltip: context.s.playAgain,
                    onPressed: _play,
                    icon: const Icon(Icons.volume_up),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.s.whatDidYouHear,
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in _options)
              SizedBox(
                width: 64,
                height: 64,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: !answered
                        ? null
                        : o == _target
                        ? Colors.green.withValues(alpha: 0.5)
                        : o == _answer
                        ? scheme.error.withValues(alpha: 0.5)
                        : null,
                  ),
                  onPressed: answered ? null : () => _onAnswer(o),
                  child: Text(o, style: theme.textTheme.headlineSmall),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        if (answered && !wasCorrect)
          Center(
            child: FilledButton.icon(
              onPressed: _nextRound,
              icon: const Icon(Icons.arrow_forward),
              label: Text(context.s.next),
            ),
          ),
      ],
    );
  }

  Widget _buildResults() {
    final theme = Theme.of(context);
    final pct = (_correct / widget.rounds * 100).round();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              pct >= 90 ? Icons.emoji_events : Icons.insights,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(context.s.percent(pct), style: theme.textTheme.displayMedium),
            Text(
              context.s.correctOfTotal(_correct, widget.rounds),
              style: theme.textTheme.titleMedium,
            ),
            if (_finishMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _finishMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ],
            const SizedBox(height: 32),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.s.done),
                ),
                FilledButton(
                  onPressed: widget.onRestart ?? _restart,
                  child: Text(context.s.goAgain),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
