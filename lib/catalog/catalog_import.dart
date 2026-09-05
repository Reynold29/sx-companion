import 'dart:convert';

import 'sound_source.dart';
import 'style.dart';
import 'voice.dart';

class ImportedCatalog {
  const ImportedCatalog({this.voices = const [], this.styles = const []});

  final List<SxVoice> voices;
  final List<SxStyle> styles;

  bool get isEmpty => voices.isEmpty && styles.isEmpty;
}

/// Parses JSON, CSV, or a simple name-per-line dump from YEM / a spreadsheet.
ImportedCatalog parseCatalogFile(String text, {SoundSource fallback = SoundSource.usb}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const ImportedCatalog();
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    return _parseJson(trimmed, fallback);
  }
  if (trimmed.contains(',') && trimmed.contains('\n')) {
    return _parseCsv(trimmed, fallback);
  }
  return _parseLines(trimmed, fallback);
}

ImportedCatalog _parseJson(String text, SoundSource fallback) {
  final decoded = jsonDecode(text);
  if (decoded is List) {
    return _fromMaps(
      [for (final item in decoded) if (item is Map) Map<String, dynamic>.from(item)],
      fallback,
    );
  }
  if (decoded is Map) {
    final map = Map<String, dynamic>.from(decoded);
    final voiceRaw = map['voices'];
    final styleRaw = map['styles'];
    final voices = <SxVoice>[
      if (voiceRaw is List)
        for (final item in voiceRaw)
          if (item is Map) SxVoice.fromJson(Map<String, dynamic>.from(item)),
    ];
    final styles = <SxStyle>[
      if (styleRaw is List)
        for (final item in styleRaw)
          if (item is Map) SxStyle.fromJson(Map<String, dynamic>.from(item)),
    ];
    if (voices.isEmpty && styles.isEmpty) {
      return _fromMaps([map], fallback);
    }
    return ImportedCatalog(voices: voices, styles: styles);
  }
  return const ImportedCatalog();
}

ImportedCatalog _fromMaps(List<Map<String, dynamic>> rows, SoundSource fallback) {
  final voices = <SxVoice>[];
  final styles = <SxStyle>[];
  for (final row in rows) {
    final kind = '${row['kind'] ?? row['type'] ?? ''}'.toLowerCase();
    if (kind.contains('style') || row.containsKey('index') && !row.containsKey('msb')) {
      styles.add(SxStyle.fromJson(row));
      continue;
    }
    if (row.containsKey('name')) {
      final voice = SxVoice.fromJson({
        ...row,
        'source': row['source'] ?? fallback.name,
      });
      if (kind.contains('style')) {
        styles.add(
          SxStyle(
            index: styles.length,
            name: voice.name,
            category: voice.category,
            msb: voice.msb,
            lsb: voice.lsb,
            pc: voice.pc,
            source: fallback,
          ),
        );
      } else {
        voices.add(voice);
      }
    }
  }
  return ImportedCatalog(voices: voices, styles: styles);
}

ImportedCatalog _parseCsv(String text, SoundSource fallback) {
  final lines = const LineSplitter().convert(text).where((l) => l.trim().isNotEmpty).toList();
  if (lines.isEmpty) return const ImportedCatalog();
  final header = lines.first.split(',').map((c) => c.trim().toLowerCase()).toList();
  final hasHeader = header.any((c) => {'name', 'voice', 'style', 'msb', 'pc', 'source', 'kind'}.contains(c));
  final rows = hasHeader ? lines.skip(1) : lines;
  final voices = <SxVoice>[];
  final styles = <SxStyle>[];
  for (final line in rows) {
    final cols = _splitCsv(line);
    if (cols.isEmpty) continue;
    String cell(String key, [int i = 0]) {
      if (hasHeader) {
        final idx = header.indexOf(key);
        if (idx >= 0 && idx < cols.length) return cols[idx].trim();
      }
      return i < cols.length ? cols[i].trim() : '';
    }

    final kind = cell('kind').toLowerCase();
    final sourceName = cell('source');
    final source = SoundSource.values.firstWhere(
      (s) => s.name == sourceName || s.label.toLowerCase() == sourceName.toLowerCase(),
      orElse: () => fallback,
    );
    final name = cell('name', 0);
    if (name.isEmpty) continue;
    if (kind.contains('style') || (!hasHeader && kind.isEmpty && cell('msb').isEmpty)) {
      if (kind.contains('style') || header.contains('style')) {
        styles.add(
          SxStyle(
            index: int.tryParse(cell('index')) ?? styles.length,
            name: name,
            category: cell('category', 1).isEmpty ? 'Imported' : cell('category', 1),
            msb: int.tryParse(cell('msb')) ?? 0,
            lsb: int.tryParse(cell('lsb')) ?? 0,
            pc: int.tryParse(cell('pc')) ?? styles.length + 1,
            source: source,
          ),
        );
        continue;
      }
    }
    voices.add(
      SxVoice(
        name: name,
        category: cell('category', 1).isEmpty ? 'Imported' : cell('category', 1),
        type: cell('type', 2).isEmpty ? 'USB/User' : cell('type', 2),
        msb: int.tryParse(cell('msb', 3)) ?? 63,
        lsb: int.tryParse(cell('lsb', 4)) ?? 0,
        pc: int.tryParse(cell('pc', 5)) ?? 1,
        slot: int.tryParse(cell('slot', 6)) ?? -1,
        source: source,
      ),
    );
  }
  return ImportedCatalog(voices: voices, styles: styles);
}

ImportedCatalog _parseLines(String text, SoundSource fallback) {
  final voices = <SxVoice>[];
  final styles = <SxStyle>[];
  for (final raw in const LineSplitter().convert(text)) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final lower = line.toLowerCase();
    if (lower.startsWith('style:') || lower.startsWith('sty:')) {
      final name = line.split(':').skip(1).join(':').trim();
      styles.add(
        SxStyle(
          index: styles.length,
          name: name,
          category: 'Imported',
          msb: 0,
          lsb: 0,
          pc: styles.length + 1,
          source: fallback,
        ),
      );
    } else {
      final name = lower.startsWith('voice:') ? line.split(':').skip(1).join(':').trim() : line;
      voices.add(
        SxVoice(
          name: name,
          category: 'Imported',
          type: 'USB/User',
          msb: 63,
          lsb: voices.length ~/ 128,
          pc: (voices.length % 128) + 1,
          slot: voices.length,
          source: fallback,
        ),
      );
    }
  }
  return ImportedCatalog(voices: voices, styles: styles);
}

List<String> _splitCsv(String line) {
  final out = <String>[];
  final buf = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      quoted = !quoted;
    } else if (ch == ',' && !quoted) {
      out.add(buf.toString());
      buf.clear();
    } else {
      buf.write(ch);
    }
  }
  out.add(buf.toString());
  return out;
}
