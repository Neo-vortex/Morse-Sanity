import 'package:flutter/widgets.dart';

import '../course/course.dart';
import '../morse/keyer.dart';
import '../services/settings.dart';

/// Languages the app speaks.
enum AppLanguage {
  english('en', 'English'),
  persian('fa', 'فارسی');

  const AppLanguage(this.code, this.nativeName);
  final String code;
  final String nativeName;

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) =>
      values.firstWhere((l) => l.code == code, orElse: () => english);
}

extension StringsContext on BuildContext {
  S get s => S.of(Localizations.localeOf(this));
}

/// All user-facing text, English and Persian side by side.
///
/// Dit's voice is the same in both languages: a warm, slightly nerdy radio
/// operator who encourages and never scolds. Persian uses the friendly
/// informal "تو" and keeps the odd bit of ham lingo with a gloss.
class S {
  S._(this.fa);

  static final _en = S._(false);
  static final _fa = S._(true);

  static S of(Locale locale) => locale.languageCode == 'fa' ? _fa : _en;

  final bool fa;

  String _t(String en, String fa) => this.fa ? fa : en;

  /// Formats numbers with Persian digits when speaking Persian.
  String n(Object value) {
    final text = '$value';
    if (!fa) return text;
    const western = '0123456789%';
    const persian = '۰۱۲۳۴۵۶۷۸۹٪';
    final b = StringBuffer();
    for (final ch in text.split('')) {
      final i = western.indexOf(ch);
      b.write(i < 0 ? ch : persian[i]);
    }
    return b.toString();
  }

  // --- Common --------------------------------------------------------------

  String get appName => _t('Morse Sanity', 'مورس سنیتی');
  String get ditName => _t('Dit', 'دیت');
  String get cancel => _t('Cancel', 'انصراف');
  String get save => _t('Save', 'ذخیره');
  String get reset => _t('Reset', 'بازنشانی');
  String get start => _t('Start', 'شروع');
  String get next => _t('Next', 'بعدی');
  String get done => _t('Done', 'تمام');
  String get continueLabel => _t('Continue', 'ادامه');
  String get tryAgain => _t('Try again', 'دوباره امتحان کن');
  String get backToMap => _t('Back to map', 'بازگشت به نقشه');
  String get playAgain => _t('Play again', 'پخش دوباره');
  String get quit => _t('Quit', 'خروج');
  String get receive => _t('Receive', 'دریافت');
  String get send => _t('Send', 'ارسال');
  String trackLabel(Track t) => t == Track.receive ? receive : send;
  String get settings => _t('Settings', 'تنظیمات');
  String get statistics => _t('Statistics', 'آمار');
  String get correct => _t('Correct!', 'درسته!');
  String get listen => _t('Listen', 'گوش بده');
  String get backspace => _t('Backspace', 'پاک کردن');
  String get space => _t('Space', 'فاصله');
  String get submit => _t('Submit', 'ثبت');
  String get dit => _t('dit', 'دیت');
  String get dah => _t('dah', 'داه');
  String wpm(int v) => _t('$v WPM', '${n(v)} کلمه در دقیقه');

  // --- Home ----------------------------------------------------------------

  String get tabCourse => _t('Course', 'دوره');
  String get tabPractice => _t('Practice', 'تمرین');
  String get tabTranslate => _t('Translate', 'مترجم');
  String get tabChart => _t('Chart', 'جدول');
  String get titleChart => _t('Code chart', 'جدول کدها');
  String streakTooltip(int d) => _t('$d-day streak', 'زنجیرهٔ ${n(d)} روزه');
  String xpTooltip(int xp, int goal) =>
      _t('$xp / $goal XP today', '${n(xp)} از ${n(goal)} امتیاز امروز');

  // --- Course map ----------------------------------------------------------

  String sectionName(String section) => !fa
      ? section
      : switch (section) {
          'Letters' => 'حروف',
          'Numbers' => 'اعداد',
          'Punctuation' => 'علائم نگارشی',
          'Prosigns' => 'پروساین‌ها',
          'Q-codes' => 'کدهای Q',
          'Abbreviations' => 'اختصارها',
          'Words' => 'کلمات',
          'Callsigns' => 'شناسه‌های رادیویی',
          'Sentences' => 'جمله‌ها',
          _ => section,
        };

  String sectionBlurb(String section) => switch (section) {
    'Letters' => _t(
      'The alphabet, easiest sounds first',
      'الفبای لاتین، از ساده‌ترین صداها',
    ),
    'Numbers' => _t(
      'Zero to nine, five dits and dahs each',
      'صفر تا نه، هر کدام پنج دیت و داه',
    ),
    'Punctuation' => _t(
      'Full stops, question marks and friends',
      'نقطه، علامت سؤال و رفقا',
    ),
    'Prosigns' => _t(
      'Run-together signals like AR and SK',
      'سیگنال‌های چسبیده مثل AR و SK',
    ),
    'Q-codes' => _t(
      'QTH? QRS? The radio shorthand',
      'زبان کوتاه‌نویسی رادیو، مثل QTH و QRS',
    ),
    'Abbreviations' => _t(
      'TNX, FB, 73 and other ham classics',
      'TNX، FB، ۷۳ و کلاسیک‌های آماتوری',
    ),
    'Words' => _t(
      'Hear whole words, not letters',
      'کل کلمه را بشنو، نه تک‌حرف‌ها را',
    ),
    'Callsigns' => _t(
      'Copy stations from around the world',
      'ایستگاه‌هایی از سراسر دنیا',
    ),
    _ => _t('Real messages, start to finish', 'پیام‌های واقعی، از اول تا آخر'),
  };

  /// Level titles are stored in English; translate the descriptive ones.
  String levelTitle(String title) {
    if (!fa) return title;
    final m = RegExp(r'^(.*?)(?: (\d+))?$').firstMatch(title)!;
    final base = m.group(1)!;
    final num = m.group(2);
    final name = switch (base) {
      'Review' => 'مرور',
      'Review all' => 'مرور کامل',
      'Challenge' => 'چالش',
      'Short words' => 'کلمات کوتاه',
      'Medium words' => 'کلمات متوسط',
      'Long words' => 'کلمات بلند',
      'Very long words' => 'کلمات خیلی بلند',
      'All words' => 'همهٔ کلمات',
      'Simple calls' => 'شناسه‌های ساده',
      'Two-letter suffix' => 'پسوند دوحرفی',
      'Full calls' => 'شناسه‌های کامل',
      'Portable calls' => 'شناسه‌های سیار',
      'Sentences' => 'جمله‌ها',
      _ => null,
    };
    if (name == null) return title;
    return num == null ? name : '$name ${n(num)}';
  }

  String get startBadge => _t('START', 'شروع');
  String levelHeader(Track t, int number) => _t(
    '${trackLabel(t).toUpperCase()} · LEVEL $number',
    '${trackLabel(t)} · مرحلهٔ ${n(number)}',
  );
  String levelHeading(String section, String title) =>
      '${sectionName(section)}: ${levelTitle(title)}';
  String previewChallenge(int rounds) => _t(
    'Timed, no hints. Show what you know! $rounds rounds.',
    'زمان‌دار و بدون راهنما. نشان بده چه بلدی! ${n(rounds)} دور.',
  );
  String previewNew(int rounds) => _t(
    'New this level. Tap one to hear it. $rounds rounds.',
    'جدیدهای این مرحله. روی هر کدام بزن تا بشنوی. ${n(rounds)} دور.',
  );
  String previewRounds(int rounds, String section) => _t(
    '$rounds rounds of ${section.toLowerCase()}.',
    '${n(rounds)} دور ${sectionName(section)}.',
  );
  String get practiseAgain => _t('Practise again', 'دوباره تمرین کن');
  String levelUnlocked(int number, String title) => _t(
    'Level $number unlocked: $title',
    'مرحلهٔ ${n(number)} باز شد: ${levelTitle(title)}',
  );
  String newBest(int stars) =>
      _t('New best: $stars stars!', 'رکورد تازه: ${n(stars)} ستاره!');
  String get challengeRetry => _t(
    'Challenges can be retried as often as you like.',
    'چالش‌ها را هر چند بار که بخواهی می‌توانی تکرار کنی.',
  );

  // --- Onboarding ----------------------------------------------------------

  String get chooseLanguage => _t('Language', 'زبان');
  String get hiImDit => _t('Hi! I’m Dit.', 'سلام! من دیتم.');
  String get introBody => _t(
    'I’m a little signal lamp. I’ll blink, beep and buzz Morse code at you '
        'until it feels like a second language.',
    'من یک چراغ سیگنال کوچولو هستم. آن‌قدر برایت چشمک می‌زنم، بوق می‌زنم '
        'و می‌لرزم تا کد مورس برایت مثل زبان دوم شود.',
  );
  String get tapToSayHi => _t('Tap me to say hi', 'رویم بزن تا سلام کنم');
  String get nameBubble => _t(
    'Every operator has a name on the air. What’s yours?',
    'هر اپراتوری روی موج یک اسم دارد. اسم تو چیه؟',
  );
  String get namePlaceholder => _t('Your name (optional)', 'اسمت (اختیاری)');
  String get nameSkip => _t(
    'You can skip this. I’ll just call you “operator”.',
    'می‌توانی رد شوی. آن‌وقت صدایت می‌کنم «اپراتور».',
  );
  String get goalBubble => _t(
    'A little every day beats a lot once a week. Pick a daily goal:',
    'هر روز کمی، بهتر از هفته‌ای یک‌بار زیاد. هدف روزانه‌ات را انتخاب کن:',
  );
  String get letsGo => _t('Let’s go', 'بزن بریم');
  String goalName(int xp) => switch (xp) {
    10 => _t('Casual', 'آرام'),
    30 => _t('Regular', 'منظم'),
    60 => _t('Serious', 'جدی'),
    _ => _t('Intense', 'پرشور'),
  };
  String goalBlurb(int xp) => switch (xp) {
    10 => _t('About 3 minutes a day', 'حدود ۳ دقیقه در روز'),
    30 => _t('About 10 minutes a day', 'حدود ۱۰ دقیقه در روز'),
    60 => _t('About 20 minutes a day', 'حدود ۲۰ دقیقه در روز'),
    _ => _t(
      'For aspiring contest operators',
      'برای اپراتورهای مسابقه‌ای آینده',
    ),
  };
  String xp(int v) => _t('$v XP', '${n(v)} امتیاز');

  // --- Sessions ------------------------------------------------------------

  String get typeWhatYouHear => _t('Type what you hear', 'هرچه می‌شنوی بنویس');
  List<String> get hintTooltips => [
    _t('Hint: show the code', 'راهنما: نشان دادن کد'),
    _t('Hint: show codes on the keyboard', 'راهنما: کدها روی صفحه‌کلید'),
    _t('Hint: show the answer', 'راهنما: نشان دادن جواب'),
    _t('No more hints', 'راهنمای دیگری نمانده'),
  ];
  List<String> get hintLines => [
    '',
    _t('Here’s what I blinked.', 'این چیزی است که چشمک زدم.'),
    _t(
      'Codes are on the keys now. Find the match!',
      'کدها حالا روی کلیدها هستند. جفتش را پیدا کن!',
    ),
    _t('There’s the answer. Next one’s yours!', 'این هم جواب. بعدی مال خودت!'),
  ];
  String get notQuite => _t('Not quite', 'نه دقیقاً');
  String get timesUpTitle => _t('Time’s up', 'وقت تمام شد');
  String answerIs(String a) => _t('Answer: $a', 'جواب: $a');
  String get timeUpSuffix => _t('(time up)', '(وقت تمام شد)');
  String get sendThis => _t('SEND THIS', 'این را بفرست');
  String get changeKey => _t('Change key', 'تغییر کلید');
  String get hideCode => _t('Hide code', 'پنهان کردن کد');
  String get showCode => _t('Show code', 'نمایش کد');
  String get startOver => _t('Start over', 'از نو');
  String get keyboardHintPaddles =>
      _t('Keyboard: ← → arrow keys or [ ]', 'صفحه‌کلید: کلیدهای ← → یا [ ]');
  String get keyboardHintStraight =>
      _t('Keyboard: hold the space bar', 'صفحه‌کلید: کلید فاصله را نگه دار');
  String get freeKeying => _t('Free keying', 'ارسال آزاد');
  String get freeKeyingLine => _t(
    'Tap out anything. I’ll decode it for you.',
    'هرچه دوست داری بزن. برایت رمزگشایی‌اش می‌کنم.',
  );
  String get freeKeyingPlaceholder => _t(
    'Start keying. Your text appears here.',
    'شروع کن. متنت اینجا ظاهر می‌شود.',
  );
  String approxWpm(int v) => _t('~$v WPM', 'حدود ${n(v)} کلمه در دقیقه');
  String keyPadLabel(KeyType type, bool left) => switch (type) {
    KeyType.straight => _t('KEY', 'کلید'),
    KeyType.tapButtons ||
    KeyType.singleLever ||
    KeyType.iambicA ||
    KeyType.iambicB => left ? _t('DIT', 'دیت') : _t('DAH', 'داه'),
    KeyType.sideswiper => left ? _t('LEFT', 'چپ') : _t('RIGHT', 'راست'),
    KeyType.bug => left ? _t('DITS', 'دیت‌ها') : _t('DAH', 'داه'),
  };

  // --- Results -------------------------------------------------------------

  String get accuracy => _t('Accuracy', 'دقت');
  String get xpEarned => _t('XP earned', 'امتیاز');
  String get streak => _t('Streak', 'زنجیره');
  String get streakPlusOne => _t('Streak +1!', 'زنجیره +۱!');
  String get nextLevel => _t('Next level', 'مرحلهٔ بعد');
  String get worthAnotherListen =>
      _t('Worth another listen', 'ارزش یک بار دیگر شنیدن را دارد');
  String youTyped(String a) => _t('You typed: $a', 'نوشتی: $a');
  String youSent(String a) => _t('You sent: $a', 'فرستادی: $a');

  // --- Dit's voice ---------------------------------------------------------

  List<String> greetings(String name, int hour) {
    final who = name.isEmpty ? _t('operator', 'اپراتور') : name;
    if (hour < 5) {
      return [
        _t('Burning the midnight oil, $who?', 'نصفه‌شب هم بیداری، $who؟'),
        _t('Night shift on the key, $who?', 'شیفت شب پشت کلید، $who؟'),
      ];
    }
    if (hour < 12) {
      return [
        _t('GM, $who! Good morning.', 'صبح بخیر، $who! (GM یعنی همین)'),
        _t('Morning, $who. Lamp’s warm.', 'صبحت بخیر $who. چراغ گرم است.'),
      ];
    }
    if (hour < 18) {
      return [
        _t('GA, $who! Good afternoon.', 'عصر بخیر، $who!'),
        _t('Hey $who, ready to tap?', 'سلام $who، آماده‌ای بزنیم؟'),
      ];
    }
    return [
      _t('GE, $who! Good evening.', 'شب بخیر، $who! (GE)'),
      _t(
        'Evening, $who. Perfect radio weather.',
        'شبت خوش $who. هوا برای رادیو عالی است.',
      ),
    ];
  }

  List<String> nudgeGoalMet() => [
    _t(
      'Daily goal done. FB! (That’s “fine business”.)',
      'هدف امروز انجام شد. عالی! (به زبان رادیو: FB)',
    ),
    _t(
      'Goal reached. Anything more is a bonus round.',
      'به هدف رسیدی. هرچه بیشتر، جایزه است.',
    ),
    _t(
      'You’ve earned a rest. Or one more level?',
      'حقت است استراحت کنی. یا یک مرحلهٔ دیگر؟',
    ),
  ];

  List<String> nudgeNoStreak() => [
    _t(
      'Let’s light up a new streak today.',
      'بیا امروز یک زنجیرهٔ تازه روشن کنیم.',
    ),
    _t(
      'One level is all it takes to start a streak.',
      'برای شروع زنجیره فقط یک مرحله کافی است.',
    ),
    _t(
      'Dits and dahs, warmed up and waiting.',
      'دیت‌ها و داه‌ها گرم شده‌اند و منتظرند.',
    ),
  ];

  List<String> nudgeStreak(int d) => [
    _t(
      '$d-day streak! Let’s keep it glowing.',
      'زنجیرهٔ ${n(d)} روزه! بگذار روشن بماند.',
    ),
    _t(
      'Don’t let the $d-day streak go dark!',
      'نگذار زنجیرهٔ ${n(d)} روزه خاموش شود!',
    ),
    _t(
      'Day ${d + 1} is calling. CQ CQ!',
      'روز ${n(d + 1)} صدایت می‌زند: CQ CQ',
    ),
  ];

  List<String> sessionStart(bool sending) => sending
      ? [
          _t('Your turn on the key.', 'نوبت توست پشت کلید.'),
          _t(
            'Nice and steady. Rhythm beats speed.',
            'آرام و یکنواخت. ریتم مهم‌تر از سرعت است.',
          ),
          _t('Tap it out. I’ll listen.', 'بزن، من گوش می‌دهم.'),
        ]
      : [
          _t(
            'Listen for the rhythm, not the dots.',
            'به ریتم گوش بده، نه به نقطه‌ها.',
          ),
          _t('Ears on. Here it comes.', 'گوش‌ها آماده. دارد می‌آید.'),
          _t('Don’t count. Just feel the sound.', 'نشمار. فقط صدا را حس کن.'),
        ];

  List<String> correctLines(int combo) {
    if (combo >= 10) {
      return [
        _t(
          '$combo in a row! You’re on fire!',
          '${n(combo)} تا پشت سر هم! آتیش گرفتی!',
        ),
        _t(
          'Unstoppable. $combo straight!',
          'توقف‌ناپذیری. ${n(combo)} تا پیاپی!',
        ),
      ];
    }
    if (combo >= 5) {
      return [
        _t('$combo in a row!', '${n(combo)} تا پشت سر هم!'),
        _t('Hot streak: $combo!', 'داغ داغی: ${n(combo)}!'),
        _t('Look at you go!', 'ببین چه می‌کنی!'),
      ];
    }
    return [
      _t('R R! (Roger that.)', 'گرفتم! (به زبان رادیو: R R)'),
      _t('Nailed it.', 'زدی به هدف.'),
      _t('FB!', 'عالی! (FB)'),
      _t('Yes!', 'آره!'),
      _t('Copied!', 'دریافت شد!'),
      _t('Spot on.', 'دقیقاً همین.'),
    ];
  }

  List<String> wrongLines() => [
    _t('Close! Listen once more.', 'نزدیک بود! یک بار دیگر گوش بده.'),
    _t(
      'Tricky one. You’ll get it next time.',
      'این یکی سخت بود. دفعهٔ بعد می‌گیری‌اش.',
    ),
    _t(
      'No worries. Every operator misses some.',
      'نگران نباش. همهٔ اپراتورها گاهی جا می‌اندازند.',
    ),
    _t(
      'QRM got that one. (That’s interference!)',
      'پارازیت خورد! (به زبان رادیو: QRM)',
    ),
    _t('Almost. Hear the difference?', 'تقریباً. فرقش را می‌شنوی؟'),
  ];

  List<String> timeUpLines() => [
    _t('Time’s up! Quicker next round.', 'وقت تمام شد! دور بعد سریع‌تر.'),
    _t('Too slow for the clock that time.', 'این بار ساعت از تو جلو زد.'),
  ];

  List<String> resultLines(int stars) => switch (stars) {
    3 => [
      _t('Perfect copy! 73 and high fives.', 'دریافت بی‌نقص! ۷۳ و یک بزن قدش!'),
      _t('Three stars. You’re a natural!', 'سه ستاره. استعدادش را داری!'),
      _t(
        'Flawless. Lamp’s glowing with pride.',
        'بی‌عیب. چراغم از افتخار می‌درخشد.',
      ),
    ],
    2 => [
      _t(
        'Solid copy! One more star to grab.',
        'دریافت محکم! یک ستارهٔ دیگر مانده.',
      ),
      _t('Great work. So close to perfect.', 'عالی بود. خیلی نزدیک به بی‌نقص.'),
    ],
    1 => [
      _t('Passed! Practice makes perfect.', 'قبول شدی! تمرین، استادت می‌کند.'),
      _t('You made it through. Nice!', 'از پسش برآمدی. آفرین!'),
    ],
    _ => [
      _t(
        'Not quite this time. Let’s try again!',
        'این بار نشد. بیا دوباره امتحان کنیم!',
      ),
      _t(
        'Shaky copy. Another go will sharpen it.',
        'کمی لرزان بود. یک دور دیگر تیزش می‌کند.',
      ),
      _t(
        'Every pro started right here. Again?',
        'هر حرفه‌ای از همین‌جا شروع کرده. دوباره؟',
      ),
    ],
  };

  List<String> lockedLines() => [
    _t(
      'That one’s still dark. Pass the level before it!',
      'آن یکی هنوز خاموش است. اول مرحلهٔ قبلی را رد کن!',
    ),
    _t(
      'Patience, operator. Unlock the previous level first.',
      'صبور باش اپراتور. اول مرحلهٔ قبل را باز کن.',
    ),
  ];

  // --- Practice ------------------------------------------------------------

  String get customChallenge => _t('Custom challenge', 'چالش دلخواه');
  String get customChallengeBlurb => _t(
    'Mix any content, set a time limit and speed. Your rules.',
    'محتوا، زمان و سرعت را خودت بچین. قانون، قانون توست.',
  );
  String get kochMethod => _t('Koch method', 'روش کخ');
  String get kochSub => _t('Classic lessons', 'درس‌های کلاسیک');
  String get freeKeyingSub => _t('Send anything', 'هر چیزی بفرست');
  String get quickDrills => _t('Quick drills', 'تمرین‌های سریع');
  String get charSetKoch => _t('Koch characters', 'حروف روش کخ');
  String get charSetLetters => _t('Letters', 'حروف');
  String get charSetNumbers => _t('Numbers', 'اعداد');
  String get charSetAll => _t('Everything', 'همه چیز');
  String get listenIdentify => _t('Listen & identify', 'بشنو و تشخیص بده');
  String get listenIdentifySub => _t(
    'Hear a character and pick the right one.',
    'یک حرف را بشنو و درستش را انتخاب کن.',
  );
  String get readCode => _t('Read the code', 'کد را بخوان');
  String get readCodeSub => _t(
    'See dots and dashes and name the character.',
    'نقطه و خط‌ها را ببین و حرفش را بگو.',
  );
  String get copyWords => _t('Copy words', 'نوشتن کلمات');
  String get copyWordsSub =>
      _t('Listen to whole words and type them.', 'کلمهٔ کامل را بشنو و بنویس.');
  String drillTitle(String drill, String set) => '$drill: $set';

  // --- Custom challenge ----------------------------------------------------

  String get content => _t('Content', 'محتوا');
  String rounds(int v) => _t('Rounds: $v', 'تعداد دورها: ${n(v)}');
  String get timeLimit =>
      _t('Time limit per item', 'محدودیت زمان برای هر مورد');
  String get none => _t('None', 'ندارد');
  String seconds(int v) => _t('${v}s', '${n(v)} ثانیه');
  String get hintsOffWithTime => _t(
    'Hints are off when a time limit is set.',
    'با محدودیت زمان، راهنما خاموش است.',
  );
  String get customSpeed => _t('Custom speed', 'سرعت دلخواه');
  String speedSummary(int c, int e) => _t(
    '$c WPM characters, $e WPM effective',
    'حروف ${n(c)}، سرعت مؤثر ${n(e)} کلمه در دقیقه',
  );
  String get characterSpeed => _t('Character speed', 'سرعت حروف');
  String get effectiveSpeed =>
      _t('Effective (Farnsworth) speed', 'سرعت مؤثر (فارنزورث)');

  // --- Statistics ----------------------------------------------------------

  String get resetAllProgress =>
      _t('Reset all progress', 'بازنشانی همهٔ پیشرفت');
  String get resetAllQuestion =>
      _t('Reset all progress?', 'همهٔ پیشرفت بازنشانی شود؟');
  String get resetAllBody => _t(
    'Clears course stars, Koch lessons, XP, streaks and all accuracy statistics.',
    'ستاره‌های دوره، درس‌های کخ، امتیازها، زنجیره و همهٔ آمار دقت پاک می‌شوند.',
  );
  String get characterAccuracy => _t('Character accuracy', 'دقت حروف');
  String get noCharsYet =>
      _t('No characters practised yet.', 'هنوز حرفی تمرین نشده.');
  String answersSummary(int attempts, int pct) => _t(
    '$attempts answers, $pct% correct',
    '${n(attempts)} پاسخ، ${n(pct)}٪ درست',
  );
  String needsWork(String list) =>
      _t('Needs work: $list', 'نیاز به تمرین: $list');
  String trackCourse(Track t) =>
      _t('${trackLabel(t)} course', 'دورهٔ ${trackLabel(t)}');
  String trackSummary(
    int passed,
    int total,
    int perfect,
    int ch,
    int chTotal,
    int stars,
  ) => _t(
    '$passed/$total levels passed · $perfect perfect\n'
        '$ch/$chTotal challenges · $stars/${total * 3} stars',
    '${n(passed)} از ${n(total)} مرحله · ${n(perfect)} بی‌نقص\n'
        '${n(ch)} از ${n(chTotal)} چالش · ${n(stars)} از ${n(total * 3)} ستاره',
  );
  String get totalXp => _t('Total XP', 'کل امتیاز');
  String get bestStreak => _t('Best streak', 'بهترین زنجیره');
  String days(int d) => _t('$d days', '${n(d)} روز');
  String get notPractised => _t('Not practised', 'تمرین نشده');
  String correctOf(int c, int a) =>
      _t('$c/$a correct', '${n(c)} از ${n(a)} درست');

  // --- Chart ---------------------------------------------------------------

  String get chartCharacters => _t('Characters', 'حروف');
  String get chartProsigns => _t('Prosigns', 'پروساین‌ها');
  String get chartQCodes => _t('Q-codes', 'کدهای Q');
  String get chartAbbreviations => _t('Abbreviations', 'اختصارها');
  String get tapToHear =>
      _t('Tap a character to hear it', 'روی هر حرف بزن تا صدایش را بشنوی');
  String get courseOrder => _t('Course order', 'ترتیب دوره');
  String get letters => _t('Letters', 'حروف');
  String get numbers => _t('Numbers', 'اعداد');
  String get punctuation => _t('Punctuation', 'علائم نگارشی');

  String codeMeaning(String code, String english) {
    if (!fa) return english;
    return _codeMeaningsFa[code] ?? english;
  }

  static const _codeMeaningsFa = {
    'QRL': 'این فرکانس در حال استفاده است؟',
    'QRM': 'تداخل از ایستگاه‌های دیگر',
    'QRN': 'نویز جوی و الکتریسیتهٔ ساکن',
    'QRO': 'توان را زیاد کن',
    'QRP': 'توان را کم کن / توان پایین',
    'QRQ': 'سریع‌تر بفرست',
    'QRS': 'آهسته‌تر بفرست',
    'QRT': 'ارسال را قطع کن / پایان کار',
    'QRU': 'چیزی برای من داری؟',
    'QRV': 'آماده‌ام',
    'QRX': 'صبر کن / منتظر بمان',
    'QRZ': 'چه کسی صدایم می‌کند؟',
    'QSB': 'سیگنالت ضعیف و قوی می‌شود',
    'QSK': 'ارسال و دریافت همزمان (بریک‌این کامل)',
    'QSL': 'دریافت را تأیید می‌کنم',
    'QSO': 'یک ارتباط / گفتگو',
    'QSP': 'پیام را رله کن',
    'QST': 'فراخوان عمومی برای همهٔ ایستگاه‌ها',
    'QSX': 'روی فرکانس ... گوش می‌دهم',
    'QSY': 'فرکانس را عوض کن',
    'QTC': 'پیام‌هایی برای ارسال',
    'QTH': 'موقعیت من ... است',
    'QTR': 'زمان دقیق ... است',
    'QRG': 'فرکانس دقیق تو ... است',
    'CQ': 'فراخوان برای هر ایستگاهی',
    'DE': 'از طرف / اینجا ...',
    'K': 'تمام، بفرما',
    'R': 'دریافت شد',
    'TU': 'ممنونم',
    'TNX': 'ممنون',
    'FB': 'عالی (fine business)',
    'OM': 'رفیق قدیمی (اپراتور مرد)',
    'YL': 'بانوی جوان (اپراتور زن)',
    'UR': 'مال تو / تو هستی',
    'RST': 'گزارش خوانایی، قدرت و تُن',
    'NAME': 'نام اپراتور در ادامه',
    'HR': 'اینجا',
    'ES': 'و',
    'WX': 'آب‌وهوا',
    'RIG': 'تجهیزات رادیو',
    'ANT': 'آنتن',
    'PWR': 'توان',
    'AGN': 'دوباره',
    'PSE': 'لطفاً',
    'GM': 'صبح بخیر',
    'GA': 'عصر بخیر / بفرما',
    'GE': 'شب بخیر',
    'GN': 'شب خوش (خداحافظی)',
    'HW': 'چطور دریافت می‌کنی؟',
    'CUL': 'بعداً می‌بینمت',
    '73': 'بهترین آرزوها',
    '88': 'عشق و بوسه',
    '5NN': 'گزارش مسابقه‌ای ۵۹۹',
    'BK': 'وقفه',
    '<AR>': 'پایان پیام',
    '<SK>': 'پایان ارتباط',
    '<BT>': 'جداکننده / پاراگراف جدید',
    '<KN>': 'تمام، فقط ایستگاه مخاطب',
    '<AS>': 'صبر کن',
    '<CT>': 'شروع ارسال',
    '<VE>': 'فهمیدم',
    '<BK>': 'بریک‌این',
    '<SOS>': 'درخواست کمک اضطراری',
    '<HH>': 'خطا، تصحیح در ادامه',
  };

  // --- Translator ----------------------------------------------------------

  String get textToMorse => _t('Text → Morse', 'متن ← مورس');
  String get morseToText => _t('Morse → Text', 'مورس ← متن');
  String get text => _t('Text', 'متن');
  String get morseInputLabel => _t('Morse (. - space /)', 'مورس (. - فاصله /)');
  String get morse => _t('Morse', 'مورس');
  String get clear => _t('Clear', 'پاک کردن');
  String get letterGap => _t('letter', 'حرف');
  String get wordGap => _t('word', 'کلمه');
  String get play => _t('Play', 'پخش');
  String get stop => _t('Stop', 'توقف');
  String get copyResult => _t('Copy result', 'کپی نتیجه');
  String get copied => _t('Copied', 'کپی شد');
  String get swapDirection => _t('Swap direction', 'تغییر جهت');
  String get latinOnly => _t(
    'International Morse uses Latin letters, numbers and punctuation.',
    'مورس بین‌المللی با حروف لاتین، اعداد و علائم نگارشی کار می‌کند.',
  );

  // --- Settings ------------------------------------------------------------

  String get language => _t('Language', 'زبان');
  String get systemLanguage => _t('System default', 'مطابق دستگاه');
  String get profile => _t('Profile', 'نمایه');
  String get operatorName => _t('Operator name', 'نام اپراتور');
  String get notSet => _t('Not set', 'تعیین نشده');
  String get dailyGoal => _t('Daily goal', 'هدف روزانه');
  String get themeAuto => _t('Auto', 'خودکار');
  String get themePaper => _t('Paper', 'کاغذی');
  String get themeNight => _t('Night', 'شب');
  String get speed => _t('Speed', 'سرعت');
  String get wordsPerMinute => _t('Words per minute', 'کلمه در دقیقه');
  String get wpmSub =>
      _t('How fast each character is sent', 'هر حرف با چه سرعتی فرستاده شود');
  String get farnsworth => _t('Farnsworth speed', 'سرعت فارنزورث');
  String get farnsworthOn => _t(
    'Extra space between characters and words',
    'فاصلهٔ بیشتر بین حروف و کلمات',
  );
  String get farnsworthOff => _t('Standard spacing', 'فاصله‌گذاری استاندارد');
  String get speedTip => _t(
    'Learn characters at 18–25 WPM so you hear each one as a sound, and '
        'lower the Farnsworth speed for thinking time.',
    'حروف را با سرعت ۱۸ تا ۲۵ کلمه در دقیقه یاد بگیر تا هر کدام را یک '
        'صدای کامل بشنوی، و برای فرصت فکر کردن سرعت فارنزورث را پایین بیاور.',
  );
  String get sound => _t('Sound', 'صدا');
  String get tonePitch => _t('Tone pitch', 'زیر و بمی صدا');
  String hz(int v) => _t('$v Hz', '${n(v)} هرتز');
  String get volume => _t('Volume', 'بلندی صدا');
  String percent(int v) => _t('$v%', '${n(v)}٪');
  String get backgroundNoise => _t('Background noise', 'نویز پس‌زمینه');
  String get noiseSub => _t(
    'Makes copying harder. 10–20% also keeps Bluetooth headphones from '
        'cutting off the first sounds.',
    'دریافت را سخت‌تر می‌کند. ۱۰ تا ۲۰٪ هم کمک می‌کند هدفون بلوتوثی '
        'اولین صداها را نبُرد.',
  );
  String get interfaceSounds => _t('Interface sounds', 'صداهای رابط');
  String get interfaceSoundsSub =>
      _t('Chimes for right and wrong answers', 'زنگ برای جواب‌های درست و غلط');
  String get outputModes => _t('Output modes', 'حالت‌های خروجی');
  String get blinkingLight => _t('Blinking light', 'چراغ چشمک‌زن');
  String get blinkingLightSub => _t('On-screen lamp', 'چراغ روی صفحه');
  String get flashlight => _t('Flashlight', 'چراغ‌قوه');
  String get flashlightSub =>
      _t('Blink the camera flash', 'چشمک زدن فلش دوربین');
  String get vibration => _t('Vibration', 'لرزش');
  String get vibrationSub => _t('Feel the code', 'کد را حس کن');
  String get haptics => _t('Haptic feedback', 'بازخورد لمسی');
  String get hapticsSub => _t('Ticks on key presses', 'تیک کوچک با هر فشار');
  String get testParis => _t('Test: PARIS', 'آزمایش: PARIS');
  String get sendingKey => _t('Sending key', 'کلید ارسال');
  String get swapPaddles => _t('Swap paddles', 'جابه‌جایی پدل‌ها');
  String get swapPaddlesSub =>
      _t('Dah on the left (left-handed)', 'داه در سمت چپ (چپ‌دست‌ها)');
  String get course => _t('Course', 'دوره');
  String get keyboardLayout =>
      _t('Answer keyboard layout', 'چیدمان صفحه‌کلید پاسخ');
  String get keyboardLayoutSub => _t(
    'Switch layouts so you learn sounds, not key positions',
    'چیدمان را عوض کن تا صدا را یاد بگیری، نه جای کلیدها را',
  );
  String layoutName(KeyboardLayout l) =>
      l == KeyboardLayout.random ? _t('Random', 'تصادفی') : l.label;
  String get unlockAll => _t('Unlock all levels', 'باز کردن همهٔ مراحل');
  String get unlockAllSub => _t(
    'Play any level without passing earlier ones',
    'هر مرحله‌ای را بدون رد کردن مراحل قبل بازی کن',
  );
  String get whatToCallYou =>
      _t('What should Dit call you?', 'دیت تو را چه صدا کند؟');
  String get yourName => _t('Your name', 'اسمت');

  String keyLabel(KeyType t) => switch (t) {
    KeyType.straight => _t('Straight key', 'کلید ساده'),
    KeyType.tapButtons => _t('Dit & dah buttons', 'دکمه‌های دیت و داه'),
    KeyType.sideswiper => _t('Sideswiper (cootie)', 'سایدسوایپر (کوتی)'),
    KeyType.bug => _t('Bug (semi-automatic)', 'باگ (نیمه‌خودکار)'),
    KeyType.singleLever => _t('Single-lever paddle', 'پدل تک‌اهرمی'),
    KeyType.iambicA => _t('Iambic paddle – mode A', 'پدل آیامبیک – حالت A'),
    KeyType.iambicB => _t('Iambic paddle – mode B', 'پدل آیامبیک – حالت B'),
  };

  String keyDescription(KeyType t) => switch (t) {
    KeyType.straight => _t(
      'Hold for as long as the element lasts.',
      'به اندازهٔ طول هر علامت نگه دار.',
    ),
    KeyType.tapButtons => _t(
      'Tap one button per dit or dah.',
      'برای هر دیت یا داه یک دکمه بزن.',
    ),
    KeyType.sideswiper => _t(
      'Two manual contacts; alternate sides, you time every element.',
      'دو اتصال دستی؛ دو طرف را یکی‌درمیان بزن و زمان هر علامت با توست.',
    ),
    KeyType.bug => _t(
      'Left makes automatic dits, right is a manual dah.',
      'چپ دیت خودکار می‌سازد، راست داه دستی است.',
    ),
    KeyType.singleLever => _t(
      'Automatic dits on the left, dahs on the right. No squeezing.',
      'دیت خودکار در چپ، داه در راست. بدون فشار همزمان.',
    ),
    KeyType.iambicA => _t(
      'Squeeze both paddles to alternate dits and dahs.',
      'هر دو پدل را با هم فشار بده تا دیت و داه یکی‌درمیان شوند.',
    ),
    KeyType.iambicB => _t(
      'Like mode A, plus one extra element when a squeeze is released.',
      'مثل حالت A، به‌علاوهٔ یک علامت اضافه هنگام رها کردن.',
    ),
  };

  // --- Koch lessons --------------------------------------------------------

  String lesson(int v) => _t('Lesson $v', 'درس ${n(v)}');
  String get kochAllLearned => _t(
    'You have learned every character. Congratulations!',
    'همهٔ حروف را یاد گرفتی. تبریک!',
  );
  String kochPassed(String c) => _t(
    'Lesson passed! New character unlocked: $c',
    'درس را رد کردی! حرف تازه باز شد: $c',
  );
  String get kochComplete =>
      _t('Course complete. Keep it sharp!', 'دوره تمام شد. تیز بمان!');
  String kochReach(int pct) => _t(
    'Reach $pct% to unlock the next character.',
    'به ${n(pct)}٪ برس تا حرف بعدی باز شود.',
  );
  String charsOf(int a, int b) =>
      _t('$a of $b characters', '${n(a)} از ${n(b)} حرف');
  String get courseOptions => _t('Course options', 'گزینه‌های دوره');
  String get jumpToLesson => _t('Jump to lesson…', 'پرش به درس…');
  String get jumpToLessonTitle => _t('Jump to lesson', 'پرش به درس');
  String get resetProgress => _t('Reset progress', 'بازنشانی پیشرفت');
  String get resetProgressQuestion =>
      _t('Reset progress?', 'پیشرفت بازنشانی شود؟');
  String get resetProgressBody => _t(
    'This clears your lesson level and all accuracy statistics.',
    'سطح درس و همهٔ آمار دقت پاک می‌شود.',
  );
  String get firstCharacters => _t('Your first characters', 'اولین حروف تو');
  String get newestCharacter => _t('Newest character', 'تازه‌ترین حرف');
  String get kochTip => _t(
    'Listen to the rhythm rather than counting dots and dashes. Characters '
        'are sent at full speed with extra space between them.',
    'به جای شمردن نقطه و خط، به ریتم گوش بده. حروف با سرعت کامل و با فاصلهٔ '
        'بیشتر بینشان فرستاده می‌شوند.',
  );
  String startLesson(int v) => _t('Start lesson $v', 'شروع درس ${n(v)}');
  String get copyGroups => _t('Copy groups', 'نوشتن گروه‌ها');
  String get copyWordsGroups =>
      _t('Copy words & groups', 'نوشتن کلمات و گروه‌ها');
  String upNext(String c) => _t('Up next: $c', 'بعدی: $c');
  String get yourCharacters => _t('Your characters', 'حروف تو');
  String get set => _t('Set', 'تأیید');
  String lessonChars(int count, String chars) =>
      _t('$count characters: $chars', '${n(count)} حرف: $chars');
  String get notPractisedYet => _t('Not practised yet', 'هنوز تمرین نشده');

  // --- Quick drills --------------------------------------------------------

  String round(int a, int b) => _t('Round $a / $b', 'دور ${n(a)} از ${n(b)}');
  String youChose(String a) => _t('You chose $a', 'انتخابت: $a');
  String get whatCharacter =>
      _t('What character is this?', 'این کدام حرف است؟');
  String get whatDidYouHear => _t('What did you hear?', 'چه شنیدی؟');
  String streakChip(int v) => _t('$v streak', '${n(v)} پیاپی');
  String correctCount(int v) => _t('$v correct', '${n(v)} درست');
  String correctOfTotal(int c, int t) =>
      _t('$c of $t correct', '${n(c)} از ${n(t)} درست');
  String get goAgain => _t('Go again', 'یک دور دیگر');
  String get typeTheWord =>
      _t('Type the word you hear', 'کلمه‌ای را که می‌شنوی بنویس');
  String score(int c, int a) =>
      _t('Score: $c / $a', 'امتیاز: ${n(c)} از ${n(a)}');
  String get yourCopy => _t('Your copy', 'نوشتهٔ تو');
  String get itWas => _t('It was', 'جواب این بود');
  String get check => _t('Check', 'بررسی');
  String get nextWord => _t('Next word', 'کلمهٔ بعد');
  String get skip => _t('Skip', 'رد شدن');
}
