import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../copy/voice.dart';
import '../course/rewards.dart';
import '../course/session_config.dart';
import '../morse/keyer.dart';
import '../morse/morse_code.dart';
import '../services/morse_player.dart';
import '../services/settings.dart';
import '../theme/app_theme.dart';
import '../widgets/dit.dart';
import '../widgets/key_pad.dart';
import '../widgets/morse_pattern.dart';
import '../widgets/motion.dart';
import '../widgets/session_chrome.dart';
import '../widgets/session_results.dart';
import '../l10n/strings.dart';

/// The character a pattern stands for, including prosigns.
String _labelFor(String pattern, {String? expectedToken}) {
  final expected = expectedToken == null ? null : encodeToken(expectedToken);
  if (expectedToken != null && expected == pattern) return expectedToken;
  return decodePattern(pattern) ??
      prosigns.entries
          .where((e) => e.value == pattern)
          .map((e) => '<${e.key}>')
          .firstOrNull ??
      '�';
}

/// Send items on the selected telegraph key. With [config] null the screen
/// is a free keying pad that shows whatever you send.
class SendSessionScreen extends StatefulWidget {
  const SendSessionScreen({
    super.key,
    this.config,
    this.onFinished,
    this.onNext,
    this.onRetry,
  });

  final SessionConfig? config;
  final String? Function(List<RoundResult> results)? onFinished;
  final VoidCallback? onNext;
  final VoidCallback? onRetry;

  @override
  State<SendSessionScreen> createState() => _SendSessionScreenState();
}

class _SendSessionScreenState extends State<SendSessionScreen> {
  final _random = Random();
  final _focusNode = FocusNode();
  late MorsePlayer _player;
  late Settings _settings;
  Keyer? _keyer;
  KeyType? _keyerType;
  bool _started = false;

  final _held = <Contact>{};
  final _results = <RoundResult>[];
  String _item = '';
  List<String> _targetTokens = [];
  final _sent = <String>[];
  String _pending = '';
  String _freeText = '';
  bool _showPattern = true;
  RoundResult? _feedback;
  bool _finished = false;
  String? _message;
  SessionReward? _reward;
  int _combo = 0;
  String _line = '';
  DitMood _mood = DitMood.idle;
  int _confetti = 0;
  int _shake = 0;
  Timer? _advanceTimer;
  Timer? _clockTimer;
  DateTime? _deadline;

  bool get _free => widget.config == null;
  SessionConfig get _config => widget.config!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    _player = scope.player;
    _settings = scope.settings;
    if (!_started) {
      _started = true;
      _showPattern = _free || _config.hintsAllowed;
      _line = _free
          ? context.s.freeKeyingLine
          : Voice.sessionStart(context.s, true);
      if (!_free) _nextRound();
    }
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _clockTimer?.cancel();
    _keyer?.dispose();
    _player.keyUp();
    _player.stop();
    _focusNode.dispose();
    super.dispose();
  }

  Keyer _ensureKeyer() {
    final type = _settings.keyType;
    if (_keyer == null || _keyerType != type) {
      _keyer?.dispose();
      _keyerType = type;
      final timing = widget.config?.timing ?? _settings.timing;
      _keyer = Keyer(
        type: type,
        unitMs: timing.unitMs,
        onTone: (on) => on ? _player.keyDown() : _player.keyUp(),
        onPending: (p) {
          if (mounted) setState(() => _pending = p);
        },
        onLetter: _onLetter,
        onWordGap: _free ? _onWordGap : null,
      );
    }
    return _keyer!;
  }

  void _press(Contact c) {
    if (_finished) return;
    if (!_free && _feedback != null) return;
    if (_settings.hapticsEnabled) HapticFeedback.selectionClick();
    setState(() => _held.add(c));
    _ensureKeyer().press(c);
  }

  void _release(Contact c) {
    setState(() => _held.remove(c));
    _keyer?.release(c);
  }

  void _nextRound() {
    _advanceTimer?.cancel();
    _clockTimer?.cancel();
    _keyer?.flush();
    if (_results.length >= _config.rounds) {
      _finish();
      return;
    }
    var item = _config.nextItem(_random);
    if (item == _item) item = _config.nextItem(_random);
    setState(() {
      _item = item;
      _targetTokens = [
        for (final w in item.trim().split(RegExp(r'\s+'))) ...tokenize(w),
      ].where((t) => encodeToken(t) != null).toList();
      _sent.clear();
      _pending = '';
      _feedback = null;
      _deadline = null;
      _mood = DitMood.idle;
    });
    final limit = _config.timeLimit;
    if (limit != null) {
      _deadline = DateTime.now().add(limit);
      _clockTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted) return;
        if (DateTime.now().isAfter(_deadline!)) {
          _evaluate(timedOut: true);
        } else {
          setState(() {});
        }
      });
    }
  }

  void _onLetter(String pattern) {
    if (!mounted) return;
    if (_free) {
      setState(() => _freeText += _labelFor(pattern));
      return;
    }
    if (_feedback != null) return;
    setState(() => _sent.add(pattern));
    if (_sent.length >= _targetTokens.length) _evaluate();
  }

  void _onWordGap() {
    if (!mounted) return;
    if (_freeText.isNotEmpty && !_freeText.endsWith(' ')) {
      setState(() => _freeText += ' ');
    }
  }

  void _evaluate({bool timedOut = false}) {
    if (_feedback != null) return;
    _clockTimer?.cancel();
    var correct = !timedOut && _sent.length == _targetTokens.length;
    for (var i = 0; correct && i < _targetTokens.length; i++) {
      correct = _sent[i] == encodeToken(_targetTokens[i]);
    }
    final scope = AppScope.of(context);
    if (_targetTokens.length == 1) {
      scope.progress.record(_targetTokens.single, correct: correct, send: true);
    }
    _player.chime(correct: correct);
    final sentText = [
      for (var i = 0; i < _sent.length; i++)
        _labelFor(
          _sent[i],
          expectedToken: i < _targetTokens.length ? _targetTokens[i] : null,
        ),
    ].join();
    final result = RoundResult(
      item: _item,
      answer: timedOut
          ? '$sentText ${context.s.timeUpSuffix}'.trim()
          : sentText,
      correct: correct,
    );
    if (_settings.hapticsEnabled) {
      correct ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
    }
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
    }
  }

  void _clearCurrent() {
    _keyer?.flush();
    setState(() {
      if (_free) {
        _freeText = '';
      } else {
        _sent.clear();
      }
      _pending = '';
    });
  }

  void _finish() {
    _keyer?.flush();
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
    final key = event.logicalKey;
    Contact? contact;
    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.bracketLeft) {
      contact = Contact.left;
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.bracketRight) {
      contact = Contact.right;
    }
    if (contact == null) return KeyEventResult.ignored;
    if (_settings.swapPaddles && _settings.keyType.hasTwoContacts) {
      contact = contact == Contact.left ? Contact.right : Contact.left;
    }
    if (event is KeyDownEvent) _press(contact);
    if (event is KeyUpEvent) _release(contact);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _free ? AppBar(title: Text(context.s.freeKeying)) : null,
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
              : _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final feedback = _feedback;

    double? timeLeft;
    if (!_free &&
        _deadline != null &&
        _config.timeLimit != null &&
        feedback == null) {
      final ms = _deadline!.difference(DateTime.now()).inMilliseconds;
      timeLeft = (ms / _config.timeLimit!.inMilliseconds).clamp(0.0, 1.0);
    }

    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) => Column(
        children: [
          if (!_free)
            SessionTopBar(
              progress: _results.length / _config.rounds,
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
                        child: Dit(
                          size: 104,
                          mood: _mood,
                          signal: _settings.flashEnabled
                              ? _player.signal
                              : null,
                        ),
                      ),
                    ),
                    SpeechBubble(text: _line, tailLeft: false),
                    const SizedBox(height: 14),
                    _free
                        ? _buildFreeArea(theme)
                        : _buildTargetArea(theme, feedback),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: PopupMenuButton<KeyType>(
                        tooltip: context.s.changeKey,
                        initialValue: _settings.keyType,
                        onSelected: (t) => _settings.keyType = t,
                        itemBuilder: (_) => [
                          for (final t in KeyType.values)
                            PopupMenuItem(
                              value: t,
                              child: Text(context.s.keyLabel(t)),
                            ),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.keyboard_alt_outlined,
                                color: theme.colorScheme.secondary,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  context.s.keyLabel(_settings.keyType),
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.expand_more_rounded,
                                color: theme.colorScheme.secondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!_free && _config.hintsAllowed) ...[
                      IconButton(
                        tooltip: _showPattern
                            ? context.s.hideCode
                            : context.s.showCode,
                        onPressed: () =>
                            setState(() => _showPattern = !_showPattern),
                        icon: Icon(
                          _showPattern
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                      ),
                      IconButton(
                        tooltip: context.s.listen,
                        onPressed: () =>
                            _player.playText(_item, timing: _config.timing),
                        icon: const Icon(Icons.volume_up_rounded),
                      ),
                    ],
                    IconButton(
                      tooltip: context.s.startOver,
                      onPressed: _clearCurrent,
                      icon: const Icon(Icons.backspace_outlined),
                    ),
                  ],
                ),
                KeyPad(
                  type: _settings.keyType,
                  swapped: _settings.swapPaddles,
                  held: _held,
                  onPress: _press,
                  onRelease: _release,
                ),
                const SizedBox(height: 6),
                Text(
                  _settings.keyType.hasTwoContacts
                      ? context.s.keyboardHintPaddles
                      : context.s.keyboardHintStraight,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeArea(ThemeData theme) {
    return Column(
      children: [
        Text(
          _freeText.isEmpty ? context.s.freeKeyingPlaceholder : _freeText,
          textAlign: TextAlign.center,
          style: _freeText.isEmpty
              ? theme.textTheme.bodyLarge
              : theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 20,
          child: MorsePattern(
            _pending,
            size: 10,
            color: theme.colorScheme.tertiary,
          ),
        ),
        if (_keyer != null && !_settings.keyType.hasTwoContacts) ...[
          const SizedBox(height: 12),
          Text(
            context.s.approxWpm((1200 / _keyer!.manualDotMs).round()),
            style: theme.textTheme.labelLarge,
          ),
        ],
      ],
    );
  }

  Widget _buildTargetArea(ThemeData theme, RoundResult? feedback) {
    final scheme = theme.colorScheme;
    return Column(
      children: [
        Text(
          context.s.sendThis,
          style: theme.textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: tracking(1.2),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _item,
          textAlign: TextAlign.center,
          style: theme.textTheme.displaySmall,
        ),
        const SizedBox(height: 12),
        if (_showPattern || feedback != null)
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
        const SizedBox(height: 20),
        // What has been sent so far, letter by letter.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < _sent.length; i++)
              PopIn(
                child: _SentChip(
                  label: _labelFor(
                    _sent[i],
                    expectedToken: i < _targetTokens.length
                        ? _targetTokens[i]
                        : null,
                  ),
                  ok:
                      i < _targetTokens.length &&
                      _sent[i] == encodeToken(_targetTokens[i]),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 20,
          child: MorsePattern(_pending, size: 10, color: scheme.tertiary),
        ),
        if (feedback != null && !feedback.correct) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _nextRound,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(context.s.next),
          ),
        ],
      ],
    );
  }
}

class _SentChip extends StatelessWidget {
  const _SentChip({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = ok ? context.colors.success : scheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}
