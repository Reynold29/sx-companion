/// Yamaha ACMP chord-type ids (Data List 0–34) → scale intervals from the root.
const yamahaChordIntervals = <int, List<int>>{
  0: [0, 4, 7], // Maj
  1: [0, 4, 7, 9], // 6
  2: [0, 4, 7, 11], // Maj7
  3: [0, 4, 6, 7, 11], // Maj7#11
  4: [0, 2, 4, 7], // add9
  5: [0, 2, 4, 7, 11], // Maj9
  6: [0, 2, 4, 7, 9], // 6/9
  7: [0, 4, 8], // aug
  8: [0, 3, 7], // min
  9: [0, 3, 7, 9], // min6
  10: [0, 3, 7, 10], // min7
  11: [0, 3, 6, 10], // m7b5
  12: [0, 2, 3, 7], // min9
  13: [0, 2, 3, 7, 10], // min7(9)
  14: [0, 2, 3, 5, 7, 10], // min11
  15: [0, 3, 7, 11], // minMaj7
  16: [0, 2, 3, 7, 11], // minMaj9
  17: [0, 3, 6], // dim
  18: [0, 3, 6, 9], // dim7
  19: [0, 4, 7, 10], // 7
  20: [0, 5, 7, 10], // 7sus4
  21: [0, 4, 6, 10], // 7b5
  22: [0, 2, 4, 7, 10], // 9
  23: [0, 4, 6, 7, 10], // 7#11
  24: [0, 4, 7, 9, 10], // 7(13)
  25: [0, 1, 4, 7, 10], // 7b9
  26: [0, 4, 7, 8, 10], // 7b13
  27: [0, 3, 4, 7, 10], // 7#9
  28: [0, 4, 8, 11], // Maj7aug
  29: [0, 4, 8, 10], // 7aug
  30: [0, 12], // 1+8
  31: [0, 7], // 1+5
  32: [0, 5, 7], // sus4
  33: [0, 2, 7], // 1+2+5
  34: [], // cancel
};

/// MIDI notes for Fingered / Chord Detect, rooted near C3 (48).
List<int> chordDetectNotes(int rootPc, int chordType, {int base = 48}) {
  final intervals = yamahaChordIntervals[chordType] ?? const [0, 4, 7];
  final root = base + (rootPc % 12);
  return [
    for (final interval in intervals) (root + interval).clamp(0, 127),
  ];
}
