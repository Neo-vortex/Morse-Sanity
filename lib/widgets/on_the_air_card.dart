import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../screens/qso_screen.dart';
import '../theme/app_theme.dart';
import 'dit.dart';
import 'motion.dart';

/// Night-radio styled invitation to a simulated contact, used on the
/// Practice tab and at the end of the course map.
class OnTheAirCard extends StatelessWidget {
  const OnTheAirCard({super.key, this.compactTitle});

  /// Overrides the title (the course map uses an invitation line).
  final String? compactTitle;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final colors = context.colors;
    // Always "night": ink panel with a lamp-amber glow, in both themes.
    const ink = Color(0xFF14203A);
    const onInk = Color(0xFFEEF1F7);
    return Pressable(
      scale: 0.97,
      onTap: () =>
          Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const QsoScreen())),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(color: Color(0xFF070D1A), offset: Offset(0, 5)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.signal,
                          boxShadow: [
                            BoxShadow(color: colors.signalGlow, blurRadius: 8),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        s.onTheAir.toUpperCase(),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.signal,
                          letterSpacing: tracking(1.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    compactTitle ?? s.makeContact,
                    style: theme.textTheme.titleLarge?.copyWith(color: onInk),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    compactTitle == null ? s.onTheAirBlurb : s.qsoInviteBody,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: onInk.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _MiniMeter(),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Dit(size: 76, mood: DitMood.happy, lit: true),
          ],
        ),
      ),
    );
  }
}

/// Static S-meter decoration with a CW snippet beside it.
class _MiniMeter extends StatelessWidget {
  const _MiniMeter();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      textDirection: TextDirection.ltr,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 1; i <= 9; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            width: 5,
            height: 4 + i * 2.2,
            decoration: BoxDecoration(
              color: i <= 7
                  ? colors.signal.withValues(alpha: 0.5 + 0.5 * min(1, i / 7))
                  : const Color(0xFF34466A),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        const SizedBox(width: 10),
        Text(
          'CQ CQ DE …',
          style: TextStyle(
            fontFamily: monoFont,
            fontSize: 12,
            color: colors.signal.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}
