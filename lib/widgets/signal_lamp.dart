import 'package:flutter/material.dart';

import '../app_scope.dart';

/// A round lamp that lights up whenever the Morse signal is keyed.
class SignalLamp extends StatelessWidget {
  const SignalLamp({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    final player = AppScope.of(context).player;
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: player.signal,
      builder: (context, on, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 15),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? Colors.amber : scheme.surfaceContainerHighest,
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: on
              ? [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.7),
                    blurRadius: size * 0.6,
                    spreadRadius: size * 0.1,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}
