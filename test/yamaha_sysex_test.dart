import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sx700_remote/midi/yamaha_sysex.dart';

void main() {
  test('style section SysEx', () {
    expect(
      YamahaSysex.section(YamahaSysex.mainA),
      Uint8List.fromList(const [0xF0, 0x43, 0x7E, 0x00, 0x08, 0x7F, 0xF7]),
    );
    expect(
      YamahaSysex.section(YamahaSysex.endingB, on: false),
      Uint8List.fromList(const [0xF0, 0x43, 0x7E, 0x00, 0x21, 0x00, 0xF7]),
    );
  });

  test('tempo pack/unpack', () {
    final bytes = YamahaSysex.tempo(120);
    expect(bytes, Uint8List.fromList(const [0xF0, 0x43, 0x7E, 0x01, 0x00, 0x00, 0x00, 120, 0xF7]));
    expect(YamahaSysex.parseTempo(bytes), 120);
    expect(YamahaSysex.parseTempo(YamahaSysex.tempo(200)), 200);
  });

  test('chord Cmaj and Am', () {
    final c = YamahaSysex.chord(rootPc: 0);
    expect(c[0], 0xF0);
    expect(c[3], 0x02);
    expect(c[4], YamahaSysex.chromaticToYamahaRoot(0));
    expect(YamahaSysex.parseChord(c)?.label, 'C');

    final am = YamahaSysex.chord(rootPc: 9, chordType: 8);
    expect(YamahaSysex.parseChord(am)?.label, 'Amin');
  });

  test('registration 1-8 send form', () {
    expect(
      YamahaSysex.registration(1),
      Uint8List.fromList(const [0xF0, 0x43, 0x73, 0x01, 0x52, 0x25, 0x11, 0x00, 0x01, 0x00, 0x00, 0xF7]),
    );
  });

  test('style select index bytes', () {
    final first = YamahaSysex.styleSelect(0);
    expect(first.sublist(first.length - 3), [0x00, 0x00, 0xF7]);
    final later = YamahaSysex.styleSelect(129);
    expect(later[later.length - 3], 0x01);
    expect(later[later.length - 2], 0x01);
  });

  test('voice bank select + PC', () {
    final data = MidiBytes.voiceSelect(channel: 0, msb: 104, lsb: 11, program: 0);
    expect(data, Uint8List.fromList(const [0xB0, 0x00, 104, 0xB0, 0x20, 11, 0xC0, 0x00]));
  });

  test('XG part volume and realtime start/stop', () {
    expect(
      YamahaSysex.xgPartVolume(part: 0, volume: 100),
      Uint8List.fromList(const [0xF0, 0x43, 0x10, 0x4C, 0x08, 0x00, 0x0B, 100, 0xF7]),
    );
    expect(MidiBytes.start(), Uint8List.fromList(const [0xFA]));
    expect(MidiBytes.stop(), Uint8List.fromList(const [0xFC]));
  });

  test('root encoding table', () {
    expect(YamahaSysex.chromaticToYamahaRoot(0), 0x31);
    expect(YamahaSysex.yamahaRootToChromatic(0x31), 0);
    expect(YamahaSysex.yamahaRootToChromatic(0x23), 3);
  });

  test('identity request', () {
    expect(
      YamahaSysex.identityRequest(),
      Uint8List.fromList(const [0xF0, 0x7E, 0x7F, 0x06, 0x01, 0xF7]),
    );
    expect(
      YamahaSysex.parseIdentity(
        const [0xF0, 0x7E, 0x00, 0x06, 0x02, 0x43, 0x00, 0xF7],
      ),
      'Yamaha keyboard',
    );
  });
}
