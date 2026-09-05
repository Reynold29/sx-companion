import '../midi/yamaha_sysex.dart';

/// One bar (or fraction) of a live chord chart. Beats are at the song tempo, 4/4.
class ChartChord {
  ChartChord({
    required this.rootPc,
    this.chordType = 0,
    this.beats = 4,
  });

  factory ChartChord.fromJson(Map<String, dynamic> json) {
    return ChartChord(
      rootPc: json['rootPc'] as int? ?? 0,
      chordType: json['chordType'] as int? ?? 0,
      beats: json['beats'] as int? ?? 4,
    );
  }

  int rootPc;
  int chordType;
  int beats;

  String get label => YamahaChord(rootPc: rootPc, chordType: chordType).label;

  String get beatsLabel {
    if (beats == 8) return '2 bars';
    if (beats == 4) return '1 bar';
    if (beats == 2) return '½ bar';
    if (beats == 1) return '1 beat';
    return '$beats beats';
  }

  Map<String, dynamic> toJson() => {
        'rootPc': rootPc,
        'chordType': chordType,
        'beats': beats,
      };
}

int chartDurationMs(List<ChartChord> chart, int bpm) {
  final safeBpm = bpm.clamp(5, 260);
  var beats = 0;
  for (final chord in chart) {
    beats += chord.beats.clamp(1, 32);
  }
  return (beats * 60000 / safeBpm).round();
}
