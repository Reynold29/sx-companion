import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';

import '../music/chart.dart';
import '../music/chord_tones.dart';
import 'smf.dart';
import 'yamaha_sysex.dart';

enum KeyboardPart { right1, right2, left }

class MidiActivity {
  const MidiActivity({this.inbound = 0, this.outbound = 0});

  final int inbound;
  final int outbound;
}

class MidiSession extends ChangeNotifier {
  MidiSession({MidiCommand? command}) : _midi = command ?? MidiCommand();

  final MidiCommand _midi;
  StreamSubscription<MidiSetupChange>? _setupSub;
  StreamSubscription<MidiPacket>? _packetSub;

  List<MidiDevice> devices = const [];
  MidiDevice? usb1;
  MidiDevice? usb2;

  bool scanning = false;
  String? lastError;
  MidiActivity activity = const MidiActivity();
  YamahaChord? liveChord;
  int tempoBpm = 120;
  int registrationBankNumber = 1;
  int registrationSlot = 1;
  int expression = 127;
  int modulation = 0;
  bool sustainOn = false;
  bool articulation1 = false;
  bool articulation2 = false;
  final Set<int> heldNotes = {};
  int chordDetectChannel = 2;
  int lastBankMsb = 0;
  int lastBankLsb = 0;
  int lastProgram = 1;
  int lastProgramChannel = 0;
  String? keyboardIdentity;
  String? lastSysexName;
  final List<int> _heldChordNotes = [];
  int _pendingMsb = 0;
  int _pendingLsb = 0;

  bool recording = false;
  final List<({int millis, Uint8List bytes})> _recorded = [];
  DateTime? _recordStarted;

  bool playing = false;
  String? playingLyric;
  Timer? _playTimer;
  int _playIndex = 0;
  List<SmfEvent> _playEvents = const [];
  Stopwatch? _playWatch;
  double _usPerTick = 500000 / 480;
  bool _alive = true;
  bool _playAsClip = false;

  bool arrangementPlaying = false;
  int arrangementChordIndex = 0;
  String? arrangementPartName;
  Timer? _chartTimer;
  int _chartIndex = 0;
  List<ChartChord> _chart = const [];
  bool _chartLoop = false;
  List<ArrangementStep> _queue = const [];
  int _queueIndex = 0;
  bool _advanceWhenClipEnds = false;

  bool get isConnected => usb1 != null || usb2 != null;

  String get connectionLabel {
    if (!isConnected) return 'Not connected';
    final a = usb1?.name ?? '—';
    final b = usb2?.name;
    if (b == null || identical(usb1, usb2) || usb1?.id == usb2?.id) {
      return a;
    }
    return '$a  +  $b';
  }

  Future<void> start() async {
    try {
      _midi.configureTransportPolicy(
        const MidiTransportPolicy(excludedTransports: {MidiTransport.ble}),
      );
    } catch (error) {
      lastError = '$error';
    }
    _setupSub ??= _midi.onMidiSetupChanged?.listen((_) {
      unawaited(refreshDevices());
    });
    _packetSub ??= _midi.onMidiPacketReceived?.listen(_onPacket);
    await refreshDevices();
  }

  Future<void> refreshDevices() async {
    scanning = true;
    notifyListeners();
    try {
      devices = (await _midi.devices) ?? const [];
      lastError = null;
    } catch (error) {
      lastError = '$error';
      devices = const [];
    } finally {
      scanning = false;
      notifyListeners();
    }
  }

  Future<void> connect(MidiDevice device, {MidiPortRole role = MidiPortRole.usb1}) async {
    lastError = null;
    notifyListeners();
    try {
      await _midi.connectToDevice(device);
      if (role == MidiPortRole.usb1) {
        usb1 = device;
        usb2 ??= device;
      } else {
        usb2 = device;
        usb1 ??= device;
      }
      _autoAssignIfNeeded();
      probeKeyboard();
    } catch (error) {
      lastError = 'Connect failed: $error';
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    stopPlayback();
    stopRecording();
    stopArrangement();
    _releaseChordNotes();
    for (final device in {usb1, usb2}) {
      if (device != null) {
        try {
          _midi.disconnectDevice(device);
        } catch (_) {}
      }
    }
    usb1 = null;
    usb2 = null;
    notifyListeners();
  }

  void assignRole(MidiDevice device, MidiPortRole role) {
    if (role == MidiPortRole.usb1) {
      usb1 = device;
    } else {
      usb2 = device;
    }
    notifyListeners();
  }

  void send(
    Uint8List data, {
    MidiPortRole port = MidiPortRole.usb1,
  }) {
    final device = port == MidiPortRole.usb2 ? (usb2 ?? usb1) : (usb1 ?? usb2);
    if (device == null) return;
    try {
      _midi.sendData(data, deviceId: device.id);
      _captureOutbound(data);
      activity = MidiActivity(
        inbound: activity.inbound,
        outbound: activity.outbound + 1,
      );
      notifyListeners();
    } catch (error) {
      lastError = 'Send failed: $error';
      notifyListeners();
    }
  }

  void sendToBoth(Uint8List data) {
    send(data, port: MidiPortRole.usb1);
    if (usb2 != null && usb2?.id != usb1?.id) {
      send(data, port: MidiPortRole.usb2);
    }
  }

  void startStyle() => send(MidiBytes.start());

  void stopStyle() => send(MidiBytes.stop());

  void styleSection(int switchNo) => send(YamahaSysex.section(switchNo));

  void setTempo(int bpm) {
    tempoBpm = bpm.clamp(5, 260);
    send(YamahaSysex.tempo(tempoBpm));
    notifyListeners();
  }

  void sendChord({required int rootPc, int chordType = 0, int? bassPc}) {
    liveChord = chordType == 34
        ? null
        : YamahaChord(rootPc: rootPc, chordType: chordType, bassPc: bassPc);
    send(YamahaSysex.chord(rootPc: rootPc, chordType: chordType, bassPc: bassPc));
    _applyChordNotes(rootPc, chordType);
    notifyListeners();
  }

  void setChordDetectChannel(int channel) {
    if (channel == chordDetectChannel) return;
    _releaseChordNotes();
    chordDetectChannel = channel.clamp(0, 15);
    final chord = liveChord;
    if (chord != null && chord.chordType != 34) {
      _applyChordNotes(chord.rootPc, chord.chordType);
    }
    notifyListeners();
  }

  void probeKeyboard() {
    send(YamahaSysex.identityRequest());
    send(YamahaSysex.xgDumpRequest());
  }

  void resetPedals() {
    expression = 127;
    modulation = 0;
    sustainOn = false;
    articulation1 = false;
    articulation2 = false;
    for (final ch in [0, 1, 2]) {
      send(MidiBytes.cc(channel: ch, controller: 11, value: 127));
      send(MidiBytes.cc(channel: ch, controller: 1, value: 0));
      send(MidiBytes.cc(channel: ch, controller: 64, value: 0));
      send(MidiBytes.cc(channel: ch, controller: 80, value: 0));
      send(MidiBytes.cc(channel: ch, controller: 81, value: 0));
      send(MidiBytes.pitchBend(channel: ch, value: 8192));
      send(MidiBytes.aftertouch(channel: ch, value: 0));
    }
    send(YamahaSysex.articulation(1, on: false));
    send(YamahaSysex.articulation(2, on: false));
    notifyListeners();
  }

  void _applyChordNotes(int rootPc, int chordType) {
    _releaseChordNotes();
    if (chordType == 34) return;
    for (final note in chordDetectNotes(rootPc, chordType)) {
      send(MidiBytes.noteOn(channel: chordDetectChannel, note: note, velocity: 100));
      _heldChordNotes.add(note);
    }
  }

  void _releaseChordNotes() {
    for (final note in _heldChordNotes) {
      send(MidiBytes.noteOff(channel: chordDetectChannel, note: note));
    }
    _heldChordNotes.clear();
  }

  void selectStyle({
    required int index,
    required int msb,
    required int lsb,
    required int program,
    int source = 0,
  }) {
    send(YamahaSysex.styleSelect(index, source: source));
    send(
      MidiBytes.voiceSelect(channel: 0, msb: msb, lsb: lsb, program: program),
    );
  }

  void selectVoice({
    required KeyboardPart part,
    required int msb,
    required int lsb,
    required int program,
    int source = 0,
    int index = 0,
  }) {
    send(YamahaSysex.voiceContentSelect(index, source: source));
    send(
      MidiBytes.voiceSelect(
        channel: part.channel,
        msb: msb,
        lsb: lsb,
        program: program,
      ),
    );
  }

  void setPartOn(KeyboardPart part, bool on) {
    send(MidiBytes.cc(channel: part.channel, controller: 11, value: on ? 127 : 0));
  }

  void setPartVolume(KeyboardPart part, int volume) {
    send(MidiBytes.cc(channel: part.channel, controller: 7, value: volume));
  }

  void setStyleVolume(int volume) {
    send(YamahaSysex.xgPartVolume(part: 0, volume: volume), port: MidiPortRole.usb1);
  }

  void setSongVolume(int volume) {
    send(YamahaSysex.xgPartVolume(part: 0, volume: volume), port: MidiPortRole.usb2);
  }

  void setMasterVolume(int volume) => sendToBoth(YamahaSysex.masterVolume(volume));

  void recallRegistration(int slot) {
    registrationSlot = slot.clamp(1, 8);
    send(YamahaSysex.registration(registrationSlot));
    notifyListeners();
  }

  void setRegistrationBank(int bank) {
    registrationBankNumber = bank.clamp(1, 99);
    send(YamahaSysex.registrationBank(registrationBankNumber));
    notifyListeners();
  }

  void setExpression(int value) {
    expression = value.clamp(0, 127);
    send(MidiBytes.cc(channel: 0, controller: 11, value: expression));
    notifyListeners();
  }

  void setModulation(int value) {
    modulation = value.clamp(0, 127);
    send(MidiBytes.cc(channel: 0, controller: 1, value: modulation));
    notifyListeners();
  }

  void setSustain(bool on) {
    sustainOn = on;
    send(MidiBytes.cc(channel: 0, controller: 64, value: on ? 127 : 0));
    notifyListeners();
  }

  void setArticulation(int slot, bool on) {
    if (slot == 1) {
      articulation1 = on;
    } else {
      articulation2 = on;
    }
    send(YamahaSysex.articulation(slot, on: on));
    send(MidiBytes.cc(channel: 0, controller: slot == 1 ? 80 : 81, value: on ? 127 : 0));
    notifyListeners();
  }

  void setAftertouch(int value) {
    send(MidiBytes.aftertouch(channel: 0, value: value));
  }

  void setPitchBend(int value) {
    send(MidiBytes.pitchBend(channel: 0, value: value));
  }

  void noteOn(int note, {int channel = 0, int velocity = 100}) {
    send(MidiBytes.noteOn(channel: channel, note: note, velocity: velocity));
  }

  void noteOff(int note, {int channel = 0}) {
    send(MidiBytes.noteOff(channel: channel, note: note));
  }

  void startRecording() {
    _recorded.clear();
    recording = true;
    _recordStarted = DateTime.now();
    notifyListeners();
  }

  Uint8List? stopRecording({int bpm = 120}) {
    recording = false;
    final copy = List<({int millis, Uint8List bytes})>.from(_recorded);
    _recorded.clear();
    notifyListeners();
    if (copy.isEmpty) return null;
    return SmfCodec.write(copy, bpm: bpm);
  }

  Future<void> playSong(
    Uint8List smfBytes, {
    MidiPortRole port = MidiPortRole.usb2,
    bool asClip = false,
  }) async {
    stopPlayback();
    final song = SmfCodec.parse(smfBytes);
    _playEvents = song.events;
    _playIndex = 0;
    _usPerTick = song.initialTempo / song.ppq;
    _playAsClip = asClip;
    playing = true;
    playingLyric = null;
    _playWatch = Stopwatch()..start();
    _playTimer = Timer.periodic(const Duration(milliseconds: 4), (_) {
      _flushPlayEvents(song, port);
    });
    notifyListeners();
  }

  void stopPlayback({bool fromNaturalEnd = false}) {
    _playTimer?.cancel();
    _playTimer = null;
    _playWatch?.stop();
    playing = false;
    playingLyric = null;
    _playAsClip = false;
    final shouldAdvance = fromNaturalEnd && _advanceWhenClipEnds && _chart.isEmpty;
    notifyListeners();
    if (shouldAdvance) {
      _advanceWhenClipEnds = false;
      _queueIndex++;
      _startQueueStep();
    }
  }

  void playArrangement({
    required List<ArrangementStep> steps,
    int bpm = 120,
  }) {
    stopArrangement();
    if (steps.isEmpty) return;
    _queue = List.of(steps);
    _queueIndex = 0;
    arrangementPlaying = true;
    setTempo(bpm);
    startStyle();
    _startQueueStep();
  }

  void stopArrangement({bool stopStyleToo = false}) {
    _chartTimer?.cancel();
    _chartTimer = null;
    _chart = const [];
    _chartLoop = false;
    _queue = const [];
    _queueIndex = 0;
    _advanceWhenClipEnds = false;
    arrangementPlaying = false;
    arrangementPartName = null;
    arrangementChordIndex = 0;
    stopPlayback();
    _silenceClipNotes();
    if (stopStyleToo) {
      _releaseChordNotes();
      stopStyle();
    }
    notifyListeners();
  }

  void _silenceClipNotes() {
    for (final ch in [0, 1]) {
      send(MidiBytes.cc(channel: ch, controller: 123, value: 0));
      send(MidiBytes.cc(channel: ch, controller: 64, value: 0));
    }
  }

  void _startQueueStep() {
    _chartTimer?.cancel();
    if (!arrangementPlaying) return;
    if (_queueIndex >= _queue.length) {
      arrangementPlaying = false;
      arrangementPartName = null;
      notifyListeners();
      return;
    }
    final step = _queue[_queueIndex];
    arrangementPartName = step.name;
    arrangementChordIndex = 0;
    step.apply?.call();
    if (step.bpm != null) setTempo(step.bpm!);
    _chart = List.of(step.chart);
    _chartLoop = step.loop;
    _chartIndex = 0;
    _advanceWhenClipEnds = _chart.isEmpty && step.clip != null;
    if (step.clip != null) {
      unawaited(playSong(step.clip!, port: MidiPortRole.usb1, asClip: true));
    }
    if (_chart.isEmpty) {
      notifyListeners();
      if (step.clip == null) {
        _queueIndex++;
        _startQueueStep();
      }
      return;
    }
    _fireChartChord();
  }

  void _fireChartChord() {
    if (!arrangementPlaying || _chart.isEmpty) return;
    if (_chartIndex >= _chart.length) {
      if (_chartLoop) {
        _chartIndex = 0;
      } else {
        _queueIndex++;
        _startQueueStep();
        return;
      }
    }
    final chord = _chart[_chartIndex];
    arrangementChordIndex = _chartIndex;
    sendChord(rootPc: chord.rootPc, chordType: chord.chordType);
    final ms = (60000 / tempoBpm.clamp(5, 260) * chord.beats.clamp(1, 32)).round();
    _chartTimer = Timer(Duration(milliseconds: ms.clamp(50, 120000)), () {
      _chartIndex++;
      _fireChartChord();
    });
    notifyListeners();
  }

  void _captureOutbound(Uint8List data) {
    if (!recording || _recordStarted == null || data.isEmpty) return;
    final status = data.first;
    if (status == 0xF0 || status >= 0xF8) return;
    _recorded.add((
      millis: DateTime.now().difference(_recordStarted!).inMilliseconds,
      bytes: Uint8List.fromList(data),
    ));
  }

  void _flushPlayEvents(SmfSong song, MidiPortRole port) {
    if (!playing || _playWatch == null) return;
    final elapsedUs = _playWatch!.elapsedMicroseconds;
    while (_playIndex < _playEvents.length) {
      final event = _playEvents[_playIndex];
      final due = (event.tick * _usPerTick).round();
      if (due > elapsedUs) break;
      _playIndex++;
      if (event.lyric != null) {
        playingLyric = event.lyric;
      }
      if (event.bytes.isNotEmpty && event.bytes.first == 0xFF) {
        if (event.bytes.length >= 6 && event.bytes[1] == 0x51) {
          final tempo =
              (event.bytes[3] << 16) | (event.bytes[4] << 8) | event.bytes[5];
          _usPerTick = tempo / song.ppq;
        }
        continue;
      }
      if (event.bytes.isEmpty) continue;
      final status = event.bytes.first;
      if (_playAsClip) {
        if (status == 0xF8 || status == 0xFA || status == 0xFB || status == 0xFC) continue;
        if (status == 0xF0 &&
            event.bytes.length >= 4 &&
            event.bytes[1] == 0x43 &&
            event.bytes[2] == 0x7E &&
            event.bytes[3] == 0x02) {
          continue;
        }
      }
      send(event.bytes, port: port);
    }
    if (_playIndex >= _playEvents.length) {
      stopPlayback(fromNaturalEnd: true);
    } else {
      notifyListeners();
    }
  }

  void _onPacket(MidiPacket packet) {
    activity = MidiActivity(
      inbound: activity.inbound + 1,
      outbound: activity.outbound,
    );
    final data = packet.data;
    if (recording && _recordStarted != null) {
      _recorded.add((
        millis: DateTime.now().difference(_recordStarted!).inMilliseconds,
        bytes: Uint8List.fromList(data),
      ));
    }
    if (data.isNotEmpty && data.first == 0xF0) {
      final chord = YamahaSysex.parseChord(data);
      if (chord != null) liveChord = chord;
      final tempo = YamahaSysex.parseTempo(data);
      if (tempo != null) tempoBpm = tempo;
      final identity = YamahaSysex.parseIdentity(data);
      if (identity != null) keyboardIdentity = identity;
      final name = YamahaSysex.asciiNameFromSysex(data);
      if (name != null) lastSysexName = name;
    }
    if (data.length >= 3) {
      final status = data.first & 0xF0;
      final channel = data.first & 0x0F;
      if (status == 0xB0) {
        if (data[1] == 0) _pendingMsb = data[2];
        if (data[1] == 32) _pendingLsb = data[2];
      } else if (status == 0xC0) {
        lastBankMsb = _pendingMsb;
        lastBankLsb = _pendingLsb;
        lastProgram = data[1] + 1;
        lastProgramChannel = channel;
      }
    }
    if (data.isNotEmpty) {
      final status = data.first & 0xF0;
      if (status == 0x90 && data.length >= 3) {
        if (data[2] > 0) {
          heldNotes.add(data[1]);
        } else {
          heldNotes.remove(data[1]);
        }
      } else if (status == 0x80 && data.length >= 2) {
        heldNotes.remove(data[1]);
      }
    }
    notifyListeners();
  }

  void _autoAssignIfNeeded() {
    final yamaha = devices.where(_looksLikeSx700).toList();
    if (yamaha.length >= 2) {
      yamaha.sort((a, b) => a.name.compareTo(b.name));
      usb1 ??= yamaha.first;
      usb2 ??= yamaha[1];
    }
  }

  static bool _looksLikeSx700(MidiDevice device) {
    final name = device.name.toLowerCase();
    return name.contains('sx700') ||
        name.contains('psr') ||
        name.contains('yamaha') ||
        name.contains('digital keyboard');
  }

  @override
  void notifyListeners() {
    if (!_alive) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _chartTimer?.cancel();
    _releaseChordNotes();
    _alive = false;
    _setupSub?.cancel();
    _packetSub?.cancel();
    _playTimer?.cancel();
    _setupSub = null;
    _packetSub = null;
    super.dispose();
  }
}

extension KeyboardPartChannel on KeyboardPart {
  int get channel => switch (this) {
        KeyboardPart.right1 => 0,
        KeyboardPart.right2 => 1,
        KeyboardPart.left => 2,
      };

  String get label => switch (this) {
        KeyboardPart.right1 => 'Right 1',
        KeyboardPart.right2 => 'Right 2',
        KeyboardPart.left => 'Left',
      };
}

class ArrangementStep {
  const ArrangementStep({
    required this.name,
    required this.chart,
    this.loop = false,
    this.clip,
    this.apply,
    this.bpm,
  });

  final String name;
  final List<ChartChord> chart;
  final bool loop;
  final Uint8List? clip;
  final void Function()? apply;
  final int? bpm;
}
