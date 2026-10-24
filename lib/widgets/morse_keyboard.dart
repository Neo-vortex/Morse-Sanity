import 'dart:math';

import 'package:flutter/material.dart';

import '../morse/morse_code.dart';
import '../services/settings.dart';
import '../l10n/strings.dart';

/// Builds keyboard rows for a layout, adding number, symbol and prosign
/// rows only when a session needs them.
List<List<String>> keyboardRows(
  KeyboardLayout layout, {
  bool digitsRow = false,
  bool symbolRows = false,
  bool prosignRow = false,
  Random? random,
}) {
  List<String> letterRows;
  if (layout == KeyboardLayout.random) {
    final shuffled = letters.split('')..shuffle(random ?? Random());
    letterRows = [
      shuffled.sublist(0, 10).join(),
      shuffled.sublist(10, 19).join(),
      shuffled.sublist(19).join(),
    ];
  } else {
    letterRows = layout.rows;
  }
  final symbols = punctuation.split('');
  return [
    if (prosignRow) [for (final p in prosigns.keys) '<$p>'],
    if (digitsRow) digits.substring(1).split('')..add('0'),
    for (final r in letterRows) r.split(''),
    if (symbolRows) ...[
      symbols.sublist(0, (symbols.length / 2).ceil()),
      symbols.sublist((symbols.length / 2).ceil()),
    ],
  ];
}

/// On-screen keyboard for answering. Optionally shows each key's code.
class MorseKeyboard extends StatelessWidget {
  const MorseKeyboard({
    super.key,
    required this.rows,
    required this.onKey,
    this.onBackspace,
    this.onSpace,
    this.onSubmit,
    this.highlight = const {},
    this.showPatterns = false,
    this.enabled = true,
    this.keyColors = const {},
  });

  final List<List<String>> rows;
  final ValueChanged<String> onKey;
  final VoidCallback? onBackspace;
  final VoidCallback? onSpace;
  final VoidCallback? onSubmit;

  /// Keys that belong to the current level; others are dimmed.
  final Set<String> highlight;
  final bool showPatterns;
  final bool enabled;

  /// Feedback colours for particular keys (e.g. right/wrong answers).
  final Map<String, Color> keyColors;

  @override
  Widget build(BuildContext context) {
    final hasActions =
        onBackspace != null || onSpace != null || onSubmit != null;
    // The answer keyboard types Latin characters, so it stays LTR.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in rows)
            Row(
              children: [
                // Centre short rows instead of stretching their keys.
                if (row.length < 10) Spacer(flex: 10 - row.length),
                for (final k in row)
                  Expanded(
                    flex: 2,
                    child: _Key(label: k, keyboard: this),
                  ),
                if (row.length < 10) Spacer(flex: 10 - row.length),
              ],
            ),
          if (hasActions)
            Row(
              children: [
                if (onBackspace != null)
                  Expanded(
                    flex: 2,
                    child: _ActionKey(
                      icon: Icons.backspace_outlined,
                      tooltip: context.s.backspace,
                      onTap: enabled ? onBackspace : null,
                    ),
                  ),
                if (onSpace != null)
                  Expanded(
                    flex: 5,
                    child: _ActionKey(
                      icon: Icons.space_bar,
                      tooltip: context.s.space,
                      onTap: enabled ? onSpace : null,
                    ),
                  ),
                if (onSubmit != null)
                  Expanded(
                    flex: 3,
                    child: _ActionKey(
                      icon: Icons.keyboard_return,
                      tooltip: context.s.submit,
                      onTap: enabled ? onSubmit : null,
                      filled: true,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.keyboard});

  final String label;
  final MorseKeyboard keyboard;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isProsign = label.startsWith('<');
    final text = isProsign ? label.substring(1, label.length - 1) : label;
    final active =
        keyboard.highlight.isEmpty || keyboard.highlight.contains(label);
    final color =
        keyboard.keyColors[label] ??
        (active ? scheme.surfaceContainerLowest : scheme.surfaceContainer);
    final fg = active ? scheme.onSurface : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
      // A lip under each key makes the keyboard feel tactile.
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            if (active)
              BoxShadow(
                color: scheme.outlineVariant,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Material(
          color: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: active ? scheme.outlineVariant : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: keyboard.enabled ? () => keyboard.onKey(label) : null,
            child: SizedBox(
              height: keyboard.showPatterns ? 54 : 44,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: fg,
                        decoration: isProsign ? TextDecoration.overline : null,
                      ),
                    ),
                  ),
                  if (keyboard.showPatterns)
                    FittedBox(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          (encodeToken(label) ?? '')
                              .replaceAll('.', '·')
                              .replaceAll('-', '−'),
                          style: TextStyle(fontSize: 11, color: fg),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionKey extends StatelessWidget {
  const _ActionKey({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: filled ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onTap,
            child: SizedBox(
              height: 44,
              child: Icon(
                icon,
                color: filled ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
