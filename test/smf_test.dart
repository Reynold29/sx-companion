import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sx700_remote/midi/smf.dart';
import 'package:sx700_remote/midi/yamaha_sysex.dart';

void main() {
  test('round-trip a recorded note through SMF', () {
    final recorded = [
      (millis: 0, bytes: MidiBytes.noteOn(channel: 0, note: 60, velocity: 100)),
      (millis: 250, bytes: MidiBytes.noteOff(channel: 0, note: 60)),
    ];
    final bytes = SmfCodec.write(recorded, bpm: 120);
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'MThd');
    final song = SmfCodec.parse(bytes);
    expect(song.ppq, 480);
    expect(song.events.where((e) => e.bytes.isNotEmpty && e.bytes.first & 0xF0 == 0x90).length, 1);
  });

  test('rejects non-midi', () {
    expect(
      () => SmfCodec.parse(Uint8List.fromList('NOPE'.codeUnits)),
      throwsA(isA<FormatException>()),
    );
  });
}
