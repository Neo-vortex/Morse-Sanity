import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../l10n/strings.dart';

/// Dit's expressions.
enum DitMood { idle, listening, thinking, happy, celebrating, sad, sleepy }

/// Dit, the app's mascot: a small signal lamp whose lens lights up whenever
/// Morse is played. It bobs while idle, blinks, and bounces when its mood
/// changes.
class Dit extends StatefulWidget {
  const Dit({
    super.key,
    this.mood = DitMood.idle,
    this.size = 120,
    this.signal,
    this.lit = false,
  });

  final DitMood mood;
  final double size;

  /// When given, the lens glows while this is true (e.g. the player signal).
  final ValueListenable<bool>? signal;

  /// Forces the lens on.
  final bool lit;

  @override
  State<Dit> createState() => _DitState();
}

class _DitState extends State<Dit> with TickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
  );
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 40),
  );
  Timer? _blinkTimer;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    widget.signal?.addListener(_onSignal);
    _scheduleBlink();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _bob.stop();
    } else if (!_bob.isAnimating) {
      _bob.repeat();
    }
  }

  @override
  void didUpdateWidget(Dit old) {
    super.didUpdateWidget(old);
    if (old.signal != widget.signal) {
      old.signal?.removeListener(_onSignal);
      widget.signal?.addListener(_onSignal);
    }
    if (old.mood != widget.mood && !context.reduceMotion) {
      _bounce.forward(from: 0);
    }
  }

  void _onSignal() {
    widget.signal!.value ? _glow.forward() : _glow.reverse();
  }

  void _scheduleBlink() {
    _blinkTimer = Timer(
      Duration(milliseconds: 2200 + _random.nextInt(2800)),
      () {
        if (!mounted) return;
        _blink.forward().then((_) {
          if (mounted) _blink.reverse();
        });
        _scheduleBlink();
      },
    );
  }

  @override
  void dispose() {
    widget.signal?.removeListener(_onSignal);
    _blinkTimer?.cancel();
    _bob.dispose();
    _bounce.dispose();
    _blink.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: context.s.ditName,
      child: SizedBox(
        width: widget.size,
        height: widget.size * 1.15,
        child: AnimatedBuilder(
          animation: Listenable.merge([_bob, _bounce, _blink, _glow]),
          builder: (context, _) {
            final bob = sin(_bob.value * 2 * pi);
            // Bounce: a quick squash-and-stretch hop that decays.
            final b = _bounce.value;
            final hop = widget.mood == DitMood.celebrating
                ? sin(b * pi * 2).abs() * (1 - b) * 0.25
                : sin(b * pi) * (1 - b) * 0.12;
            final squash = widget.mood == DitMood.sad
                ? 1 - sin(b * pi) * 0.06
                : 1 + sin(b * pi * 2) * (1 - b) * 0.08;
            return CustomPaint(
              painter: _DitPainter(
                mood: widget.mood,
                colors: colors,
                scheme: Theme.of(context).colorScheme,
                bob: bob,
                hop: hop,
                squash: squash,
                blink: _blink.value,
                glow: widget.lit ? 1 : _glow.value,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DitPainter extends CustomPainter {
  _DitPainter({
    required this.mood,
    required this.colors,
    required this.scheme,
    required this.bob,
    required this.hop,
    required this.squash,
    required this.blink,
    required this.glow,
  });

  final DitMood mood;
  final AppColors colors;
  final ColorScheme scheme;
  final double bob;
  final double hop;
  final double squash;
  final double blink;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ground = h * 0.97;

    // Shadow shrinks as Dit hops.
    final shadowW = w * 0.5 * (1 - hop * 1.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, ground),
        width: shadowW,
        height: h * 0.05,
      ),
      Paint()..color = scheme.shadow.withValues(alpha: 0.12),
    );

    canvas.save();
    final lift =
        (hop * h) + (mood == DitMood.sad ? -h * 0.02 : bob * h * 0.015);
    canvas.translate(w / 2, ground - h * 0.03 - lift);
    canvas.scale(1 / sqrt(squash), squash);

    // --- Base: a rounded lamp housing --------------------------------------
    final baseW = w * 0.62;
    final baseH = h * 0.36;
    final baseRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(-baseW / 2, -baseH, baseW, baseH),
      topLeft: Radius.circular(w * 0.12),
      topRight: Radius.circular(w * 0.12),
      bottomLeft: Radius.circular(w * 0.16),
      bottomRight: Radius.circular(w * 0.16),
    );
    canvas.drawRRect(baseRect, Paint()..color = colors.mascotBody);
    // Brass band.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-baseW / 2, -baseH * 0.62, baseW, baseH * 0.16),
        Radius.circular(w * 0.02),
      ),
      Paint()..color = colors.signal.withValues(alpha: 0.9),
    );
    // Little feet.
    final foot = Paint()
      ..color = Color.lerp(colors.mascotBody, Colors.black, 0.25)!;
    for (final x in [-baseW * 0.28, baseW * 0.28]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, 0),
            width: w * 0.14,
            height: h * 0.05,
          ),
          Radius.circular(w * 0.03),
        ),
        foot,
      );
    }

    // --- Lens: the glowing head -------------------------------------------
    final r = w * 0.34;
    final lensCenter = Offset(0, -baseH - r * 0.72);
    if (glow > 0) {
      canvas.drawCircle(
        lensCenter,
        r * (1.25 + 0.35 * glow),
        Paint()
          ..shader = RadialGradient(
            colors: [
              colors.signalGlow.withValues(alpha: 0.9 * glow),
              colors.signalGlow.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: lensCenter, radius: r * 1.6)),
      );
    }
    // Rim.
    canvas.drawCircle(lensCenter, r * 1.08, Paint()..color = colors.mascotBody);
    // Glass.
    final glass = Color.lerp(colors.lampOff, colors.signal, glow)!;
    canvas.drawCircle(lensCenter, r, Paint()..color = glass);
    // Shine.
    canvas.drawArc(
      Rect.fromCircle(center: lensCenter, radius: r * 0.78),
      pi * 1.1,
      pi * 0.45,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12
        ..strokeCap = StrokeCap.round,
    );

    // Antenna with a bobbing tip.
    final antennaBase = lensCenter + Offset(0, -r * 1.05);
    final tip = antennaBase + Offset(bob * w * 0.03, -h * 0.1);
    canvas.drawLine(
      antennaBase,
      tip,
      Paint()
        ..color = colors.mascotBody
        ..strokeWidth = w * 0.035
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      tip,
      w * 0.045,
      Paint()..color = glow > 0.5 ? colors.signal : colors.streak,
    );

    _paintFace(canvas, lensCenter, r);
    canvas.restore();
  }

  void _paintFace(Canvas canvas, Offset c, double r) {
    final ink = colors.mascotFace;
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.11
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = ink;
    final eyeY = c.dy - r * 0.08;
    final eyeDx = r * 0.36;

    // Eyes.
    for (final side in [-1, 1]) {
      final e = Offset(c.dx + side * eyeDx, eyeY);
      switch (mood) {
        case DitMood.happy:
        case DitMood.celebrating:
          // ^ ^ happy arcs.
          canvas.drawArc(
            Rect.fromCenter(
              center: e + Offset(0, r * 0.06),
              width: r * 0.32,
              height: r * 0.3,
            ),
            pi * 1.1,
            pi * 0.8,
            false,
            stroke,
          );
        case DitMood.listening:
        case DitMood.sleepy:
          // Gently closed.
          canvas.drawArc(
            Rect.fromCenter(
              center: e - Offset(0, r * 0.04),
              width: r * 0.28,
              height: r * 0.2,
            ),
            pi * 0.1,
            pi * 0.8,
            false,
            stroke,
          );
        case DitMood.idle:
        case DitMood.thinking:
        case DitMood.sad:
          final open = 1 - blink;
          final look = mood == DitMood.thinking
              ? Offset(r * 0.07, -r * 0.08)
              : Offset.zero;
          canvas.drawOval(
            Rect.fromCenter(
              center: e + look,
              width: r * 0.2,
              height: r * 0.28 * max(open, 0.12),
            ),
            fill,
          );
          if (mood == DitMood.sad) {
            // Worried brows.
            canvas.drawLine(
              e + Offset(-side * r * 0.14, -r * 0.26),
              e + Offset(side * r * 0.1, -r * 0.33),
              stroke..strokeWidth = r * 0.08,
            );
            stroke.strokeWidth = r * 0.11;
          }
      }
    }

    // Cheeks when cheerful.
    if (mood == DitMood.happy || mood == DitMood.celebrating) {
      final blush = Paint()
        ..color = const Color(0xFFFF7A7A).withValues(alpha: 0.45);
      for (final side in [-1, 1]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(c.dx + side * r * 0.58, c.dy + r * 0.2),
            width: r * 0.26,
            height: r * 0.15,
          ),
          blush,
        );
      }
    }

    // Mouth.
    final m = Offset(c.dx, c.dy + r * 0.32);
    switch (mood) {
      case DitMood.celebrating:
        final path = Path()
          ..moveTo(m.dx - r * 0.26, m.dy - r * 0.06)
          ..quadraticBezierTo(
            m.dx,
            m.dy + r * 0.42,
            m.dx + r * 0.26,
            m.dy - r * 0.06,
          )
          ..close();
        canvas.drawPath(path, fill);
      case DitMood.happy:
        canvas.drawArc(
          Rect.fromCenter(
            center: m - Offset(0, r * 0.08),
            width: r * 0.5,
            height: r * 0.36,
          ),
          pi * 0.15,
          pi * 0.7,
          false,
          stroke,
        );
      case DitMood.sad:
        canvas.drawArc(
          Rect.fromCenter(
            center: m + Offset(0, r * 0.1),
            width: r * 0.38,
            height: r * 0.26,
          ),
          pi * 1.15,
          pi * 0.7,
          false,
          stroke,
        );
      case DitMood.thinking:
        canvas.drawCircle(m + Offset(r * 0.08, 0), r * 0.07, fill);
      case DitMood.sleepy:
        canvas.drawOval(
          Rect.fromCenter(center: m, width: r * 0.14, height: r * 0.1),
          fill,
        );
      case DitMood.idle:
      case DitMood.listening:
        canvas.drawArc(
          Rect.fromCenter(
            center: m - Offset(0, r * 0.06),
            width: r * 0.34,
            height: r * 0.22,
          ),
          pi * 0.15,
          pi * 0.7,
          false,
          stroke,
        );
    }
  }

  @override
  bool shouldRepaint(_DitPainter old) =>
      old.mood != mood ||
      old.bob != bob ||
      old.hop != hop ||
      old.squash != squash ||
      old.blink != blink ||
      old.glow != glow ||
      old.colors != colors;
}

/// A rounded speech bubble with a tail pointing at Dit on the left.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({super.key, required this.text, this.tailLeft = true});

  final String text;
  final bool tailLeft;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // tailLeft means "towards the start"; mirror it for right-to-left text.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final left = tailLeft != rtl;
    return CustomPaint(
      painter: _BubblePainter(
        fill: scheme.surfaceContainerLowest,
        border: scheme.outlineVariant,
        tailLeft: left,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(left ? 22 : 14, 12, left ? 14 : 22, 12),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.25),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
              child: child,
            ),
          ),
          child: Text(
            text,
            key: ValueKey(text),
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter({
    required this.fill,
    required this.border,
    required this.tailLeft,
  });

  final Color fill;
  final Color border;
  final bool tailLeft;

  @override
  void paint(Canvas canvas, Size size) {
    const tail = 10.0;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(tailLeft ? tail : 0, 0, size.width - tail, size.height),
      const Radius.circular(18),
    );
    final midY = size.height / 2;
    final tailPath = tailLeft
        ? (Path()
            ..moveTo(tail + 1, midY - 9)
            ..lineTo(0, midY + 2)
            ..lineTo(tail + 1, midY + 7))
        : (Path()
            ..moveTo(size.width - tail - 1, midY - 9)
            ..lineTo(size.width, midY + 2)
            ..lineTo(size.width - tail - 1, midY + 7));
    final path = Path.combine(
      PathOperation.union,
      Path()..addRRect(body),
      tailPath,
    );
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_BubblePainter old) =>
      old.fill != fill || old.border != border || old.tailLeft != tailLeft;
}
