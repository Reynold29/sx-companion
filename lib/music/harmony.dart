import '../midi/yamaha_sysex.dart';

class HarmonyKey {
  const HarmonyKey({required this.tonic, required this.minor});

  final int tonic;
  final bool minor;

  String get label =>
      '${YamahaSysex.rootNames[tonic % 12]} ${minor ? 'minor' : 'major'}';

  HarmonyKey copyWith({int? tonic, bool? minor}) {
    return HarmonyKey(tonic: tonic ?? this.tonic, minor: minor ?? this.minor);
  }
}

class ScaleChord {
  const ScaleChord({
    required this.roman,
    required this.degree,
    required this.rootPc,
    required this.chordType,
    required this.function,
  });

  final String roman;
  final int degree;
  final int rootPc;
  final int chordType;
  final String function;

  String get name {
    final root = YamahaSysex.rootNames[rootPc % 12];
    final type = YamahaSysex.chordTypeNames[chordType] ?? '';
    if (type == 'Maj') return root;
    if (type == 'min') return '${root}m';
    if (type == 'dim') return '$root°';
    return '$root$type';
  }
}

/// Diatonic triads (and V7 in minor) for arranger ACMP.
List<ScaleChord> diatonicChords(HarmonyKey key) {
  if (key.minor) {
    const intervals = [0, 2, 3, 5, 7, 8, 10];
    const types = [8, 17, 0, 8, 19, 0, 0]; // i, ii°, III, iv, V7, VI, VII
    const romans = ['i', 'ii°', 'III', 'iv', 'V7', 'VI', 'VII'];
    const functions = ['Tonic', 'Supertonic', 'Mediant', 'Subdominant', 'Dominant', 'Submediant', 'Subtonic'];
    return [
      for (var i = 0; i < 7; i++)
        ScaleChord(
          roman: romans[i],
          degree: i + 1,
          rootPc: (key.tonic + intervals[i]) % 12,
          chordType: types[i],
          function: functions[i],
        ),
    ];
  }
  const intervals = [0, 2, 4, 5, 7, 9, 11];
  const types = [0, 8, 8, 0, 0, 8, 17]; // I ii iii IV V vi vii°
  const romans = ['I', 'ii', 'iii', 'IV', 'V', 'vi', 'vii°'];
  const functions = ['Tonic', 'Supertonic', 'Mediant', 'Subdominant', 'Dominant', 'Submediant', 'Leading'];
  return [
    for (var i = 0; i < 7; i++)
      ScaleChord(
        roman: romans[i],
        degree: i + 1,
        rootPc: (key.tonic + intervals[i]) % 12,
        chordType: types[i],
        function: functions[i],
      ),
  ];
}

class CommonChordType {
  const CommonChordType(this.id, this.label);
  final int id;
  final String label;
}

const acmpChordTypes = <CommonChordType>[
  CommonChordType(0, 'Maj'),
  CommonChordType(8, 'min'),
  CommonChordType(19, '7'),
  CommonChordType(10, 'min7'),
  CommonChordType(2, 'Maj7'),
  CommonChordType(32, 'sus4'),
  CommonChordType(17, 'dim'),
  CommonChordType(18, 'dim7'),
  CommonChordType(7, 'aug'),
  CommonChordType(1, '6'),
  CommonChordType(9, 'min6'),
  CommonChordType(20, '7sus4'),
  CommonChordType(4, 'add9'),
  CommonChordType(12, 'min9'),
  CommonChordType(22, '9'),
  CommonChordType(25, '7b9'),
  CommonChordType(27, '7#9'),
  CommonChordType(11, 'm7b5'),
  CommonChordType(15, 'minMaj7'),
  CommonChordType(5, 'Maj9'),
  CommonChordType(21, '7b5'),
  CommonChordType(24, '7(13)'),
  CommonChordType(3, 'Maj7#11'),
  CommonChordType(14, 'min11'),
  CommonChordType(6, '6/9'),
  CommonChordType(13, 'min7(9)'),
  CommonChordType(16, 'minMaj9'),
  CommonChordType(23, '7#11'),
  CommonChordType(26, '7b13'),
  CommonChordType(28, 'Maj7aug'),
  CommonChordType(29, '7aug'),
  CommonChordType(30, '1+8'),
  CommonChordType(31, '1+5'),
  CommonChordType(33, '1+2+5'),
  CommonChordType(34, 'cc'),
];
