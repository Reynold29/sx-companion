import '../catalog/sound_source.dart';
import '../catalog/style.dart';
import '../catalog/voice.dart';
import '../midi/midi_session.dart';
import '../midi/yamaha_sysex.dart';
import '../music/chart.dart';

class SoundPick {
  const SoundPick({
    required this.source,
    required this.name,
    required this.msb,
    required this.lsb,
    required this.pc,
    this.index = 0,
    this.category = '',
  });

  factory SoundPick.voice(SxVoice voice, {int index = 0}) {
    return SoundPick(
      source: voice.source,
      name: voice.name,
      msb: voice.msb,
      lsb: voice.lsb,
      pc: voice.pc,
      index: index,
      category: voice.category,
    );
  }

  factory SoundPick.style(SxStyle style) {
    return SoundPick(
      source: style.source,
      name: style.name,
      msb: style.msb,
      lsb: style.lsb,
      pc: style.pc,
      index: style.index,
      category: style.category,
    );
  }

  factory SoundPick.fromJson(Map<String, dynamic> json) {
    return SoundPick(
      source: SoundSource.values[json['source'] as int? ?? 0],
      name: json['name'] as String? ?? '',
      msb: json['msb'] as int? ?? 0,
      lsb: json['lsb'] as int? ?? 0,
      pc: json['pc'] as int? ?? 1,
      index: json['index'] as int? ?? 0,
      category: json['category'] as String? ?? '',
    );
  }

  final SoundSource source;
  final String name;
  final String category;
  final int msb;
  final int lsb;
  final int pc;
  final int index;

  int get program => (pc - 1).clamp(0, 127);

  Map<String, dynamic> toJson() => {
        'source': source.index,
        'name': name,
        'category': category,
        'msb': msb,
        'lsb': lsb,
        'pc': pc,
        'index': index,
      };
}

class SongPart {
  SongPart({
    required this.id,
    required this.name,
    this.role = 'main',
    this.styleSection = YamahaSysex.mainA,
    this.style,
    this.right1,
    this.right2,
    this.left,
    this.tempo,
    this.registrationBank,
    this.registrationSlot,
    this.right1On = true,
    this.right2On = true,
    this.leftOn = true,
    this.right1Volume = 100,
    this.right2Volume = 90,
    this.leftVolume = 90,
    this.styleVolume = 100,
    List<ChartChord>? chart,
    this.loopChart = false,
    this.clipId,
  }) : chart = chart ?? [];

  factory SongPart.fromJson(Map<String, dynamic> json) {
    SoundPick? pick(String key) {
      final value = json[key];
      if (value is Map<String, dynamic>) return SoundPick.fromJson(value);
      return null;
    }

    return SongPart(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Part',
      role: json['role'] as String? ?? 'main',
      styleSection: json['styleSection'] as int? ?? YamahaSysex.mainA,
      style: pick('style'),
      right1: pick('right1'),
      right2: pick('right2'),
      left: pick('left'),
      tempo: json['tempo'] as int?,
      registrationBank: json['registrationBank'] as int?,
      registrationSlot: json['registrationSlot'] as int?,
      right1On: json['right1On'] as bool? ?? true,
      right2On: json['right2On'] as bool? ?? true,
      leftOn: json['leftOn'] as bool? ?? true,
      right1Volume: json['right1Volume'] as int? ?? 100,
      right2Volume: json['right2Volume'] as int? ?? 90,
      leftVolume: json['leftVolume'] as int? ?? 90,
      styleVolume: json['styleVolume'] as int? ?? 100,
      loopChart: json['loopChart'] as bool? ?? false,
      clipId: json['clipId'] as String?,
      chart: [
        for (final item in json['chart'] as List? ?? const [])
          if (item is Map) ChartChord.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }

  String id;
  String name;
  String role;
  int styleSection;
  SoundPick? style;
  SoundPick? right1;
  SoundPick? right2;
  SoundPick? left;
  int? tempo;
  int? registrationBank;
  int? registrationSlot;
  bool right1On;
  bool right2On;
  bool leftOn;
  int right1Volume;
  int right2Volume;
  int leftVolume;
  int styleVolume;
  List<ChartChord> chart;
  bool loopChart;
  String? clipId;

  String get chartSummary {
    if (chart.isEmpty) return 'No chord chart';
    final names = chart.take(8).map((c) => c.label).join('  ');
    final extra = chart.length > 8 ? ' …' : '';
    return '$names$extra';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'styleSection': styleSection,
        'style': style?.toJson(),
        'right1': right1?.toJson(),
        'right2': right2?.toJson(),
        'left': left?.toJson(),
        'tempo': tempo,
        'registrationBank': registrationBank,
        'registrationSlot': registrationSlot,
        'right1On': right1On,
        'right2On': right2On,
        'leftOn': leftOn,
        'right1Volume': right1Volume,
        'right2Volume': right2Volume,
        'leftVolume': leftVolume,
        'styleVolume': styleVolume,
        'loopChart': loopChart,
        'clipId': clipId,
        'chart': [for (final chord in chart) chord.toJson()],
      };

  void apply(MidiSession midi) {
    if (tempo != null) midi.setTempo(tempo!);
    if (registrationBank != null) midi.setRegistrationBank(registrationBank!);
    if (registrationSlot != null) midi.recallRegistration(registrationSlot!);
    final selectedStyle = style;
    if (selectedStyle != null) {
      midi.selectStyle(
        index: selectedStyle.index,
        msb: selectedStyle.msb,
        lsb: selectedStyle.lsb,
        program: selectedStyle.program,
        source: selectedStyle.source.sysex,
      );
    }
    midi.styleSection(styleSection);
    void voice(KeyboardPart part, SoundPick? pick) {
      if (pick == null) return;
      midi.selectVoice(
        part: part,
        msb: pick.msb,
        lsb: pick.lsb,
        program: pick.program,
        source: pick.source.sysex,
        index: pick.index,
      );
    }

    voice(KeyboardPart.right1, right1);
    voice(KeyboardPart.right2, right2);
    voice(KeyboardPart.left, left);
    midi.setPartOn(KeyboardPart.right1, right1On);
    midi.setPartOn(KeyboardPart.right2, right2On);
    midi.setPartOn(KeyboardPart.left, leftOn);
    midi.setPartVolume(KeyboardPart.right1, right1Volume);
    midi.setPartVolume(KeyboardPart.right2, right2Volume);
    midi.setPartVolume(KeyboardPart.left, leftVolume);
    midi.setStyleVolume(styleVolume);
  }
}

class SongPreset {
  SongPreset({
    required this.id,
    required this.name,
    this.tonic = 0,
    this.minor = false,
    this.tempo = 120,
    List<SongPart>? parts,
  }) : parts = parts ?? [];

  factory SongPreset.fromJson(Map<String, dynamic> json) {
    return SongPreset(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Song',
      tonic: json['tonic'] as int? ?? 0,
      minor: json['minor'] as bool? ?? false,
      tempo: json['tempo'] as int? ?? 120,
      parts: [
        for (final part in json['parts'] as List? ?? const [])
          if (part is Map<String, dynamic>) SongPart.fromJson(part),
      ],
    );
  }

  String id;
  String name;
  int tonic;
  bool minor;
  int tempo;
  List<SongPart> parts;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tonic': tonic,
        'minor': minor,
        'tempo': tempo,
        'parts': [for (final part in parts) part.toJson()],
      };
}
