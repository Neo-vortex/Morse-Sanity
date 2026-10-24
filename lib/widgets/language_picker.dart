import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../l10n/strings.dart';

/// Pill toggle for the app language. Each option is written in its own
/// language and font so it is recognisable whatever is currently shown.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return SegmentedButton<AppLanguage>(
      showSelectedIcon: false,
      segments: [
        for (final l in AppLanguage.values)
          ButtonSegment(
            value: l,
            label: Text(
              l.nativeName,
              style: TextStyle(
                fontFamily: l == AppLanguage.persian ? 'Vazirmatn' : 'Nunito',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
      selected: {settings.language},
      onSelectionChanged: (s) => settings.languageCode = s.first.code,
    );
  }
}
