import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_scope.dart';
import 'l10n/strings.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/morse_player.dart';
import 'services/progress.dart';
import 'services/settings.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final font in [
      'Nunito',
      'SpaceGrotesk',
      'JetBrainsMono',
      'Vazirmatn',
    ]) {
      final text = await rootBundle.loadString('assets/fonts/OFL-$font.txt');
      yield LicenseEntryWithLineBreaks([font], text);
    }
  });
  final prefs = await SharedPreferences.getInstance();
  final settings = Settings(prefs);
  runApp(
    MorseSanityApp(
      settings: settings,
      progress: Progress(prefs),
      player: MorsePlayer(settings),
    ),
  );
}

class MorseSanityApp extends StatelessWidget {
  const MorseSanityApp({
    super.key,
    required this.settings,
    required this.progress,
    required this.player,
  });

  final Settings settings;
  final Progress progress;
  final MorsePlayer player;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      settings: settings,
      progress: progress,
      player: player,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          onGenerateTitle: (context) => context.s.appName,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light, settings.language),
          darkTheme: buildTheme(Brightness.dark, settings.language),
          themeMode: settings.themeMode,
          locale: settings.language.locale,
          supportedLocales: [for (final l in AppLanguage.values) l.locale],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: settings.onboarded
              ? const HomeScreen()
              : const OnboardingScreen(),
        ),
      ),
    );
  }
}
