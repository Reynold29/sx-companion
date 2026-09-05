import 'package:flutter_test/flutter_test.dart';
import 'package:sx700_remote/music/harmony.dart';

void main() {
  test('C major diatonic chords', () {
    final chords = diatonicChords(const HarmonyKey(tonic: 0, minor: false));
    expect(chords.map((c) => c.name).toList(), ['C', 'Dm', 'Em', 'F', 'G', 'Am', 'B°']);
    expect(chords.first.roman, 'I');
    expect(chords[4].chordType, 0); // V is major triad in major
  });

  test('A minor includes V7', () {
    final chords = diatonicChords(const HarmonyKey(tonic: 9, minor: true));
    expect(chords.first.name, 'Am');
    expect(chords[4].name, 'E7');
  });
}
