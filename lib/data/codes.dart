import 'dart:math';

/// A code with its plain-language meaning, for reference and course levels.
typedef CodeEntry = ({String code, String meaning});

const List<CodeEntry> qCodes = [
  (code: 'QRL', meaning: 'Is this frequency in use?'),
  (code: 'QRM', meaning: 'Interference from other stations'),
  (code: 'QRN', meaning: 'Static / atmospheric noise'),
  (code: 'QRO', meaning: 'Increase power'),
  (code: 'QRP', meaning: 'Decrease power / low power'),
  (code: 'QRQ', meaning: 'Send faster'),
  (code: 'QRS', meaning: 'Send slower'),
  (code: 'QRT', meaning: 'Stop sending / closing down'),
  (code: 'QRU', meaning: 'Have you anything for me?'),
  (code: 'QRV', meaning: 'I am ready'),
  (code: 'QRX', meaning: 'Wait / stand by'),
  (code: 'QRZ', meaning: 'Who is calling me?'),
  (code: 'QSB', meaning: 'Your signal is fading'),
  (code: 'QSK', meaning: 'Full break-in'),
  (code: 'QSL', meaning: 'I acknowledge receipt'),
  (code: 'QSO', meaning: 'A contact / conversation'),
  (code: 'QSP', meaning: 'Relay a message'),
  (code: 'QST', meaning: 'General call to all stations'),
  (code: 'QSX', meaning: 'I am listening on ...'),
  (code: 'QSY', meaning: 'Change frequency'),
  (code: 'QTC', meaning: 'Messages to send'),
  (code: 'QTH', meaning: 'My location is ...'),
  (code: 'QTR', meaning: 'The correct time is ...'),
  (code: 'QRG', meaning: 'Your exact frequency is ...'),
];

const List<CodeEntry> abbreviations = [
  (code: 'CQ', meaning: 'Calling any station'),
  (code: 'DE', meaning: 'From / this is'),
  (code: 'K', meaning: 'Over, go ahead'),
  (code: 'R', meaning: 'Received / roger'),
  (code: 'TU', meaning: 'Thank you'),
  (code: 'TNX', meaning: 'Thanks'),
  (code: 'FB', meaning: 'Fine business (excellent)'),
  (code: 'OM', meaning: 'Old man (any male operator)'),
  (code: 'YL', meaning: 'Young lady (any female operator)'),
  (code: 'UR', meaning: 'Your / you are'),
  (code: 'RST', meaning: 'Readability, strength, tone report'),
  (code: 'NAME', meaning: 'Operator name follows'),
  (code: 'HR', meaning: 'Here'),
  (code: 'ES', meaning: 'And'),
  (code: 'WX', meaning: 'Weather'),
  (code: 'RIG', meaning: 'Radio equipment'),
  (code: 'ANT', meaning: 'Antenna'),
  (code: 'PWR', meaning: 'Power'),
  (code: 'AGN', meaning: 'Again'),
  (code: 'PSE', meaning: 'Please'),
  (code: 'GM', meaning: 'Good morning'),
  (code: 'GA', meaning: 'Good afternoon / go ahead'),
  (code: 'GE', meaning: 'Good evening'),
  (code: 'GN', meaning: 'Good night'),
  (code: 'HW', meaning: 'How (do you copy)?'),
  (code: 'CUL', meaning: 'See you later'),
  (code: '73', meaning: 'Best regards'),
  (code: '88', meaning: 'Love and kisses'),
  (code: '5NN', meaning: 'Contest report 599'),
  (code: 'BK', meaning: 'Break'),
  (code: 'ABT', meaning: 'About'),
  (code: 'ADR', meaning: 'Address'),
  (code: 'AGE', meaning: 'Age'),
  (code: 'ANS', meaning: 'Answer'),
  (code: 'B4', meaning: 'Before'),
  (code: 'BCNU', meaning: 'Be seeing you'),
  (code: 'BTR', meaning: 'Better'),
  (code: 'BTU', meaning: 'Back to you'),
  (code: 'CFM', meaning: 'Confirm'),
  (code: 'CL', meaning: 'Closing station'),
  (code: 'CLG', meaning: 'Calling'),
  (code: 'CONDX', meaning: 'Conditions'),
  (code: 'CPY', meaning: 'Copy'),
  (code: 'CUAGN', meaning: 'See you again'),
  (code: 'CW', meaning: 'Continuous wave (Morse)'),
  (code: 'DR', meaning: 'Dear'),
  (code: 'DX', meaning: 'Distant station'),
  (code: 'ENUF', meaning: 'Enough'),
  (code: 'FER', meaning: 'For'),
  (code: 'FREQ', meaning: 'Frequency'),
  (code: 'GD', meaning: 'Good'),
  (code: 'GL', meaning: 'Good luck'),
  (code: 'GUD', meaning: 'Good'),
  (code: 'HI', meaning: 'Laughter'),
  (code: 'HPE', meaning: 'Hope'),
  (code: 'HVY', meaning: 'Heavy'),
  (code: 'INFO', meaning: 'Information'),
  (code: 'MNI', meaning: 'Many'),
  (code: 'MSG', meaning: 'Message'),
  (code: 'N', meaning: 'No'),
  (code: 'NR', meaning: 'Number / near'),
  (code: 'NW', meaning: 'Now'),
  (code: 'OB', meaning: 'Old boy'),
  (code: 'OP', meaning: 'Operator'),
  (code: 'OT', meaning: 'Old timer'),
  (code: 'RCVR', meaning: 'Receiver'),
  (code: 'RFI', meaning: 'Radio interference'),
  (code: 'RPT', meaning: 'Repeat / report'),
  (code: 'RX', meaning: 'Receiver'),
  (code: 'SIG', meaning: 'Signal'),
  (code: 'SKED', meaning: 'Schedule'),
  (code: 'SRI', meaning: 'Sorry'),
  (code: 'STN', meaning: 'Station'),
  (code: 'SUM', meaning: 'Some'),
  (code: 'SWL', meaning: 'Shortwave listener'),
  (code: 'TEMP', meaning: 'Temperature'),
  (code: 'TKS', meaning: 'Thanks'),
  (code: 'TMW', meaning: 'Tomorrow'),
  (code: 'TRX', meaning: 'Transceiver'),
  (code: 'TX', meaning: 'Transmitter'),
  (code: 'U', meaning: 'You'),
  (code: 'VY', meaning: 'Very'),
  (code: 'WID', meaning: 'With'),
  (code: 'WKD', meaning: 'Worked'),
  (code: 'WL', meaning: 'Well / will'),
  (code: 'WPM', meaning: 'Words per minute'),
  (code: 'XYL', meaning: 'Wife'),
  (code: 'YRS', meaning: 'Years / yours'),
];

const List<CodeEntry> prosignEntries = [
  (code: '<AR>', meaning: 'End of message'),
  (code: '<SK>', meaning: 'End of contact'),
  (code: '<BT>', meaning: 'Break / new paragraph'),
  (code: '<KN>', meaning: 'Over, named station only'),
  (code: '<AS>', meaning: 'Wait'),
  (code: '<CT>', meaning: 'Start of transmission'),
  (code: '<VE>', meaning: 'Understood'),
  (code: '<BK>', meaning: 'Break-in'),
  (code: '<SOS>', meaning: 'Distress'),
  (code: '<HH>', meaning: 'Error, correction follows'),
];

/// Short sentences for the sentence levels, roughly easiest first.
const List<String> sentences = [
  'I AM HERE',
  'SEE YOU SOON',
  'THE SUN IS UP',
  'GOOD MORNING',
  'IT IS COLD',
  'HOW ARE YOU',
  'I LIKE MORSE',
  'THE WIND IS STRONG',
  'MEET ME AT NOON',
  'WE ARE READY',
  'THANK YOU VERY MUCH',
  'WHAT IS YOUR NAME',
  'MY NAME IS SAM',
  'THE RADIO WORKS',
  'CALL ME LATER',
  'RAIN IS COMING',
  'THE CAT IS ASLEEP',
  'KEEP IT SIMPLE',
  'PRACTICE MAKES PERFECT',
  'SEND IT AGAIN PLEASE',
  'CQ CQ DE W1AW K',
  'UR RST 599 5NN',
  'QTH IS BOSTON',
  'TNX FER QSO 73',
  'WX HR IS SUNNY',
  'RIG HR IS QRP',
  'PSE QRS',
  'NAME HR IS ANN',
  'GM OM TNX FER CALL',
  'HW CPY? <BK>',
  'GOOD EVENING OM',
  'WX HR IS RAINY',
  'ANT IS A DIPOLE',
  'RIG IS A KIT',
  'PWR IS FIVE WATTS',
  'THE BAND IS OPEN',
  'CONDX ARE GOOD TODAY',
  'I AM NEW TO CW',
  'SEND SLOWER PLEASE',
  'HOW IS THE WEATHER',
  'MY KEY IS A PADDLE',
  'I LIVE NEAR THE SEA',
  'THE STORM IS COMING',
  'LISTEN FOR THE RHYTHM',
  'WE MEET EVERY MONDAY',
  'THE CLUB HAS A NET',
  'QSL VIA BURO',
  'SRI QRM AGN PSE',
  'FB OM TNX FER RPT',
  'GL ES 73 <SK>',
];

const _prefixes = [
  'W',
  'K',
  'N',
  'AA',
  'KB',
  'KD',
  'WA',
  'VE',
  'VA',
  'G',
  'M',
  'F',
  'DL',
  'DK',
  'I',
  'EA',
  'ON',
  'PA',
  'OH',
  'SM',
  'LA',
  'OZ',
  'JA',
  'VK',
  'ZL',
  'PY',
  'LU',
  'UA',
  'SP',
  'OK',
  'HB9',
  'EI',
  'YO',
  'LZ',
  '9A',
  'S5',
];

/// Generates a plausible amateur radio callsign, e.g. `DL3ABC`.
String randomCallsign(Random r, {int maxSuffix = 3}) {
  const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  final prefix = _prefixes[r.nextInt(_prefixes.length)];
  final digit = r.nextInt(10);
  final suffixLength = 1 + r.nextInt(maxSuffix);
  final suffix = List.generate(
    suffixLength,
    (_) => letters[r.nextInt(letters.length)],
  ).join();
  return '$prefix$digit$suffix';
}

/// Building blocks for generated QSO (contact) exchanges.
const qsoNames = [
  'ANN',
  'BOB',
  'SAM',
  'JOE',
  'LIZ',
  'TOM',
  'EVA',
  'MAX',
  'ALI',
  'KIM',
  'JOHN',
  'MARY',
  'PAUL',
  'NINA',
  'OMID',
  'SARA',
  'HANS',
  'YUKI',
  'RAJ',
  'LEO',
];
const qsoPlaces = [
  'BOSTON',
  'DENVER',
  'TEXAS',
  'OHIO',
  'LONDON',
  'PARIS',
  'BERLIN',
  'ROME',
  'TOKYO',
  'SYDNEY',
  'TEHRAN',
  'OSLO',
  'MADRID',
  'DUBLIN',
  'TORONTO',
  'LIMA',
];
const qsoRigs = ['IC 7300', 'K3', 'FT 991', 'KX2', 'QCX', 'HOMEBREW', 'TS 590'];
const qsoAntennas = ['DIPOLE', 'VERTICAL', 'YAGI', 'LOOP', 'END FED', 'WIRE'];
const qsoWeather = [
  'SUNNY',
  'CLOUDY',
  'RAINY',
  'WINDY',
  'COLD',
  'WARM',
  'SNOW',
];

String _pick(Random r, List<String> xs) => xs[r.nextInt(xs.length)];

String _rst(Random r) => '5${3 + r.nextInt(7)}9';

/// Generated QSO phrases, by stage of a contact.
String qsoOpener(Random r) {
  final c = randomCallsign(r);
  return 'CQ CQ DE $c $c K';
}

String qsoReport(Random r) {
  final rst = _rst(r);
  return r.nextBool() ? 'UR RST $rst $rst' : 'TNX FER CALL UR $rst';
}

String qsoNamePlace(Random r) => r.nextBool()
    ? 'NAME HR IS ${_pick(r, qsoNames)}'
    : 'QTH IS ${_pick(r, qsoPlaces)}';

String qsoStation(Random r) => switch (r.nextInt(4)) {
  0 => 'RIG HR IS ${_pick(r, qsoRigs)}',
  1 => 'ANT IS ${_pick(r, qsoAntennas)}',
  2 => 'PWR IS ${(1 + r.nextInt(10)) * 10} W',
  _ => 'WX HR IS ${_pick(r, qsoWeather)}',
};

String qsoSignOff(Random r) => _pick(r, [
  'TNX FER QSO 73 <SK>',
  'GL ES 73 CUL <SK>',
  'TNX ${_pick(r, qsoNames)} 73 <SK>',
  'HPE CUAGN 73 <SK>',
]);

String qsoAny(Random r) => switch (r.nextInt(5)) {
  0 => qsoOpener(r),
  1 => qsoReport(r),
  2 => qsoNamePlace(r),
  3 => qsoStation(r),
  _ => qsoSignOff(r),
};
