import 'sound_source.dart';

class SxStyle {
  const SxStyle({
    required this.index,
    required this.name,
    required this.category,
    required this.msb,
    required this.lsb,
    required this.pc,
    this.source = SoundSource.preset,
  });

  final int index;
  final String name;
  final String category;
  final int msb;
  final int lsb;
  final int pc;
  final SoundSource source;

  int get program => (pc - 1).clamp(0, 127);

  String get subtitle => '${source.label}  ·  $category  ·  #${index + 1}';

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        category.toLowerCase().contains(q) ||
        source.label.toLowerCase().contains(q) ||
        '${index + 1}'.contains(q);
  }

  Map<String, Object> toJson() => {
        'index': index,
        'name': name,
        'category': category,
        'msb': msb,
        'lsb': lsb,
        'pc': pc,
        'source': source.name,
      };

  factory SxStyle.fromJson(Map<String, dynamic> json) {
    return SxStyle(
      index: (json['index'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Style',
      category: json['category'] as String? ?? 'Imported',
      msb: (json['msb'] as num?)?.toInt() ?? 0,
      lsb: (json['lsb'] as num?)?.toInt() ?? 0,
      pc: (json['pc'] as num?)?.toInt() ?? 1,
      source: SoundSource.values.firstWhere(
        (s) => s.name == json['source'],
        orElse: () => SoundSource.usb,
      ),
    );
  }
}
