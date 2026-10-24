import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morse_sanity/course/course.dart';
import 'package:morse_sanity/l10n/strings.dart';
import 'package:morse_sanity/main.dart';
import 'package:morse_sanity/services/morse_player.dart';
import 'package:morse_sanity/services/progress.dart';
import 'package:morse_sanity/services/settings.dart';
import 'package:morse_sanity/widgets/morse_keyboard.dart';
import 'package:morse_sanity/widgets/motion.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(MorseSanityApp, Progress)> _buildApp({bool onboarded = true}) async {
  SharedPreferences.setMockInitialValues({'settings.onboarded': onboarded});
  final prefs = await SharedPreferences.getInstance();
  final settings = Settings(prefs);
  final progress = Progress(prefs);
  return (
    MorseSanityApp(
      settings: settings,
      progress: progress,
      player: MorsePlayer(settings, audioEnabled: false),
    ),
    progress,
  );
}

/// Dit and the level map animate forever unless the OS asks for reduced
/// motion, which also keeps pumpAndSettle usable.
void _reduceMotion(WidgetTester tester) {
  // Also use a phone-sized screen.
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Finder _chunky(String label) => find.descendant(
  of: find.byType(ChunkyButton),
  matching: find.text(label.toUpperCase()),
);

Finder _key(String label) =>
    find.descendant(of: find.byType(MorseKeyboard), matching: find.text(label));

void main() {
  testWidgets('home shows the course and navigates tabs', (tester) async {
    _reduceMotion(tester);
    final (app, _) = await _buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.text('E T'), findsOneWidget);
    expect(find.text('Letters'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(find.text('E T'), findsOneWidget);

    await tester.tap(find.text('Translate'));
    await tester.pumpAndSettle();
    expect(find.text('... --- ...'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'hi');
    await tester.pump();
    expect(find.text('.... ..'), findsOneWidget);

    await tester.tap(find.text('Chart'));
    await tester.pumpAndSettle();
    expect(find.text('Tap a character to hear it'), findsOneWidget);
    final qChip = find.widgetWithText(ChoiceChip, 'Q-codes');
    await tester.ensureVisible(qChip);
    await tester.pumpAndSettle();
    await tester.tap(qChip);
    await tester.pumpAndSettle();
    expect(find.text('Is this frequency in use?'), findsOneWidget);
  });

  testWidgets('a receive level runs through to the results page', (
    tester,
  ) async {
    _reduceMotion(tester);
    final (app, progress) = await _buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    // Tapping a level opens its preview sheet.
    await tester.tap(find.text('E T'));
    await tester.pumpAndSettle();
    expect(find.text('Letters: E T'), findsOneWidget);
    await tester.tap(_chunky('Start'));
    await tester.pumpAndSettle();

    var correct = 0;
    for (var round = 0; round < 20; round++) {
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(_key('E'));
      await tester.pump();
      final next = _chunky('Continue');
      if (next.evaluate().isNotEmpty) {
        await tester.pumpAndSettle();
        await tester.tap(next);
        await tester.pump();
      } else {
        correct++;
        await tester.pump(const Duration(milliseconds: 800));
      }
    }
    await tester.pumpAndSettle();
    expect(find.text('Back to map'), findsOneWidget);
    final stars = starsFor(correct / 20);
    expect(progress.starsFor('receive-1'), stars);
    expect(progress.totalXp, correct + stars * 5);
    expect(progress.streak, correct > 0 ? 1 : 0);
    // Let the player's playback timeline run out.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('free keying decodes a straight key', (tester) async {
    _reduceMotion(tester);
    final (app, _) = await _buildApp();
    await tester.pumpWidget(app);
    await tester.tap(find.text('Practice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Free keying'));
    await tester.pumpAndSettle();

    final key = find.text('KEY');
    Future<void> press(int ms) async {
      final g = await tester.startGesture(tester.getCenter(key));
      await tester.pump(Duration(milliseconds: ms));
      await g.up();
      await tester.pump(const Duration(milliseconds: 60));
    }

    // A: dit dah at 20 WPM (60 ms unit).
    await press(60);
    await press(180);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
    // The word gap after the letter adds a space.
    expect(find.text('A '), findsOneWidget);
  });

  testWidgets('onboarding asks for a name and goal', (tester) async {
    _reduceMotion(tester);
    final (app, _) = await _buildApp(onboarded: false);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    expect(find.text('Hi! I’m Dit.'), findsOneWidget);

    await tester.tap(_chunky('Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.tap(_chunky('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Serious'));
    await tester.tap(_chunky('Let’s go'));
    await tester.pumpAndSettle();

    expect(find.text('E T'), findsOneWidget);
    expect(find.textContaining('Ada'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('language can be switched to Persian during onboarding', (
    tester,
  ) async {
    _reduceMotion(tester);
    final (app, _) = await _buildApp(onboarded: false);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('فارسی'));
    await tester.pumpAndSettle();
    expect(find.text('سلام! من دیتم.'), findsOneWidget);
    final dir = Directionality.of(tester.element(find.text('سلام! من دیتم.')));
    expect(dir, TextDirection.rtl);

    await tester.tap(_chunky('ادامه'));
    await tester.pumpAndSettle();
    await tester.tap(_chunky('ادامه'));
    await tester.pumpAndSettle();
    await tester.tap(_chunky('بزن بریم'));
    await tester.pumpAndSettle();
    expect(find.text('دوره'), findsWidgets);
    expect(find.text('حروف'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a Persian receive level runs to results in RTL', (tester) async {
    _reduceMotion(tester);
    SharedPreferences.setMockInitialValues({
      'settings.onboarded': true,
      'settings.language': 'fa',
    });
    final prefs = await SharedPreferences.getInstance();
    final settings = Settings(prefs);
    final progress = Progress(prefs);
    await tester.pumpWidget(
      MorseSanityApp(
        settings: settings,
        progress: progress,
        player: MorsePlayer(settings, audioEnabled: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('E T'));
    await tester.pumpAndSettle();
    expect(find.text('حروف: E T'), findsOneWidget);
    await tester.tap(_chunky('شروع'));
    await tester.pumpAndSettle();
    for (var round = 0; round < 20; round++) {
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(_key('T'));
      await tester.pump();
      final next = _chunky('ادامه');
      if (next.evaluate().isNotEmpty) {
        await tester.pumpAndSettle();
        await tester.tap(next);
      }
      await tester.pump(const Duration(milliseconds: 1000));
    }
    await tester.pumpAndSettle();
    expect(find.text('بازگشت به نقشه'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('language can be changed back in settings', (tester) async {
    _reduceMotion(tester);
    SharedPreferences.setMockInitialValues({
      'settings.onboarded': true,
      'settings.language': 'fa',
    });
    final prefs = await SharedPreferences.getInstance();
    final settings = Settings(prefs);
    await tester.pumpWidget(
      MorseSanityApp(
        settings: settings,
        progress: Progress(prefs),
        player: MorsePlayer(settings, audioEnabled: false),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('تنظیمات'));
    await tester.pumpAndSettle();
    expect(find.text('زبان'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    expect(settings.languageCode, 'en');
  });

  test('Persian digits', () {
    final fa = S.of(const Locale('fa'));
    expect(fa.n(2025), '۲۰۲۵');
    expect(fa.percent(90), '۹۰٪');
    expect(S.of(const Locale('en')).n(42), '42');
  });

  test('Progress unlocks characters only at the pass mark', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final progress = Progress(prefs);
    expect(progress.unlocked, ['K', 'M']);
    expect(progress.completeLesson(0.85), isFalse);
    expect(progress.completeLesson(0.9), isTrue);
    expect(progress.unlocked, ['K', 'M', 'U']);
    progress.record('K', correct: true);
    progress.record('K', correct: false);

    final reloaded = Progress(prefs);
    expect(reloaded.level, 3);
    expect(reloaded.statsFor('K').accuracy, 0.5);
  });
}
