import 'package:flutter/material.dart';

import '../l10n/strings.dart';

/// Draws a Morse pattern such as `-.-` as pill-shaped dashes and round dots.
class MorsePattern extends StatelessWidget {
  const MorsePattern(this.pattern, {super.key, this.size = 12, this.color});

  final String pattern;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    final s = context.s;
    return Semantics(
      label: pattern.split('').map((e) => e == '-' ? s.dah : s.dit).join(' '),
      // Morse always reads left to right, even in right-to-left languages.
      textDirection: TextDirection.ltr,
      child: Row(
        textDirection: TextDirection.ltr,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < pattern.length; i++)
            Container(
              margin: EdgeInsets.only(left: i == 0 ? 0 : size * 0.5),
              width: pattern[i] == '-' ? size * 3 : size,
              height: size,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(size / 2),
              ),
            ),
        ],
      ),
    );
  }
}
