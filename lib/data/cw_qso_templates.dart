/// Template pools for the simulated CW contact, keyed by what the other
/// operator is doing. Slots in braces are filled from the session:
/// {my_call} {their_call} {rst} {name} {qth} {rig} {condition} {wx}.
library;

/// The other station calling CQ, before the user answers.
const qsoCqTemplates = [
  'CQ CQ CQ DE {their_call} {their_call} K',
  'CQ CQ DE {their_call} {their_call} {their_call} K',
  'CQ DE {their_call} {their_call} K',
];

/// Reply to the user's greeting: greet back and send our report.
const qsoGreetingTemplates = [
  '{my_call} DE {their_call} GE TNX FER CALL UR RST {rst} {rst} NAME {name} QTH {qth} HW? {my_call} DE {their_call} KN',
  'R {my_call} DE {their_call} FB OM UR RST {rst} {rst} NAME HR {name} {name} QTH {qth} BK',
  '{my_call} DE {their_call} TNX CALL ES GE UR {rst} {rst} OP {name} QTH {qth} HW CPY? KN',
];

/// Acknowledging the user's report, then describing conditions.
const qsoReportReceivedTemplates = [
  'R R TNX FER RPT {user_rst} CONDX HR {condition} HW CONDX UR END? BK',
  'FB TNX {user_rst} RPT {condition} HR HW UR CONDX? KN',
  'R QSL {user_rst} TNX OM {condition} ON BAND TODAY HW? BK',
];

/// After the conditions comment: a little station small talk.
const qsoConditionsTemplates = [
  'R R FB RIG HR {rig} ES WX {wx} BK',
  'QSL CONDX TNX RIG IS {rig} WX HR {wx} HW? KN',
  'FB OM HR RIG {rig} ANT DIPOLE WX {wx} BK',
];

/// After small talk: start wrapping up.
const qsoSmalltalkTemplates = [
  'FB OM TNX FER INFO NICE QSO HPE CUAGN 73 {my_call} DE {their_call} KN',
  'R R TNX FER FB QSO {name} WILL QRT NW 73 ES GL {my_call} DE {their_call} KN',
];

/// Wrapping up when the conversation reaches its exchange limit.
const qsoWrapUpTemplates = [
  'TNX FER QSO MUST QRT NW 73 {my_call} DE {their_call} KN',
  'SRI MUST GO TNX FER FB QSO 73 GL {my_call} DE {their_call} KN',
];

/// Final reply after the user's sign-off.
const qsoFinalTemplates = [
  'TU 73 <SK> E E',
  'R TU {name} 73 GL <SK>',
  'TNX 73 CUL <SK> E E',
];

/// The other operator didn't understand.
const qsoUnclearTemplates = [
  'QRZ? KN',
  'AGN? KN',
  'PSE AGN KN',
  'SRI QRM PSE RPT KN',
];

/// Condition phrases for the {condition} slot.
const qsoConditionPhrases = {
  'clear': ['CONDX FB', 'BAND CLR', 'SIGS CLR'],
  'lightQsb': ['SUM QSB', 'LITTLE QSB', 'SLIGHT QSB'],
  'heavyQsb': ['HVY QSB', 'DEEP QSB', 'BAD QSB'],
  'qrm': ['QRM HR', 'HVY QRM', 'SUM QRM'],
  'qrn': ['QRN HR', 'HVY QRN', 'STATIC QRN'],
};

/// Example replies the coach offers, keyed by what the other operator is
/// waiting for. Same slots as above.
const qsoUserExamples = {
  'greeting': [
    '{their_call} DE {my_call} GE OM K',
    '{their_call} DE {my_call} {my_call} K',
  ],
  'report': [
    'R R UR RST 599 599 BK',
    'TNX FER CALL UR 579 579 HW? BK',
    'UR 5NN 5NN BK',
  ],
  'conditions': ['CONDX FB HR', 'SUM QSB HR', 'QRM HR SRI'],
  'smalltalk': ['RIG HR KX2 ANT DIPOLE', 'WX HR SUNNY ES WARM'],
  'signOff': ['TNX FER QSO 73 <SK>', 'TU 73 GL <SK>'],
};
