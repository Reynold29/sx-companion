import 'dart:typed_data';

/// Yamaha PSR-SX / Genos-family SysEx builders and parsers.
///
/// Style section / tempo / chord messages follow the PSR-S700/S900 Data List
/// (`F0 43 7E …`). Registration recall uses the community-documented send form
/// for the SX700 (`F0 43 73 01 52 25 11 …`).
class YamahaSysex {
  YamahaSysex._();

  static const int yamaha = 0x43;
  static const int styleId = 0x7E;
  static const int xgModel = 0x4C;

  static const int introA = 0x00;
  static const int introB = 0x01;
  static const int introC = 0x02;
  static const int introD = 0x03;
  static const int mainA = 0x08;
  static const int mainB = 0x09;
  static const int mainC = 0x0A;
  static const int mainD = 0x0B;
  static const int fillAA = 0x10;
  static const int fillBB = 0x11;
  static const int fillCC = 0x12;
  static const int fillDD = 0x13;
  static const int breakFill = 0x18;
  static const int endingA = 0x20;
  static const int endingB = 0x21;
  static const int endingC = 0x22;
  static const int endingD = 0x23;

  static Uint8List section(int switchNo, {bool on = true}) {
    return Uint8List.fromList([
      0xF0,
      yamaha,
      styleId,
      0x00,
      switchNo & 0x7F,
      on ? 0x7F : 0x00,
      0xF7,
    ]);
  }

  /// Packs integer BPM into four 7-bit bytes (t4..t1).
  static Uint8List tempo(int bpm) {
    final value = bpm.clamp(5, 260);
    return Uint8List.fromList([
      0xF0,
      yamaha,
      styleId,
      0x01,
      (value >> 21) & 0x7F,
      (value >> 14) & 0x7F,
      (value >> 7) & 0x7F,
      value & 0x7F,
      0xF7,
    ]);
  }

  static int? parseTempo(List<int> data) {
    if (!_isStyle(data, 0x01) || data.length < 9) return null;
    final value =
        (data[4] << 21) | (data[5] << 14) | (data[6] << 7) | data[7];
    if (value < 5 || value > 260) return null;
    return value;
  }

  /// Chord Control Type 1: `F0 43 7E 02 cr ct bn bt F7`.
  static Uint8List chord({
    required int rootPc,
    int chordType = 0,
    int? bassPc,
    int bassType = 127,
  }) {
    final cr = chromaticToYamahaRoot(rootPc);
    final bn = bassPc == null ? 127 : chromaticToYamahaRoot(bassPc);
    return Uint8List.fromList([
      0xF0,
      yamaha,
      styleId,
      0x02,
      cr,
      chordType & 0x7F,
      bn,
      bassPc == null ? 127 : bassType & 0x7F,
      0xF7,
    ]);
  }

  static YamahaChord? parseChord(List<int> data) {
    if (!_isStyle(data, 0x02) || data.length < 9) return null;
    final root = yamahaRootToChromatic(data[4]);
    final bass = data[6] == 127 ? null : yamahaRootToChromatic(data[6]);
    if (root == null) return null;
    return YamahaChord(
      rootPc: root,
      chordType: data[5],
      bassPc: bass,
      bassType: data[7],
    );
  }

  /// Panel style select. [source] 0=Preset, 2=Expansion, 3=USB/User.
  static Uint8List styleSelect(int index, {int source = 0}) {
    final n = index.clamp(0, 0x3FFF);
    return Uint8List.fromList([
      0xF0,
      yamaha,
      0x73,
      0x01,
      0x51,
      0x05,
      0x00,
      0x03,
      source & 0x7F,
      0x00,
      (n >> 7) & 0x7F,
      n & 0x7F,
      0xF7,
    ]);
  }

  /// Panel voice select on a drive (Preset / Expansion / USB).
  static Uint8List voiceContentSelect(int index, {int source = 0}) {
    final n = index.clamp(0, 0x3FFF);
    return Uint8List.fromList([
      0xF0,
      yamaha,
      0x73,
      0x01,
      0x51,
      0x05,
      0x00,
      0x01,
      source & 0x7F,
      0x00,
      (n >> 7) & 0x7F,
      n & 0x7F,
      0xF7,
    ]);
  }

  /// Super Articulation / assignable Articulation 1 or 2 (momentary).
  static Uint8List articulation(int slot, {bool on = true}) {
    return Uint8List.fromList([
      0xF0,
      yamaha,
      0x73,
      0x01,
      0x51,
      0x05,
      0x00,
      0x0A,
      0x00,
      0x00,
      (slot.clamp(1, 2) - 1) & 0x7F,
      on ? 0x7F : 0x00,
      0xF7,
    ]);
  }

  /// Registration Memory 1–8 recall (send form, not the dump form).
  static Uint8List registration(int slot) {
    final nn = slot.clamp(1, 8);
    return Uint8List.fromList([
      0xF0,
      yamaha,
      0x73,
      0x01,
      0x52,
      0x25,
      0x11,
      0x00,
      nn,
      0x00,
      0x00,
      0xF7,
    ]);
  }

  static Uint8List registrationBank(int bank) {
    final nn = bank.clamp(1, 127);
    return Uint8List.fromList([
      0xF0,
      yamaha,
      0x73,
      0x01,
      0x52,
      0x25,
      0x11,
      0x01,
      nn,
      0x00,
      0x00,
      0xF7,
    ]);
  }

  /// XG part volume. Port routing (USB1 style vs USB2 song) is the caller's job.
  static Uint8List xgPartVolume({required int part, required int volume}) {
    return Uint8List.fromList([
      0xF0,
      yamaha,
      0x10,
      xgModel,
      0x08,
      part & 0x0F,
      0x0B,
      volume.clamp(0, 127),
      0xF7,
    ]);
  }

  static Uint8List xgPartPan({required int part, required int pan}) {
    return Uint8List.fromList([
      0xF0,
      yamaha,
      0x10,
      xgModel,
      0x08,
      part & 0x0F,
      0x0E,
      pan.clamp(0, 127),
      0xF7,
    ]);
  }

  static Uint8List masterVolume(int volume) {
    return Uint8List.fromList([
      0xF0,
      0x7F,
      0x7F,
      0x04,
      0x01,
      0x00,
      volume.clamp(0, 127),
      0xF7,
    ]);
  }

  /// `0fffnnnn` — nnnn 1=C…7=B, fff 0=bbb … 3=natural … 6=###.
  static int chromaticToYamahaRoot(int pc) {
    const table = <int>[
      0x31, // C
      0x41, // C#
      0x32, // D
      0x23, // Eb
      0x33, // E
      0x34, // F
      0x44, // F#
      0x35, // G
      0x26, // Ab
      0x36, // A
      0x27, // Bb
      0x37, // B
    ];
    return table[pc % 12];
  }

  static int? yamahaRootToChromatic(int cr) {
    const reverse = <int, int>{
      0x31: 0,
      0x41: 1,
      0x32: 2,
      0x23: 3,
      0x33: 4,
      0x34: 5,
      0x44: 6,
      0x35: 7,
      0x26: 8,
      0x36: 9,
      0x27: 10,
      0x37: 11,
    };
    return reverse[cr];
  }

  static const chordTypeNames = <int, String>{
    0: 'Maj',
    1: 'Maj6',
    2: 'Maj7',
    3: 'Maj7(#11)',
    4: 'Maj(9)',
    5: 'Maj7(9)',
    6: 'Maj6(9)',
    7: 'aug',
    8: 'min',
    9: 'min6',
    10: 'min7',
    11: 'min7b5',
    12: 'min(9)',
    13: 'min7(9)',
    14: 'min7(11)',
    15: 'minMaj7',
    16: 'minMaj7(9)',
    17: 'dim',
    18: 'dim7',
    19: '7',
    20: '7sus4',
    21: '7b5',
    22: '7(9)',
    23: '7(#11)',
    24: '7(13)',
    25: '7(b9)',
    26: '7(b13)',
    27: '7(#9)',
    28: 'Maj7aug',
    29: '7aug',
    30: '1+8',
    31: '1+5',
    32: 'sus4',
    33: '1+2+5',
    34: 'cc',
  };

  static const rootNames = [
    'C',
    'C#',
    'D',
    'Eb',
    'E',
    'F',
    'F#',
    'G',
    'Ab',
    'A',
    'Bb',
    'B',
  ];

  static Uint8List identityRequest() =>
      Uint8List.fromList(const [0xF0, 0x7E, 0x7F, 0x06, 0x01, 0xF7]);

  /// XG dump request (device 0). Some SX replies include voice-name ASCII.
  static Uint8List xgDumpRequest() =>
      Uint8List.fromList(const [0xF0, 0x43, 0x20, 0x4C, 0x00, 0x00, 0x00, 0xF7]);

  static String? parseIdentity(List<int> data) {
    if (data.length < 6 || data.first != 0xF0 || data[1] != 0x7E) return null;
    if (data[3] != 0x06 || data[4] != 0x02) return null;
    if (data.length > 6 && data[5] == yamaha) return 'Yamaha keyboard';
    return 'MIDI device';
  }

  static String? asciiNameFromSysex(List<int> data) {
    if (data.isEmpty || data.first != 0xF0) return null;
    final chars = <int>[];
    var best = '';
    for (final b in data) {
      if (b >= 0x20 && b <= 0x7E && b != 0x7F) {
        chars.add(b);
      } else {
        final run = String.fromCharCodes(chars).trim();
        if (run.length >= 4 && run.length <= 24 && _looksLikeName(run) && run.length > best.length) {
          best = run;
        }
        chars.clear();
      }
    }
    return best.isEmpty ? null : best;
  }

  static bool _looksLikeName(String value) {
    if (!RegExp(r'[A-Za-z]').hasMatch(value)) return false;
    const skip = {
      'Yamaha',
      'PSR-SX700',
      'PSR-SX900',
      'MIDI',
    };
    return !skip.contains(value);
  }

  static bool _isStyle(List<int> data, int command) {
    return data.length >= 4 &&
        data.first == 0xF0 &&
        data[1] == yamaha &&
        data[2] == styleId &&
        data[3] == command &&
        data.last == 0xF7;
  }
}

class YamahaChord {
  const YamahaChord({
    required this.rootPc,
    required this.chordType,
    this.bassPc,
    this.bassType = 127,
  });

  final int rootPc;
  final int chordType;
  final int? bassPc;
  final int bassType;

  String get label {
    final root = YamahaSysex.rootNames[rootPc % 12];
    final type = YamahaSysex.chordTypeNames[chordType] ?? '$chordType';
    final name = type == 'Maj' ? root : '$root$type';
    if (bassPc != null && bassPc != rootPc) {
      return '$name/${YamahaSysex.rootNames[bassPc! % 12]}';
    }
    return name;
  }
}

class MidiBytes {
  MidiBytes._();

  static Uint8List start() => Uint8List.fromList(const [0xFA]);
  static Uint8List stop() => Uint8List.fromList(const [0xFC]);
  static Uint8List continuePlayback() => Uint8List.fromList(const [0xFB]);
  static Uint8List clock() => Uint8List.fromList(const [0xF8]);

  static Uint8List noteOn({
    required int channel,
    required int note,
    int velocity = 100,
  }) {
    return Uint8List.fromList([
      0x90 | (channel & 0x0F),
      note & 0x7F,
      velocity.clamp(0, 127),
    ]);
  }

  static Uint8List noteOff({
    required int channel,
    required int note,
    int velocity = 0,
  }) {
    return Uint8List.fromList([
      0x80 | (channel & 0x0F),
      note & 0x7F,
      velocity.clamp(0, 127),
    ]);
  }

  static Uint8List cc({
    required int channel,
    required int controller,
    required int value,
  }) {
    return Uint8List.fromList([
      0xB0 | (channel & 0x0F),
      controller & 0x7F,
      value.clamp(0, 127),
    ]);
  }

  static Uint8List programChange({required int channel, required int program}) {
    return Uint8List.fromList([0xC0 | (channel & 0x0F), program & 0x7F]);
  }

  static Uint8List bankSelect({
    required int channel,
    required int msb,
    required int lsb,
  }) {
    return Uint8List.fromList([
      ...cc(channel: channel, controller: 0, value: msb),
      ...cc(channel: channel, controller: 32, value: lsb),
    ]);
  }

  static Uint8List aftertouch({required int channel, required int value}) {
    return Uint8List.fromList([0xD0 | (channel & 0x0F), value.clamp(0, 127)]);
  }

  static Uint8List pitchBend({required int channel, required int value}) {
    final v = value.clamp(0, 16383);
    return Uint8List.fromList([0xE0 | (channel & 0x0F), v & 0x7F, (v >> 7) & 0x7F]);
  }

  static Uint8List voiceSelect({
    required int channel,
    required int msb,
    required int lsb,
    required int program,
  }) {
    return Uint8List.fromList([
      ...bankSelect(channel: channel, msb: msb, lsb: lsb),
      ...programChange(channel: channel, program: program),
    ]);
  }
}

enum MidiPortRole { usb1, usb2 }
