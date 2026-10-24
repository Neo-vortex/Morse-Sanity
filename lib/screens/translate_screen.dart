import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../morse/morse_code.dart' as morse;
import '../widgets/dit.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';

/// Convert between plain text and Morse, and play the result.
class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  final _controller = TextEditingController(text: 'SOS');
  bool _textToMorse = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _output => _textToMorse
      ? morse.encode(_controller.text)
      : morse.decode(_controller.text);

  /// The plain-text form of whatever is entered, for playback.
  String get _plainText =>
      _textToMorse ? _controller.text : morse.decode(_controller.text);

  void _insert(String s) {
    final sel = _controller.selection;
    final text = _controller.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    _controller.value = TextEditingValue(
      text: text.replaceRange(start, end, s),
      selection: TextSelection.collapsed(offset: start + s.length),
    );
  }

  void _backspace() {
    final text = _controller.text;
    if (text.isEmpty) return;
    _controller.value = TextEditingValue(
      text: text.substring(0, text.length - 1),
      selection: TextSelection.collapsed(offset: text.length - 1),
    );
  }

  void _swap() {
    final out = _output;
    setState(() => _textToMorse = !_textToMorse);
    _controller.text = out;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final player = AppScope.of(context).player;
    final output = _output;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: true, label: Text(s.textToMorse)),
                  ButtonSegment(value: false, label: Text(s.morseToText)),
                ],
                selected: {_textToMorse},
                onSelectionChanged: (s) {
                  if (s.first != _textToMorse) _swap();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          minLines: 2,
          maxLines: 5,
          autocorrect: false,
          enableSuggestions: false,
          // Input is Latin text or Morse, both written left to right.
          textDirection: TextDirection.ltr,
          keyboardType: _textToMorse
              ? TextInputType.text
              : TextInputType.visiblePassword,
          style: _textToMorse
              ? null
              : const TextStyle(fontFamily: monoFont, fontSize: 18),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: _textToMorse ? s.text : s.morseInputLabel,
            helperText: _textToMorse ? s.latinOnly : null,
            helperMaxLines: 2,
            suffixIcon: IconButton(
              tooltip: s.clear,
              icon: const Icon(Icons.clear),
              onPressed: _controller.clear,
            ),
          ),
        ),
        if (!_textToMorse) ...[
          const SizedBox(height: 8),
          Row(
            textDirection: TextDirection.ltr,
            children: [
              for (final (label, value) in [
                ('·', '.'),
                ('−', '-'),
                (s.letterGap, ' '),
                (s.wordGap, ' / '),
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: OutlinedButton(
                      onPressed: () => _insert(value),
                      child: Text(
                        label,
                        style: label.length == 1
                            ? theme.textTheme.titleLarge
                            : null,
                      ),
                    ),
                  ),
                ),
              IconButton(
                tooltip: s.backspace,
                onPressed: _backspace,
                icon: const Icon(Icons.backspace_outlined),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _textToMorse ? s.morse : s.text,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  output.isEmpty ? '—' : output,
                  textDirection: TextDirection.ltr,
                  style: _textToMorse
                      ? theme.textTheme.titleLarge?.copyWith(
                          fontFamily: monoFont,
                          letterSpacing: 2,
                        )
                      : theme.textTheme.headlineSmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: player.isPlaying,
              builder: (context, playing, _) => Dit(
                size: 64,
                mood: playing ? DitMood.listening : DitMood.idle,
                signal: player.signal,
              ),
            ),
            const SizedBox(width: 16),
            ValueListenableBuilder<bool>(
              valueListenable: player.isPlaying,
              builder: (context, playing, _) => FilledButton.icon(
                onPressed: playing
                    ? player.stop
                    : _plainText.trim().isEmpty
                    ? null
                    : () => player.playText(_plainText),
                icon: Icon(playing ? Icons.stop : Icons.play_arrow),
                label: Text(playing ? s.stop : s.play),
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: s.copyResult,
              onPressed: output.isEmpty
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: output));
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(s.copied)));
                    },
              icon: const Icon(Icons.copy),
            ),
            IconButton(
              tooltip: s.swapDirection,
              onPressed: _swap,
              icon: const Icon(Icons.swap_vert),
            ),
          ],
        ),
      ],
    );
  }
}
