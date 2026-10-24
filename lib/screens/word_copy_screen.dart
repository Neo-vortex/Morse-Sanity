import 'dart:math';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../morse/morse_code.dart' as morse;
import '../services/morse_player.dart';
import '../widgets/signal_lamp.dart';
import '../l10n/strings.dart';

/// Listen to a whole word or group and type what you heard.
class WordCopyScreen extends StatefulWidget {
  const WordCopyScreen({super.key, required this.title, required this.words});

  final String title;
  final List<String> words;

  @override
  State<WordCopyScreen> createState() => _WordCopyScreenState();
}

class _WordCopyScreenState extends State<WordCopyScreen> {
  final _random = Random();
  final _controller = TextEditingController();
  final _inputFocus = FocusNode();
  late MorsePlayer _player;

  String _word = '';
  bool? _wasCorrect;
  int _attempts = 0;
  int _correct = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _player = AppScope.of(context).player;
    if (_word.isEmpty) _next();
  }

  @override
  void dispose() {
    _player.stop();
    _controller.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _next() {
    var word = widget.words[_random.nextInt(widget.words.length)];
    if (word == _word && widget.words.length > 1) {
      word = widget.words[_random.nextInt(widget.words.length)];
    }
    setState(() {
      _word = word;
      _wasCorrect = null;
      _controller.clear();
    });
    _player.playText(word);
    _inputFocus.requestFocus();
  }

  void _check() {
    if (_wasCorrect != null) {
      _next();
      return;
    }
    final guess = _controller.text.trim().toUpperCase();
    if (guess.isEmpty) return;
    final ok = guess == _word;
    setState(() {
      _wasCorrect = ok;
      _attempts++;
      if (ok) _correct++;
    });
    if (!ok) _player.playText(_word);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _attempts == 0
                  ? context.s.typeTheWord
                  : context.s.score(_correct, _attempts),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            Center(
              child: IconButton.filledTonal(
                iconSize: 56,
                tooltip: context.s.playAgain,
                onPressed: () => _player.playText(_word),
                icon: const Icon(Icons.volume_up),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              focusNode: _inputFocus,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              // Copy is Latin text.
              textDirection: TextDirection.ltr,
              style: theme.textTheme.headlineMedium,
              readOnly: _wasCorrect != null,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: context.s.yourCopy,
              ),
              onSubmitted: (_) => _check(),
            ),
            const SizedBox(height: 16),
            if (_wasCorrect != null)
              Card(
                color: (_wasCorrect! ? Colors.green : scheme.error).withValues(
                  alpha: 0.15,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        _wasCorrect! ? context.s.correct : context.s.itWas,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(_word, style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      SelectableText(
                        morse.encode(_word),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontFamily: 'JetBrainsMono',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _check,
              icon: Icon(_wasCorrect == null ? Icons.check : Icons.skip_next),
              label: Text(
                _wasCorrect == null ? context.s.check : context.s.nextWord,
              ),
            ),
            if (_wasCorrect == null)
              TextButton(onPressed: _next, child: Text(context.s.skip)),
          ],
        ),
      ),
    );
  }
}
