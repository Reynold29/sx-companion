import 'sound_source.dart';

class SxVoice {
  const SxVoice({
    required this.name,
    required this.category,
    required this.type,
    required this.msb,
    required this.lsb,
    required this.pc,
    this.slot = -1,
    this.source = SoundSource.preset,
  });

  final String name;
  final String category;
  final String type;
  final int msb;
  final int lsb;
  final int pc;
  /// Panel content index for Yamaha SysEx select. Negative = derive from LSB/PC.
  final int slot;
  final SoundSource source;

  /// MIDI program change is 0-127; Yamaha lists PC as 1-128.
  int get program => (pc - 1).clamp(0, 127);

  int get selectIndex => slot >= 0 ? slot : (pc - 1) + lsb * 128;

  String get subtitle => '$type  ·  MSB $msb  LSB $lsb  PC $pc';

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        category.toLowerCase().contains(q) ||
        type.toLowerCase().contains(q) ||
        source.label.toLowerCase().contains(q);
  }

  Map<String, Object> toJson() => {
        'name': name,
        'category': category,
        'type': type,
        'msb': msb,
        'lsb': lsb,
        'pc': pc,
        'slot': slot,
        'source': source.name,
      };

  factory SxVoice.fromJson(Map<String, dynamic> json) {
    return SxVoice(
      name: json['name'] as String? ?? 'Voice',
      category: json['category'] as String? ?? 'Imported',
      type: json['type'] as String? ?? 'USB/User',
      msb: (json['msb'] as num?)?.toInt() ?? 63,
      lsb: (json['lsb'] as num?)?.toInt() ?? 0,
      pc: (json['pc'] as num?)?.toInt() ?? 1,
      slot: (json['slot'] as num?)?.toInt() ?? -1,
      source: SoundSource.values.firstWhere(
        (s) => s.name == json['source'],
        orElse: () => SoundSource.usb,
      ),
    );
  }
}
