import 'dart:typed_data';

class SmfEvent {
  const SmfEvent({
    required this.tick,
    required this.bytes,
    this.lyric,
  });

  final int tick;
  final Uint8List bytes;
  final String? lyric;
}

class SmfSong {
  const SmfSong({
    required this.ppq,
    required this.events,
    this.initialTempo = 500000,
  });

  final int ppq;
  final int initialTempo;
  final List<SmfEvent> events;

  Duration tickDuration(int tempoMicroseconds) {
    return Duration(microseconds: (tempoMicroseconds / ppq).round());
  }
}

class SmfCodec {
  SmfCodec._();

  static SmfSong parse(Uint8List data) {
    final reader = _ByteReader(data);
    if (reader.string(4) != 'MThd') {
      throw const FormatException('Not a Standard MIDI File');
    }
    final headerLen = reader.u32();
    reader.u16(); // format
    final tracks = reader.u16();
    final division = reader.u16();
    if (headerLen > 6) {
      reader.skip(headerLen - 6);
    }
    if (division & 0x8000 != 0) {
      throw const FormatException('SMPTE time division is not supported');
    }
    final events = <SmfEvent>[];
    var tempo = 500000;
    for (var t = 0; t < tracks; t++) {
      if (reader.remaining < 8) break;
      final chunk = reader.string(4);
      final length = reader.u32();
      if (chunk != 'MTrk') {
        reader.skip(length);
        continue;
      }
      final trackBytes = reader.bytes(length);
      _parseTrack(trackBytes, events, (value) => tempo = value);
    }
    events.sort((a, b) => a.tick.compareTo(b.tick));
    return SmfSong(ppq: division, events: events, initialTempo: tempo);
  }

  static Uint8List write(List<({int millis, Uint8List bytes})> recorded, {int bpm = 120}) {
    const ppq = 480;
    final tempo = (60000000 / bpm).round();
    final usPerTick = tempo / ppq;
    final events = <SmfEvent>[
      SmfEvent(
        tick: 0,
        bytes: Uint8List.fromList([
          0xFF,
          0x51,
          0x03,
          (tempo >> 16) & 0xFF,
          (tempo >> 8) & 0xFF,
          tempo & 0xFF,
        ]),
      ),
    ];
    for (final item in recorded) {
      final tick = (item.millis * 1000 / usPerTick).round().clamp(0, 0x0FFFFFFF);
      events.add(SmfEvent(tick: tick, bytes: item.bytes));
    }
    events.add(SmfEvent(tick: events.last.tick, bytes: Uint8List.fromList(const [0xFF, 0x2F, 0x00])));

    final track = BytesBuilder();
    var lastTick = 0;
    for (final event in events) {
      track.add(_vlq(event.tick - lastTick));
      track.add(event.bytes);
      lastTick = event.tick;
    }
    final trackBytes = track.takeBytes();
    final out = BytesBuilder();
    out.add('MThd'.codeUnits);
    out.add(_u32(6));
    out.add(_u16(0)); // type 0
    out.add(_u16(1));
    out.add(_u16(ppq));
    out.add('MTrk'.codeUnits);
    out.add(_u32(trackBytes.length));
    out.add(trackBytes);
    return Uint8List.fromList(out.takeBytes());
  }

  static void _parseTrack(
    Uint8List data,
    List<SmfEvent> events,
    void Function(int tempo) onTempo,
  ) {
    final reader = _ByteReader(data);
    var tick = 0;
    var running = 0;
    while (reader.remaining > 0) {
      tick += reader.vlq();
      if (reader.remaining == 0) break;
      var status = reader.peek();
      if (status < 0x80) {
        status = running;
      } else {
        reader.u8();
        if (status < 0xF0) running = status;
      }

      if (status == 0xFF) {
        final type = reader.u8();
        final len = reader.vlq();
        final payload = reader.bytes(len);
        if (type == 0x51 && payload.length >= 3) {
          onTempo((payload[0] << 16) | (payload[1] << 8) | payload[2]);
        } else if (type == 0x05 || type == 0x01) {
          events.add(
            SmfEvent(
              tick: tick,
              bytes: Uint8List.fromList([0xFF, type, ..._vlq(len), ...payload]),
              lyric: String.fromCharCodes(payload),
            ),
          );
        }
        continue;
      }

      if (status == 0xF0 || status == 0xF7) {
        final len = reader.vlq();
        final payload = reader.bytes(len);
        events.add(
          SmfEvent(
            tick: tick,
            bytes: Uint8List.fromList([status, ...payload]),
          ),
        );
        continue;
      }

      final dataLen = _dataLength(status);
      final payload = <int>[status];
      for (var i = 0; i < dataLen && reader.remaining > 0; i++) {
        payload.add(reader.u8());
      }
      events.add(SmfEvent(tick: tick, bytes: Uint8List.fromList(payload)));
    }
  }

  static int _dataLength(int status) {
    final hi = status & 0xF0;
    if (hi == 0xC0 || hi == 0xD0) return 1;
    if (status >= 0xF8) return 0;
    if (status == 0xF1 || status == 0xF3) return 1;
    if (status == 0xF2) return 2;
    return 2;
  }

  static List<int> _vlq(int value) {
    var v = value;
    final bytes = <int>[v & 0x7F];
    v >>= 7;
    while (v > 0) {
      bytes.insert(0, (v & 0x7F) | 0x80);
      v >>= 7;
    }
    return bytes;
  }

  static List<int> _u16(int v) => [(v >> 8) & 0xFF, v & 0xFF];
  static List<int> _u32(int v) => [
        (v >> 24) & 0xFF,
        (v >> 16) & 0xFF,
        (v >> 8) & 0xFF,
        v & 0xFF,
      ];
}

class _ByteReader {
  _ByteReader(this.data);

  final Uint8List data;
  int offset = 0;

  int get remaining => data.length - offset;

  int peek() => data[offset];

  int u8() => data[offset++];

  int u16() => (u8() << 8) | u8();

  int u32() => (u8() << 24) | (u8() << 16) | (u8() << 8) | u8();

  Uint8List bytes(int n) {
    final end = (offset + n).clamp(0, data.length);
    final slice = data.sublist(offset, end);
    offset = end;
    return slice;
  }

  String string(int n) => String.fromCharCodes(bytes(n));

  void skip(int n) => offset = (offset + n).clamp(0, data.length);

  int vlq() {
    var value = 0;
    while (remaining > 0) {
      final b = u8();
      value = (value << 7) | (b & 0x7F);
      if (b & 0x80 == 0) break;
    }
    return value;
  }
}
