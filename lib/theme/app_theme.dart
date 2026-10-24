import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../l10n/strings.dart';

/// Brand colours that Material's [ColorScheme] has no slot for.
///
/// The palette is "night radio": warm paper and ink navy as the base, with
/// signal amber (the glow of a lamp) as the hero colour used sparingly for
/// the main action and for anything that lights up.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.signal,
    required this.signalGlow,
    required this.lampOff,
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.star,
    required this.streak,
    required this.challenge,
    required this.mascotBody,
    required this.mascotFace,
    required this.confetti,
  });

  /// Lit lamp / hero accent.
  final Color signal;
  final Color signalGlow;
  final Color lampOff;
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color star;
  final Color streak;
  final Color challenge;
  final Color mascotBody;
  final Color mascotFace;
  final List<Color> confetti;

  static const light = AppColors(
    signal: Color(0xFFFFB020),
    signalGlow: Color(0x66FFB020),
    lampOff: Color(0xFFE9DFCB),
    success: Color(0xFF1F9D5B),
    onSuccess: Colors.white,
    successContainer: Color(0xFFD3F2DF),
    star: Color(0xFFFFC531),
    streak: Color(0xFFFF7A1A),
    challenge: Color(0xFF6B5BD6),
    mascotBody: Color(0xFF1E2A44),
    mascotFace: Color(0xFF1A2233),
    confetti: [
      Color(0xFFFFB020),
      Color(0xFF1B6E7A),
      Color(0xFF6B5BD6),
      Color(0xFFFF7A1A),
      Color(0xFF1F9D5B),
    ],
  );

  static const dark = AppColors(
    signal: Color(0xFFFFC14D),
    signalGlow: Color(0x77FFC14D),
    lampOff: Color(0xFF2B3A56),
    success: Color(0xFF4BD38A),
    onSuccess: Color(0xFF00391C),
    successContainer: Color(0xFF103D27),
    star: Color(0xFFFFCF4D),
    streak: Color(0xFFFF9445),
    challenge: Color(0xFFA99BFF),
    mascotBody: Color(0xFF34466A),
    mascotFace: Color(0xFF0E1626),
    confetti: [
      Color(0xFFFFC14D),
      Color(0xFF5CC6D0),
      Color(0xFFA99BFF),
      Color(0xFFFF9445),
      Color(0xFF4BD38A),
    ],
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      signal: l(signal, other.signal),
      signalGlow: l(signalGlow, other.signalGlow),
      lampOff: l(lampOff, other.lampOff),
      success: l(success, other.success),
      onSuccess: l(onSuccess, other.onSuccess),
      successContainer: l(successContainer, other.successContainer),
      star: l(star, other.star),
      streak: l(streak, other.streak),
      challenge: l(challenge, other.challenge),
      mascotBody: l(mascotBody, other.mascotBody),
      mascotFace: l(mascotFace, other.mascotFace),
      confetti: t < 0.5 ? confetti : other.confetti,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;

  /// True when the user asked the OS to reduce motion.
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;
}

const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFFFFB020),
  onPrimary: Color(0xFF1A1408),
  primaryContainer: Color(0xFFFFE8B8),
  onPrimaryContainer: Color(0xFF4A3000),
  secondary: Color(0xFF1B6E7A),
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFCDEDEF),
  onSecondaryContainer: Color(0xFF063B42),
  tertiary: Color(0xFF6B5BD6),
  onTertiary: Colors.white,
  tertiaryContainer: Color(0xFFE4E0FF),
  onTertiaryContainer: Color(0xFF251A73),
  error: Color(0xFFD9363E),
  onError: Colors.white,
  errorContainer: Color(0xFFFFDAD7),
  onErrorContainer: Color(0xFF5C0C10),
  surface: Color(0xFFFBF6EC),
  onSurface: Color(0xFF1A2233),
  onSurfaceVariant: Color(0xFF5B6475),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFFFFCF5),
  surfaceContainer: Color(0xFFF6EFE1),
  surfaceContainerHigh: Color(0xFFEFE6D4),
  surfaceContainerHighest: Color(0xFFE7DCC6),
  outline: Color(0xFFBDAE93),
  outlineVariant: Color(0xFFE3D7C1),
  shadow: Color(0xFF3B2F1A),
  inverseSurface: Color(0xFF1A2233),
  onInverseSurface: Color(0xFFFBF6EC),
  inversePrimary: Color(0xFFFFC14D),
);

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFFFC14D),
  onPrimary: Color(0xFF2A1C00),
  primaryContainer: Color(0xFF4A3500),
  onPrimaryContainer: Color(0xFFFFE2A8),
  secondary: Color(0xFF5CC6D0),
  onSecondary: Color(0xFF00363C),
  secondaryContainer: Color(0xFF0F4B53),
  onSecondaryContainer: Color(0xFFC5F1F5),
  tertiary: Color(0xFFA99BFF),
  onTertiary: Color(0xFF241A6B),
  tertiaryContainer: Color(0xFF3A2F8F),
  onTertiaryContainer: Color(0xFFE4E0FF),
  error: Color(0xFFFF6B6B),
  onError: Color(0xFF4A0006),
  errorContainer: Color(0xFF6E1419),
  onErrorContainer: Color(0xFFFFDAD7),
  surface: Color(0xFF0E1626),
  onSurface: Color(0xFFEEF1F7),
  onSurfaceVariant: Color(0xFFA5AFC2),
  surfaceContainerLowest: Color(0xFF0A111E),
  surfaceContainerLow: Color(0xFF131D30),
  surfaceContainer: Color(0xFF18243A),
  surfaceContainerHigh: Color(0xFF1F2C45),
  surfaceContainerHighest: Color(0xFF283752),
  outline: Color(0xFF4A5A78),
  outlineVariant: Color(0xFF26344D),
  shadow: Colors.black,
  inverseSurface: Color(0xFFEEF1F7),
  onInverseSurface: Color(0xFF0E1626),
  inversePrimary: Color(0xFFE08A00),
);

bool _persianScript = false;

/// Switches the app's typefaces for the language being shown. Persian uses
/// Vazirmatn throughout; Latin faces have no Persian glyphs.
void useFontsFor(AppLanguage language) =>
    _persianScript = language == AppLanguage.persian;

/// Display face for headings; rounded body face for everything else.
String get displayFont => _persianScript ? 'Vazirmatn' : 'SpaceGrotesk';
String get bodyFont => _persianScript ? 'Vazirmatn' : 'Nunito';
const monoFont = 'JetBrainsMono';

/// Letter-spacing for decorative text. Spacing breaks connected Persian
/// script, so it is dropped there.
double tracking(double latin) => _persianScript ? 0 : latin;

ThemeData buildTheme(Brightness brightness, AppLanguage language) {
  useFontsFor(language);
  final scheme = brightness == Brightness.light ? _lightScheme : _darkScheme;
  final colors = brightness == Brightness.light
      ? AppColors.light
      : AppColors.dark;

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: bodyFont,
    fontFamilyFallback: const ['Vazirmatn'],
    brightness: brightness,
  );
  TextStyle? display(TextStyle? s, {FontWeight weight = FontWeight.w700}) =>
      s?.copyWith(
        fontFamily: displayFont,
        fontWeight: weight,
        letterSpacing: -0.5,
      );
  final t = base.textTheme;
  final textTheme = t.copyWith(
    displayLarge: display(t.displayLarge),
    displayMedium: display(t.displayMedium),
    displaySmall: display(t.displaySmall),
    headlineLarge: display(t.headlineLarge),
    headlineMedium: display(t.headlineMedium),
    headlineSmall: display(t.headlineSmall),
    titleLarge: display(t.titleLarge),
    titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w800),
    labelMedium: t.labelMedium?.copyWith(fontWeight: FontWeight.w700),
    bodyLarge: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
    bodyMedium: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
  );

  const pill = StadiumBorder();
  final buttonText = TextStyle(
    fontFamily: bodyFont,
    fontWeight: FontWeight.w800,
    fontSize: 16,
    letterSpacing: tracking(0.2),
  );

  return base.copyWith(
    textTheme: textTheme,
    extensions: [colors],
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontSize: 22,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outlineVariant, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: pill,
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: pill,
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        side: BorderSide(color: scheme.outline, width: 2),
        foregroundColor: scheme.onSurface,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: pill,
        foregroundColor: scheme.secondary,
        textStyle: buttonText,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: const StadiumBorder(),
      side: BorderSide(color: scheme.outlineVariant, width: 1.5),
      labelStyle: TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w700),
      selectedColor: scheme.primaryContainer,
      checkmarkColor: scheme.onPrimaryContainer,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: scheme.primary,
        selectedForegroundColor: scheme.onPrimary,
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outlineVariant, width: 1.5),
        textStyle: buttonText.copyWith(fontSize: 14),
        minimumSize: const Size(0, 46),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.primaryContainer,
      surfaceTintColor: Colors.transparent,
      height: 70,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: bodyFont,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
        ),
      ),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: scheme.primary,
      thumbColor: scheme.primary,
      inactiveTrackColor: scheme.surfaceContainerHighest,
      valueIndicatorColor: scheme.inverseSurface,
      year2023: false,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? scheme.onPrimary : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? scheme.primary : null,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      // ignore: deprecated_member_use
      year2023: false,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(
        fontFamily: bodyFont,
        fontWeight: FontWeight.w700,
        color: scheme.onInverseSurface,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: TextStyle(
        fontFamily: bodyFont,
        fontWeight: FontWeight.w700,
        color: scheme.onInverseSurface,
      ),
    ),
  );
}
