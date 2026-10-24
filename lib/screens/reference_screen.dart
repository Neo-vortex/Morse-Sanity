import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../course/course.dart';
import '../data/codes.dart';
import '../morse/morse_code.dart';
import '../widgets/morse_pattern.dart';
import '../l10n/strings.dart';
import '../data/nato.dart';

enum _ChartView {
  characters,
  prosigns,
  qCodes,
  abbreviations,
  nato;

  String label(S s) => switch (this) {
    characters => s.chartCharacters,
    prosigns => s.chartProsigns,
    qCodes => s.chartQCodes,
    abbreviations => s.chartAbbreviations,
    nato => s.chartNato,
  };
}

/// Tappable chart of every character and common code.
class ReferenceScreen extends StatefulWidget {
  const ReferenceScreen({super.key});

  @override
  State<ReferenceScreen> createState() => _ReferenceScreenState();
}

class _ReferenceScreenState extends State<ReferenceScreen> {
  _ChartView _view = _ChartView.characters;
  bool _courseOrder = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final v in _ChartView.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(v.label(context.s)),
                        selected: _view == v,
                        onSelected: (_) => setState(() => _view = v),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_view == _ChartView.characters) ..._characterSlivers(theme),
        if (_view == _ChartView.prosigns) _codeList(prosignEntries),
        if (_view == _ChartView.qCodes) _codeList(qCodes),
        if (_view == _ChartView.abbreviations) _codeList(abbreviations),
        if (_view == _ChartView.nato) ..._natoSlivers(theme),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  List<Widget> _characterSlivers(ThemeData theme) {
    final s = context.s;
    final sections = _courseOrder
        ? [(s.courseOrder, letterOrder), (s.numbers, digits)]
        : [
            (s.letters, letters),
            (s.numbers, digits),
            (s.punctuation, punctuation),
          ];
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(
                child: Text(s.tapToHear, style: theme.textTheme.bodyMedium),
              ),
              FilterChip(
                label: Text(s.courseOrder),
                selected: _courseOrder,
                onSelected: (v) => setState(() => _courseOrder = v),
              ),
            ],
          ),
        ),
      ),
      for (final (title, chars) in sections) ...[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 120,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.1,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _CharCard(char: chars[i]),
              childCount: chars.length,
            ),
          ),
        ),
      ],
    ];
  }

  List<Widget> _natoSlivers(ThemeData theme) {
    final s = context.s;
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        sliver: SliverToBoxAdapter(
          child: Text(s.natoChartIntro, style: theme.textTheme.bodyMedium),
        ),
      ),
      for (final (title, entries) in [
        (s.letters, natoLetters),
        (s.numbers, natoDigits),
      ]) ...[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _NatoTile(entry: entries[i]),
              childCount: entries.length,
            ),
          ),
        ),
      ],
    ];
  }

  Widget _codeList(List<CodeEntry> entries) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      sliver: SliverList.builder(
        itemCount: entries.length,
        itemBuilder: (context, i) => _CodeTile(entry: entries[i]),
      ),
    );
  }
}

class _CharCard extends StatelessWidget {
  const _CharCard({required this.char});

  final String char;

  @override
  Widget build(BuildContext context) {
    final player = AppScope.of(context).player;
    final pattern = encodeChar(char)!;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => player.playPattern(pattern),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                char,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              FittedBox(child: MorsePattern(pattern, size: 8)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeTile extends StatelessWidget {
  const _CodeTile({required this.entry});

  final CodeEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = AppScope.of(context).player;
    final isProsign = entry.code.startsWith('<');
    final label = isProsign
        ? entry.code.substring(1, entry.code.length - 1)
        : entry.code;
    return Card(
      child: ListTile(
        onTap: () => player.playText(entry.code),
        title: Row(
          children: [
            Text(
              label,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                decoration: isProsign ? TextDecoration.overline : null,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final p in patternsFor(entry.code).expand((w) => w))
                    MorsePattern(p, size: 7),
                ],
              ),
            ),
          ],
        ),
        subtitle: Text(context.s.codeMeaning(entry.code, entry.meaning)),
        trailing: const Icon(Icons.volume_up),
      ),
    );
  }
}

class _NatoTile extends StatelessWidget {
  const _NatoTile({required this.entry});

  final NatoEntry entry;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                entry.symbol,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    child: Text(
                      entry.word,
                      textDirection: TextDirection.ltr,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFamily: 'JetBrainsMono',
                      ),
                    ),
                  ),
                  FittedBox(
                    child: Text(
                      s.fa ? entry.sayFa : entry.say,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
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
