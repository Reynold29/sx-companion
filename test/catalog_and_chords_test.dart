import 'package:flutter_test/flutter_test.dart';
import 'package:sx700_remote/catalog/catalog_import.dart';
import 'package:sx700_remote/catalog/expansion.dart';
import 'package:sx700_remote/catalog/sound_source.dart';
import 'package:sx700_remote/music/chart.dart';
import 'package:sx700_remote/music/chord_tones.dart';

void main() {
  test('C major and A minor chord-detect notes', () {
    expect(chordDetectNotes(0, 0), [48, 52, 55]);
    expect(chordDetectNotes(9, 8), [57, 60, 64]);
    expect(chordDetectNotes(4, 19), [52, 56, 59, 62]); // E7
    expect(chordDetectNotes(0, 34), isEmpty);
  });

  test('factory expansion catalog uses real Yamaha names', () {
    expect(sx700ExpansionVoices, isNotEmpty);
    expect(sx700ExpansionStyles, isNotEmpty);
    expect(sx700ExpansionVoices.any((v) => v.name.contains('Expansion Voice')), isFalse);
    expect(sx700ExpansionVoices.map((v) => v.name), contains('AfricanBigKit'));
    expect(sx700ExpansionStyles.first.name, 'HighLife');
    expect(sx700ExpansionVoices.first.source, SoundSource.expansion);
  });

  test('import JSON voice list', () {
    const json = '''
{"voices":[{"name":"My Lead","category":"User","type":"Regular","msb":63,"lsb":0,"pc":1,"source":"usb"}]}
''';
    final imported = parseCatalogFile(json);
    expect(imported.voices.single.name, 'My Lead');
    expect(imported.voices.single.msb, 63);
  });

  test('chord chart duration at 120 BPM', () {
    final chart = [
      ChartChord(rootPc: 0, beats: 4),
      ChartChord(rootPc: 9, chordType: 8, beats: 4),
    ];
    expect(chartDurationMs(chart, 120), 4000);
    expect(chart.first.label, 'C');
  });
}
