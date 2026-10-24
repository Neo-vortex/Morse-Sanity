import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../data/codes.dart';
import '../l10n/strings.dart';
import '../qso/glossary.dart';
import '../qso/qso_engine.dart';
import '../services/morse_player.dart';
import '../services/settings.dart';
import '../theme/app_theme.dart';
import '../widgets/dit.dart';
import '../widgets/motion.dart';
import '../morse/keyer.dart';
import '../morse/morse_code.dart';
import '../widgets/key_pad.dart';
import '../widgets/morse_pattern.dart';

/// XP for completing a simulated contact.
const qsoXp = 15;

class _Line {
  _Line(this.text, {required this.fromUser}) : tokens = tokensFor(text);

  final String text;
  final bool fromUser;
  final List<List<String>> tokens;
  bool revealed = false;

  /// Character currently sounding, while this line plays.
  int? cursor;

  /// Has played through once (their lines appear as they're heard).
  bool heard = false;

  /// Words the user tapped to see in letters (dots & dashes mode).
  final decodedWords = <int>{};
}

/// "On the air": a short, coached CW contact with a simulated operator.
class QsoScreen extends StatefulWidget {
  const QsoScreen({super.key});

  @override
  State<QsoScreen> createState() => _QsoScreenState();
}

class _QsoScreenState extends State<QsoScreen> {
  final _random = Random();
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();
  late MorsePlayer _player;
  late Settings _settings;

  late QsoEngine _engine;
  final _lines = <_Line>[];
  bool _started = false;
  bool _busy = false;
  bool _thinking = false;
  bool _ended = false;
  bool _coachOpen = false;
  int? _playing;
  int _confetti = 0;
  int _session = 0;
  String? _practiceCall;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    _player = scope.player;
    _settings = scope.settings;
    if (!_started) {
      _started = true;
      if (_settings.callsign.isEmpty) {
        // Save a practice call after this frame; notifying mid-build
        // would rebuild the whole app.
        _practiceCall = randomCallsign(_random);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _settings.callsign = _practiceCall!,
        );
      }
      _coachOpen = !_settings.qsoCoachSeen;
      _newQso();
    }
  }

  @override
  void dispose() {
    _session++;
    _player.stop();
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _newQso() {
    _session++;
    final myCall = _settings.callsign.isEmpty
        ? (_practiceCall ??= randomCallsign(_random))
        : _settings.callsign;
    final session = QsoSession.generate(_random, myCall: myCall);
    _engine = QsoEngine(session: session, random: _random);
    _player.stop();
    setState(() {
      _lines.clear();
      _ended = false;
      _busy = true;
      _thinking = false;
      _input.clear();
    });
    final cq = _engine.start();
    final session0 = _session;
    Future<void>.delayed(const Duration(milliseconds: 500), () async {
      if (!mounted || session0 != _session) return;
      await _addTheirs(cq);
      if (mounted && session0 == _session) setState(() => _busy = false);
    });
  }

  Future<void> _addTheirs(String text) async {
    setState(() => _lines.add(_Line(text, fromUser: false)));
    _scrollToEnd();
    await _play(_lines.length - 1);
  }

  Future<void> _play(int index) async {
    final session0 = _session;
    final line = _lines[index];
    setState(() {
      _playing = index;
      line.cursor = 0;
    });
    await _player.playText(
      line.text,
      onToken: (t) {
        if (mounted && session0 == _session) setState(() => line.cursor = t);
      },
    );
    if (!mounted || session0 != _session) return;
    setState(() {
      line.cursor = null;
      line.heard = true;
      if (_playing == index) _playing = null;
    });
  }

  Future<void> _send([String? text]) async {
    final message = (text ?? _input.text).trim().toUpperCase();
    if (message.isEmpty || _busy || _engine.isDone) return;
    final session0 = _session;
    if (_settings.hapticsEnabled) HapticFeedback.lightImpact();
    if (_coachOpen) _settings.qsoCoachSeen = true;
    setState(() {
      _busy = true;
      _coachOpen = false;
      _input.clear();
      _lines.add(_Line(message, fromUser: true));
    });
    _scrollToEnd();
    // Keyed replies were already heard as sidetone while keying.
    if (_settings.qsoPlayMine && !_settings.qsoCodeMode) {
      await _play(_lines.length - 1);
    } else {
      _lines.last.heard = true;
    }
    if (!mounted || session0 != _session) return;

    final reply = _engine.reply(message);
    setState(() => _thinking = true);
    _scrollToEnd();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted || session0 != _session) return;
    setState(() => _thinking = false);
    await _addTheirs(reply);
    if (!mounted || session0 != _session) return;
    setState(() => _busy = false);

    if (_engine.isDone) {
      final progress = AppScope.of(context).progress;
      progress.addXp(qsoXp);
      _player.fanfare(3);
      setState(() => _confetti++);
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _confirmEnd() async {
    final s = context.s;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.endQsoQuestion),
        content: Text(s.endQsoBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.keepGoing),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.endQso),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _session++;
    _player.stop();
    _engine.abandon();
    setState(() {
      _ended = true;
      _busy = false;
      _thinking = false;
    });
  }

  void _explain(_Line line) {
    final s = context.s;
    final entries = glossLine(line.text, s, session: _engine.session);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ExplainSheet(line: line.text, entries: entries),
    );
  }

  void _openOptions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _QsoOptions(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final done = _engine.isDone && !_ended;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.onTheAir),
        actions: [
          IconButton(
            tooltip: s.settings,
            icon: const Icon(Icons.tune_rounded),
            onPressed: _openOptions,
          ),
          if (!_engine.isDone)
            IconButton(
              tooltip: s.endQso,
              icon: Icon(
                Icons.call_end_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: _confirmEnd,
            )
          else
            IconButton(
              tooltip: s.newQso,
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _newQso,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _settings,
          builder: (context, _) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: _StationCard(
                  session: _engine.session,
                  active: _playing != null && !_lines[_playing!].fromUser,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: [
                    ButtonSegment(
                      value: false,
                      icon: const Icon(Icons.text_fields_rounded),
                      label: Text(s.modeLetters),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.more_horiz_rounded),
                      label: Text(s.modeCode),
                    ),
                  ],
                  selected: {_settings.qsoCodeMode},
                  onSelectionChanged: (v) => _settings.qsoCodeMode = v.first,
                ),
              ),
              Expanded(
                child: MorseConfetti(
                  trigger: _confetti,
                  particles: 70,
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      for (var i = 0; i < _lines.length; i++)
                        _Bubble(
                          line: _lines[i],
                          callsign: _lines[i].fromUser
                              ? _engine.session.myCall
                              : _engine.session.theirCall,
                          playing: _playing == i,
                          codeMode: _settings.qsoCodeMode,
                          hidden:
                              !_settings.qsoCodeMode &&
                              !_lines[i].fromUser &&
                              _settings.qsoCopyByEar &&
                              !_lines[i].revealed,
                          onToggleWord: (w) => setState(() {
                            final d = _lines[i].decodedWords;
                            d.contains(w) ? d.remove(w) : d.add(w);
                          }),
                          onReveal: () =>
                              setState(() => _lines[i].revealed = true),
                          onReplay: () => _play(i),
                          onExplain: () => _explain(_lines[i]),
                        ),
                      if (_thinking) const _ThinkingBubble(),
                      if (done) ...[
                        const SizedBox(height: 12),
                        PopIn(
                          child: _QslCard(
                            session: _engine.session,
                            userRst: _engine.userRst,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (done || _ended)
                _EndPanel(onNew: _newQso)
              else ...[
                _Coach(
                  expected: _engine.expected,
                  open: _coachOpen,
                  examples: _engine.examples(),
                  signal: _player.signal,
                  onToggle: () {
                    setState(() => _coachOpen = !_coachOpen);
                    if (!_coachOpen) _settings.qsoCoachSeen = true;
                  },
                  onExample: (e) {
                    _input.text = e;
                    _input.selection = TextSelection.collapsed(
                      offset: e.length,
                    );
                    if (!_settings.qsoCodeMode) _inputFocus.requestFocus();
                  },
                ),
                if (_settings.qsoCodeMode)
                  _KeyComposer(
                    controller: _input,
                    enabled: !_busy,
                    singleKey: _settings.qsoSingleKey,
                    onSingleKeyChanged: (v) => _settings.qsoSingleKey = v,
                    onSend: _send,
                  )
                else
                  _Composer(
                    controller: _input,
                    focusNode: _inputFocus,
                    enabled: !_busy,
                    onSend: _send,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The other station: callsign, operator, conditions and a live S-meter.
class _StationCard extends StatelessWidget {
  const _StationCard({required this.session, required this.active});

  final QsoSession session;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: active ? context.colors.signal : scheme.outlineVariant,
          width: active ? 2.5 : 1.5,
        ),
      ),
      child: Row(
        children: [
          _SMeter(
            strength: int.parse(session.rst[1]),
            condition: session.condition,
            lit: active,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.theirCall,
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontFamily: monoFont,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  '${session.name} · ${session.qth}',
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    s.conditionLabel(session.condition),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                s.you.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: tracking(1),
                ),
              ),
              Text(
                session.myCall,
                textDirection: TextDirection.ltr,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontFamily: monoFont,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Nine-bar signal meter that wobbles with fading and noise.
class _SMeter extends StatefulWidget {
  const _SMeter({
    required this.strength,
    required this.condition,
    required this.lit,
  });

  final int strength;
  final BandCondition condition;
  final bool lit;

  @override
  State<_SMeter> createState() => _SMeterState();
}

class _SMeterState extends State<_SMeter> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );
  final _random = Random();

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

  double _level() {
    final base = widget.strength.toDouble();
    final t = _c.value * 2 * pi;
    return switch (widget.condition) {
      BandCondition.clear => base,
      BandCondition.lightQsb => base - 1 + sin(t),
      BandCondition.heavyQsb => base - 2.5 + 2.5 * sin(t),
      BandCondition.qrm ||
      BandCondition.qrn => base - 0.5 + (_random.nextDouble() - 0.5) * 1.5,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'S${widget.strength}',
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final level = context.reduceMotion
              ? widget.strength.toDouble()
              : _level().clamp(1.0, 9.0);
          return SizedBox(
            width: 56,
            height: 44,
            child: Row(
              textDirection: TextDirection.ltr,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 1; i <= 9; i++)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      height: 8 + i * 4.0,
                      decoration: BoxDecoration(
                        color: i <= level
                            ? (widget.lit
                                  ? colors.signal
                                  : colors.signal.withValues(alpha: 0.75))
                            : scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.line,
    required this.callsign,
    required this.playing,
    required this.codeMode,
    required this.hidden,
    required this.onToggleWord,
    required this.onReveal,
    required this.onReplay,
    required this.onExplain,
  });

  final _Line line;
  final String callsign;
  final bool playing;
  final bool codeMode;
  final bool hidden;
  final ValueChanged<int> onToggleWord;
  final VoidCallback onReveal;
  final VoidCallback onReplay;
  final VoidCallback onExplain;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.colors;
    final mine = line.fromUser;
    final bg = mine ? scheme.primaryContainer : scheme.surfaceContainerLowest;
    final fg = mine ? scheme.onPrimaryContainer : scheme.onSurface;
    final radius = BorderRadiusDirectional.only(
      topStart: const Radius.circular(20),
      topEnd: const Radius.circular(20),
      bottomStart: Radius.circular(mine ? 20 : 6),
      bottomEnd: Radius.circular(mine ? 6 : 20),
    );

    final text = hidden
        ? Pressable(
            onTap: onReveal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hearing_rounded, size: 18, color: scheme.secondary),
                const SizedBox(width: 8),
                Text(
                  s.tapToReveal,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.secondary,
                  ),
                ),
              ],
            ),
          )
        : codeMode
        ? _CodeWords(
            line: line,
            color: fg,
            // Their words appear as they are heard.
            progressive: !mine && !line.heard,
            onToggleWord: onToggleWord,
          )
        : _LiveText(line: line, color: fg);

    return Align(
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: radius,
              border: Border.all(
                color: playing ? colors.signal : scheme.outlineVariant,
                width: playing ? 2.5 : 1.5,
              ),
              boxShadow: playing
                  ? [BoxShadow(color: colors.signalGlow, blurRadius: 18)]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  callsign,
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontFamily: monoFont,
                    color: mine ? fg.withValues(alpha: 0.7) : scheme.secondary,
                  ),
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: text,
                ),
                if (codeMode && !mine && line.heard)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      s.tapWordToDecode,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!mine && !hidden)
                      TextButton.icon(
                        onPressed: onExplain,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: const Icon(Icons.translate_rounded, size: 18),
                        label: Text(s.explain),
                      ),
                    IconButton(
                      tooltip: s.playAgain,
                      visualDensity: VisualDensity.compact,
                      iconSize: 20,
                      onPressed: onReplay,
                      icon: Icon(
                        playing
                            ? Icons.graphic_eq_rounded
                            : Icons.volume_up_rounded,
                        color: playing ? colors.signal : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "· · ·" while the other operator composes a reply.
class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant, width: 1.5),
        ),
        child: Semantics(
          label: context.s.listening,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.colors.signal.withValues(
                        alpha:
                            0.3 +
                            0.7 *
                                (0.5 + 0.5 * sin((_c.value - i / 3) * 2 * pi)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dit's hint row: what they're waiting for, and how to answer.
class _Coach extends StatelessWidget {
  const _Coach({
    required this.expected,
    required this.open,
    required this.examples,
    required this.signal,
    required this.onToggle,
    required this.onExample,
  });

  final QsoIntent? expected;
  final bool open;
  final List<String> examples;
  final ValueListenable<bool> signal;
  final VoidCallback onToggle;
  final ValueChanged<String> onExample;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Dit(size: 40, mood: open ? DitMood.happy : DitMood.thinking),
                const SizedBox(width: 6),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      s.qsoWaiting(expected),
                      key: ValueKey(expected),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onToggle,
                  icon: Icon(
                    open
                        ? Icons.expand_more_rounded
                        : Icons.lightbulb_outline_rounded,
                    size: 18,
                  ),
                  label: Text(open ? s.gotIt : s.showMeHow),
                ),
              ],
            ),
            if (open) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                child: Text(
                  s.qsoHintBody(expected),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                child: Text(
                  s.tryOneOfThese,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final e in examples)
                      ActionChip(
                        onPressed: () => onExample(e),
                        label: Text(
                          e,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(fontFamily: monoFont),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              textDirection: TextDirection.ltr,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              inputFormatters: [_UpperCase()],
              style: const TextStyle(fontFamily: monoFont, fontSize: 16),
              decoration: InputDecoration(
                hintText: s.typeYourReply,
                filled: true,
                fillColor: scheme.surfaceContainerLowest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: scheme.outlineVariant,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final ready = enabled && value.text.trim().isNotEmpty;
              return Tooltip(
                message: s.sendReply,
                child: Pressable(
                  onTap: ready ? onSend : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ready
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                      boxShadow: ready
                          ? [
                              BoxShadow(
                                color: Color.lerp(
                                  scheme.primary,
                                  Colors.black,
                                  0.3,
                                )!,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      textDirection: TextDirection.ltr,
                      color: ready ? scheme.onPrimary : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}

class _EndPanel extends StatelessWidget {
  const _EndPanel({required this.onNew});

  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChunkyButton(
            label: s.newQso,
            icon: Icons.cell_tower_rounded,
            onPressed: onNew,
          ),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(s.done),
          ),
        ],
      ),
    );
  }
}

/// The postcard-style confirmation hams exchange after a contact.
class _QslCard extends StatelessWidget {
  const _QslCard({required this.session, required this.userRst});

  final QsoSession session;
  final String? userRst;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.colors;
    final now = DateTime.now().toUtc();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}Z';

    Widget field(String label, String value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: theme.textTheme.titleMedium?.copyWith(fontFamily: monoFont),
          ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.signal, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Color.lerp(colors.signal, Colors.black, 0.35)!,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(
              color: colors.signal,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(19),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'QSL',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: scheme.onPrimary,
                    fontFamily: monoFont,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.qslTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.onPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '+${s.xp(qsoXp)}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.theirCall,
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontFamily: monoFont,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  s.qslConfirming(session.theirCall),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    field(s.yourReport, userRst ?? '—'),
                    field(s.theirReport, session.rst),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    field(s.operatorLabel, '${session.name} · ${session.qth}'),
                    field('UTC', date),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  s.conditionLabel(session.condition),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.secondary,
                  ),
                ),
                const SizedBox(height: 6),
                // A dit-dah border strip, for flavour.
                Text(
                  '·−·· ·−·· ·−·· 73',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontFamily: monoFont,
                    color: scheme.outline,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplainSheet extends StatelessWidget {
  const _ExplainSheet({required this.line, required this.entries});

  final String line;
  final List<GlossEntry> entries;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(s.whatTheySaid, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                line,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontFamily: monoFont, fontSize: 15),
              ),
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              Text(s.nothingToDecode, style: theme.textTheme.bodyLarge)
            else
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        constraints: const BoxConstraints(minWidth: 64),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          e.token,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontFamily: monoFont,
                            fontWeight: FontWeight.w500,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            e.meaning,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _QsoOptions extends StatelessWidget {
  const _QsoOptions();

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text(s.qsoYourCallsign),
              subtitle: Text(s.callsignHelp),
              trailing: Text(
                settings.callsign,
                textDirection: TextDirection.ltr,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontFamily: monoFont),
              ),
              onTap: () => _editCallsign(context, settings),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.hearing_rounded),
              title: Text(s.copyByEar),
              subtitle: Text(s.copyByEarSub),
              value: settings.qsoCopyByEar,
              onChanged: (v) => settings.qsoCopyByEar = v,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.campaign_outlined),
              title: Text(s.playMyMessages),
              subtitle: Text(s.playMyMessagesSub),
              value: settings.qsoPlayMine,
              onChanged: (v) => settings.qsoPlayMine = v,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _editCallsign(BuildContext context, Settings settings) async {
    final s = context.s;
    final controller = TextEditingController(text: settings.callsign);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.qsoYourCallsign),
        content: TextField(
          controller: controller,
          autofocus: true,
          textDirection: TextDirection.ltr,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [_UpperCase()],
          style: const TextStyle(fontFamily: monoFont),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(s.save),
          ),
        ],
      ),
    );
    controller.dispose();
    final call = value?.trim().toUpperCase() ?? '';
    // Only letters, digits and a slash are sendable in a callsign.
    if (RegExp(r'^[A-Z0-9/]{3,10}$').hasMatch(call)) settings.callsign = call;
  }
}

/// Message text with the sounding character lit, sent ones solid and the
/// rest faint, in step with the audio.
class _LiveText extends StatelessWidget {
  const _LiveText({required this.line, required this.color});

  final _Line line;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cursor = line.cursor;
    final base = TextStyle(
      fontFamily: monoFont,
      fontSize: 16,
      height: 1.5,
      letterSpacing: 0.5,
      color: color,
    );
    if (cursor == null) {
      return Text(line.text, textDirection: TextDirection.ltr, style: base);
    }
    final spans = <InlineSpan>[];
    var index = 0;
    for (var w = 0; w < line.tokens.length; w++) {
      if (w > 0) spans.add(const TextSpan(text: ' '));
      for (final token in line.tokens[w]) {
        final style = index == cursor
            ? base.copyWith(
                backgroundColor: colors.signalGlow,
                fontWeight: FontWeight.w700,
              )
            : index < cursor
            ? base
            : base.copyWith(color: color.withValues(alpha: 0.35));
        spans.add(TextSpan(text: token, style: style));
        index++;
      }
    }
    return Text.rich(
      TextSpan(children: spans),
      textDirection: TextDirection.ltr,
    );
  }
}

/// A message as dots and dashes, word by word. Tapping a word swaps it for
/// its letters (and back), for when a word can't be read from the code.
class _CodeWords extends StatelessWidget {
  const _CodeWords({
    required this.line,
    required this.color,
    required this.progressive,
    required this.onToggleWord,
  });

  final _Line line;
  final Color color;

  /// Show only what has been heard so far.
  final bool progressive;
  final ValueChanged<int> onToggleWord;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final cursor = line.cursor;
    final words = <Widget>[];
    var index = 0;
    for (var w = 0; w < line.tokens.length; w++) {
      final tokens = line.tokens[w];
      final start = index;
      index += tokens.length;
      if (progressive && (cursor == null || start > cursor)) break;
      final decoded = line.decodedWords.contains(w);
      final shown = progressive ? tokens.take(cursor! - start + 1) : tokens;
      final wordIndex = w;
      words.add(
        Pressable(
          scale: 0.92,
          onTap: progressive ? null : () => onToggleWord(wordIndex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: decoded ? scheme.secondaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: decoded
                ? Text(
                    tokens.join(),
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontFamily: monoFont,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSecondaryContainer,
                    ),
                  )
                : Wrap(
                    spacing: 7,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (var t = 0; t < shown.length; t++)
                        MorsePattern(
                          encodeToken(tokens[t])!,
                          size: 7,
                          color: cursor == start + t
                              ? colors.signal
                              : color.withValues(
                                  alpha: cursor != null && start + t > cursor
                                      ? 0.35
                                      : 0.9,
                                ),
                        ),
                    ],
                  ),
          ),
        ),
      );
    }
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: words.isEmpty ? [const SizedBox(height: 18)] : words,
      ),
    );
  }
}

/// Reply composer for dots & dashes mode: key letters with two dit/dah
/// buttons or a single telegraph key and watch them decode.
class _KeyComposer extends StatefulWidget {
  const _KeyComposer({
    required this.controller,
    required this.enabled,
    required this.singleKey,
    required this.onSingleKeyChanged,
    required this.onSend,
  });

  /// Holds the decoded reply, shared with the text composer.
  final TextEditingController controller;
  final bool enabled;
  final bool singleKey;
  final ValueChanged<bool> onSingleKeyChanged;
  final VoidCallback onSend;

  @override
  State<_KeyComposer> createState() => _KeyComposerState();
}

class _KeyComposerState extends State<_KeyComposer> {
  late MorsePlayer _player;
  late Settings _settings;
  Keyer? _keyer;
  bool? _keyerSingle;
  String _pending = '';
  final _held = <Contact>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    _player = scope.player;
    _settings = scope.settings;
  }

  @override
  void dispose() {
    _keyer?.dispose();
    _player.keyUp();
    super.dispose();
  }

  Keyer _ensureKeyer() {
    if (_keyer == null || _keyerSingle != widget.singleKey) {
      _keyer?.dispose();
      _keyerSingle = widget.singleKey;
      _keyer = Keyer(
        type: widget.singleKey ? KeyType.straight : KeyType.tapButtons,
        unitMs: _settings.timing.unitMs,
        onTone: (on) => on ? _player.keyDown() : _player.keyUp(),
        onPending: (p) {
          if (mounted) setState(() => _pending = p);
        },
        onLetter: _onLetter,
        onWordGap: _onWordGap,
      );
    }
    return _keyer!;
  }

  void _onLetter(String pattern) {
    final char =
        decodePattern(pattern) ??
        prosigns.entries
            .where((e) => e.value == pattern)
            .map((e) => '<${e.key}>')
            .firstOrNull;
    if (char == null) {
      if (_settings.hapticsEnabled) HapticFeedback.heavyImpact();
      return;
    }
    _append(char);
  }

  void _onWordGap() {
    final t = widget.controller.text;
    if (t.isNotEmpty && !t.endsWith(' ')) _append(' ');
  }

  void _append(String s) {
    final c = widget.controller;
    c.text = c.text + s;
    c.selection = TextSelection.collapsed(offset: c.text.length);
  }

  void _backspace() {
    _keyer?.flush();
    final t = widget.controller.text.trimRight();
    if (t.isEmpty) {
      widget.controller.clear();
      return;
    }
    final prosign = RegExp(r'<[A-Z]+>$').firstMatch(t);
    widget.controller.text = prosign != null
        ? t.substring(0, prosign.start)
        : t.substring(0, t.length - 1);
  }

  void _press(Contact c) {
    if (!widget.enabled) return;
    if (_settings.hapticsEnabled) HapticFeedback.selectionClick();
    setState(() => _held.add(c));
    _ensureKeyer().press(c);
  }

  void _release(Contact c) {
    setState(() => _held.remove(c));
    _keyer?.release(c);
  }

  void _send() {
    _keyer?.flush();
    widget.onSend();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // What has been keyed so far, letter by letter.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (context, value, _) {
              final words = tokensFor(value.text);
              return Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 58),
                padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: scheme.outlineVariant, width: 1.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: words.isEmpty && _pending.isEmpty
                          ? Text(
                              s.keyYourReply,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              reverse: true,
                              child: Row(
                                textDirection: TextDirection.ltr,
                                children: [
                                  for (final word in words) ...[
                                    for (final t in word)
                                      _KeyedLetter(token: t),
                                    const SizedBox(width: 12),
                                  ],
                                  if (_pending.isNotEmpty)
                                    MorsePattern(
                                      _pending,
                                      size: 7,
                                      color: context.colors.signal,
                                    ),
                                ],
                              ),
                            ),
                    ),
                    IconButton(
                      tooltip: s.backspace,
                      onPressed: widget.enabled ? _backspace : null,
                      icon: const Icon(Icons.backspace_outlined),
                    ),
                    IconButton(
                      tooltip: s.space,
                      onPressed: widget.enabled ? _onWordGap : null,
                      icon: const Icon(Icons.space_bar_rounded),
                    ),
                    Pressable(
                      onTap: widget.enabled && value.text.trim().isNotEmpty
                          ? _send
                          : null,
                      child: Tooltip(
                        message: s.sendReply,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                widget.enabled && value.text.trim().isNotEmpty
                                ? scheme.primary
                                : scheme.surfaceContainerHighest,
                          ),
                          child: Icon(
                            Icons.send_rounded,
                            textDirection: TextDirection.ltr,
                            size: 20,
                            color:
                                widget.enabled && value.text.trim().isNotEmpty
                                ? scheme.onPrimary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            segments: [
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.more_horiz_rounded),
                label: Text(s.keyStyleTwo),
              ),
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.radio_button_checked_rounded),
                label: Text(s.keyStyleSingle),
              ),
            ],
            selected: {widget.singleKey},
            onSelectionChanged: (v) => widget.onSingleKeyChanged(v.first),
          ),
          const SizedBox(height: 8),
          Opacity(
            opacity: widget.enabled ? 1 : 0.5,
            child: KeyPad(
              type: widget.singleKey ? KeyType.straight : KeyType.tapButtons,
              swapped: _settings.swapPaddles,
              held: _held,
              height: 84,
              onPress: _press,
              onRelease: _release,
            ),
          ),
        ],
      ),
    );
  }
}

/// A keyed character: its letter above its code.
class _KeyedLetter extends StatelessWidget {
  const _KeyedLetter({required this.token});

  final String token;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            token.replaceAll(RegExp('[<>]'), ''),
            style: TextStyle(
              fontFamily: monoFont,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          MorsePattern(encodeToken(token) ?? '', size: 5),
        ],
      ),
    );
  }
}
