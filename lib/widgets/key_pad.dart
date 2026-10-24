import 'package:flutter/material.dart';

import '../morse/keyer.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';

/// Touch surface for the selected telegraph key: one pad for a straight
/// key, two side-by-side pads for everything else.
class KeyPad extends StatelessWidget {
  const KeyPad({
    super.key,
    required this.type,
    required this.onPress,
    required this.onRelease,
    this.swapped = false,
    this.held = const {},
    this.height = 140,
  });

  final KeyType type;
  final ValueChanged<Contact> onPress;
  final ValueChanged<Contact> onRelease;

  /// Puts the right contact on the left side of the screen.
  final bool swapped;

  /// Contacts currently held, for visual feedback.
  final Set<Contact> held;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (!type.hasTwoContacts) {
      return _Pad(
        label: context.s.keyPadLabel(type, true),
        down: held.contains(Contact.left),
        height: height,
        onDown: () => onPress(Contact.left),
        onUp: () => onRelease(Contact.left),
      );
    }
    final leftLabel = context.s.keyPadLabel(type, true);
    final rightLabel = context.s.keyPadLabel(type, false);
    Widget pad(Contact c) => Expanded(
      child: _Pad(
        label: c == Contact.left ? leftLabel : rightLabel,
        down: held.contains(c),
        height: height,
        onDown: () => onPress(c),
        onUp: () => onRelease(c),
      ),
    );
    final sides = swapped
        ? [pad(Contact.right), pad(Contact.left)]
        : [pad(Contact.left), pad(Contact.right)];
    // Paddles keep their physical left/right layout in any language.
    return Row(
      textDirection: TextDirection.ltr,
      children: [sides[0], const SizedBox(width: 12), sides[1]],
    );
  }
}

class _Pad extends StatelessWidget {
  const _Pad({
    required this.label,
    required this.down,
    required this.height,
    required this.onDown,
    required this.onUp,
  });

  final String label;
  final bool down;
  final double height;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Looks like a key cap: it sinks onto its base and lights up amber
    // while held, the same glow as Dit's lamp.
    const lip = 7.0;
    final face = down ? scheme.primary : scheme.surfaceContainerLowest;
    final base = down
        ? Color.lerp(scheme.primary, Colors.black, 0.3)!
        : scheme.outlineVariant;
    return Listener(
      onPointerDown: (_) => onDown(),
      onPointerUp: (_) => onUp(),
      onPointerCancel: (_) => onUp(),
      child: SizedBox(
        height: height + lip,
        child: Stack(
          children: [
            Positioned.fill(
              top: lip,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 40),
              left: 0,
              right: 0,
              top: down ? lip : 0,
              height: height,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 40),
                decoration: BoxDecoration(
                  color: face,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: down ? scheme.primary : scheme.outlineVariant,
                    width: 2,
                  ),
                  boxShadow: down
                      ? [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.5),
                            blurRadius: 24,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: theme.textTheme.titleLarge?.copyWith(
                    letterSpacing: tracking(6),
                    color: down ? scheme.onPrimary : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
