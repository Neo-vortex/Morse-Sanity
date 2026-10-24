import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// A bouncy spring used for presses and pop-ins (slight overshoot).
const _pressSpring = SpringDescription(mass: 1, stiffness: 500, damping: 18);

/// Shrinks a little while pressed and springs back on release.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.94,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  void _to(double target) {
    if (context.reduceMotion) {
      _c.value = target;
      return;
    }
    _c.animateWith(
      SpringSimulation(_pressSpring, _c.value, target, _c.velocity),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _to(widget.scale) : null,
      onTapUp: enabled ? (_) => _to(1) : null,
      onTapCancel: enabled ? () => _to(1) : null,
      onTap: enabled
          ? () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap?.call();
            }
          : null,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) =>
            Transform.scale(scale: _c.value, child: child),
        child: widget.child,
      ),
    );
  }
}

/// A tactile, "3D" button with a darker lip that presses down when tapped.
/// Used for the main call to action on a screen.
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.foreground,
    this.expand = true,
    this.height = 56,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? foreground;
  final bool expand;
  final double height;

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  static const _lip = 5.0;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = widget.onPressed != null;
    final face = enabled
        ? (widget.color ?? scheme.primary)
        : scheme.surfaceContainerHighest;
    final fg = enabled
        ? (widget.foreground ?? scheme.onPrimary)
        : scheme.onSurfaceVariant;
    final lip = Color.lerp(face, Colors.black, 0.28)!;
    final offset = _down ? _lip : 0.0;

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, color: fg, size: 22),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(
            widget.label.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: bodyFont,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: tracking(1.1),
              color: fg,
            ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                widget.onPressed!();
              }
            : null,
        child: SizedBox(
          height: widget.height + _lip,
          child: Stack(
            children: [
              Positioned.fill(
                top: _lip,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: enabled ? lip : scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 60),
                left: 0,
                right: 0,
                top: offset,
                height: widget.height,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: face,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: content,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shakes its child sideways whenever [trigger] changes (e.g. wrong answer).
class Shake extends StatefulWidget {
  const Shake({super.key, required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(Shake old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger && !context.reduceMotion) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        // Damped sine: three quick wobbles that settle.
        final t = _c.value;
        final dx = sin(t * pi * 6) * 12 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}

/// Scales and fades its child in after [delay], with a springy overshoot.
class PopIn extends StatefulWidget {
  const PopIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.from = 0.4,
  });

  final Widget child;
  final Duration delay;
  final double from;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (!mounted) return;
      if (context.reduceMotion) {
        _c.value = 1;
      } else {
        _c.animateWith(
          SpringSimulation(
            const SpringDescription(mass: 1, stiffness: 260, damping: 14),
            0,
            1,
            0,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = _c.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: widget.from + (1 - widget.from) * v,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Animates an integer counting up to [value].
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 900),
    this.format,
  });

  final int value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Duration duration;

  /// Formats the whole text, e.g. to use Persian digits.
  final String Function(Object text)? format;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: context.reduceMotion ? Duration.zero : duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        (format ?? (t) => '$t')('$prefix${v.round()}$suffix'),
        style: style,
      ),
    );
  }
}

/// A soft, repeating glow ring that draws the eye to the current item.
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.child, required this.color});

  final Widget child;
  final Color color;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => CustomPaint(
        painter: _PulsePainter(_c.value, widget.color),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.45 * (1 - t))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6 * (1 - t) + 1;
    canvas.drawCircle(size.center(Offset.zero), r + 4 + t * 16, paint);
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.t != t;
}

/// Confetti made of Morse dits and dahs. Bursts each time [trigger] changes.
class MorseConfetti extends StatefulWidget {
  const MorseConfetti({
    super.key,
    required this.trigger,
    required this.child,
    this.particles = 46,
  });

  final int trigger;
  final Widget child;
  final int particles;

  @override
  State<MorseConfetti> createState() => _MorseConfettiState();
}

class _Particle {
  _Particle(Random r, this.color)
    : dash = r.nextBool(),
      angle = -pi / 2 + (r.nextDouble() - 0.5) * pi * 0.9,
      speed = 380 + r.nextDouble() * 520,
      spin = (r.nextDouble() - 0.5) * 12,
      size = 6 + r.nextDouble() * 5;

  final bool dash;
  final double angle;
  final double speed;
  final double spin;
  final double size;
  final Color color;
}

class _MorseConfettiState extends State<MorseConfetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  final _random = Random();
  List<_Particle> _particles = const [];

  @override
  void didUpdateWidget(MorseConfetti old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger && widget.trigger > 0) _burst();
  }

  void _burst() {
    if (context.reduceMotion) return;
    final colors = context.colors.confetti;
    _particles = [
      for (var i = 0; i < widget.particles; i++)
        _Particle(_random, colors[i % colors.length]),
    ];
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => _c.isAnimating
                  ? CustomPaint(painter: _ConfettiPainter(_particles, _c.value))
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles, this.t);

  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.45);
    final seconds = t * 1.6;
    const gravity = 900.0;
    for (final p in particles) {
      final pos =
          origin +
          Offset(
            cos(p.angle) * p.speed * seconds,
            sin(p.angle) * p.speed * seconds +
                0.5 * gravity * seconds * seconds,
          );
      final paint = Paint()
        ..color = p.color.withValues(alpha: (1 - t * t).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * seconds);
      final w = p.dash ? p.size * 3 : p.size;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: p.size),
          Radius.circular(p.size / 2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
