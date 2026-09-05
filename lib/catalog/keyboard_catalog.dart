import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'catalog_import.dart';
import 'expansion.dart';
import 'sound_source.dart';
import 'style.dart';
import 'styles.dart';
import 'voice.dart';
import 'voices.dart';

class KeyboardCatalog extends ChangeNotifier {
  List<SxVoice> extraExpansionVoices = [];
  List<SxStyle> extraExpansionStyles = [];
  List<SxVoice> usbVoices = [];
  List<SxStyle> usbStyles = [];
  String? lastImportNote;
  bool loaded = false;
  bool _alive = true;

  List<SxVoice> voices(SoundSource source) {
    return switch (source) {
      SoundSource.preset => sx700Voices,
      SoundSource.expansion => [...sx700ExpansionVoices, ...extraExpansionVoices],
      SoundSource.usb => List.of(usbVoices),
    };
  }

  List<SxStyle> styles(SoundSource source) {
    return switch (source) {
      SoundSource.preset => sx700Styles,
      SoundSource.expansion => [...sx700ExpansionStyles, ...extraExpansionStyles],
      SoundSource.usb => List.of(usbStyles),
    };
  }

  SxVoice? lookupVoice({required int msb, required int lsb, required int pc}) {
    for (final source in SoundSource.values) {
      for (final voice in voices(source)) {
        if (voice.msb == msb && voice.lsb == lsb && voice.pc == pc) return voice;
      }
    }
    return null;
  }

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/keyboard_catalog.json');
  }

  Future<void> load() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString());
        if (json is Map<String, dynamic>) {
          extraExpansionVoices = _voices(json['expansionVoices']);
          extraExpansionStyles = _styles(json['expansionStyles']);
          usbVoices = _voices(json['usbVoices']);
          usbStyles = _styles(json['usbStyles']);
        }
      }
    } catch (_) {}
    loaded = true;
    notifyListeners();
  }

  Future<void> persist() async {
    final file = await _file();
    await file.writeAsString(
      jsonEncode({
        'expansionVoices': [for (final v in extraExpansionVoices) v.toJson()],
        'expansionStyles': [for (final s in extraExpansionStyles) s.toJson()],
        'usbVoices': [for (final v in usbVoices) v.toJson()],
        'usbStyles': [for (final s in usbStyles) s.toJson()],
      }),
      flush: true,
    );
    notifyListeners();
  }

  Future<int> importText(String text, {required SoundSource source}) async {
    final imported = parseCatalogFile(text, fallback: source);
    var count = 0;
    if (source == SoundSource.expansion) {
      extraExpansionVoices = _mergeVoices(extraExpansionVoices, imported.voices);
      extraExpansionStyles = _mergeStyles(extraExpansionStyles, imported.styles);
    } else {
      usbVoices = _mergeVoices(usbVoices, imported.voices);
      usbStyles = _mergeStyles(usbStyles, imported.styles);
    }
    count = imported.voices.length + imported.styles.length;
    lastImportNote = count == 0
        ? 'No voices or styles found in that file.'
        : 'Imported $count names.';
    await persist();
    return count;
  }

  Future<void> learnVoice(SxVoice voice) async {
    if (lookupVoice(msb: voice.msb, lsb: voice.lsb, pc: voice.pc) != null) return;
    if (voice.source == SoundSource.expansion) {
      extraExpansionVoices = _mergeVoices(extraExpansionVoices, [voice]);
    } else {
      usbVoices = _mergeVoices(usbVoices, [voice]);
    }
    lastImportNote = 'Learned ${voice.name}';
    await persist();
  }

  Future<void> clearUsb() async {
    usbVoices = [];
    usbStyles = [];
    lastImportNote = 'USB / User list cleared.';
    await persist();
  }

  static List<SxVoice> _voices(Object? raw) {
    if (raw is! List) return [];
    return [
      for (final item in raw)
        if (item is Map) SxVoice.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  static List<SxStyle> _styles(Object? raw) {
    if (raw is! List) return [];
    return [
      for (final item in raw)
        if (item is Map) SxStyle.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  static List<SxVoice> _mergeVoices(List<SxVoice> current, List<SxVoice> incoming) {
    final out = [...current];
    for (final voice in incoming) {
      final i = out.indexWhere(
        (v) => v.msb == voice.msb && v.lsb == voice.lsb && v.pc == voice.pc && v.name == voice.name,
      );
      if (i >= 0) {
        out[i] = voice;
      } else {
        out.add(voice);
      }
    }
    return out;
  }

  static List<SxStyle> _mergeStyles(List<SxStyle> current, List<SxStyle> incoming) {
    final out = [...current];
    for (final style in incoming) {
      final i = out.indexWhere((s) => s.index == style.index && s.name == style.name);
      if (i >= 0) {
        out[i] = style;
      } else {
        out.add(style);
      }
    }
    return out;
  }

  @override
  void notifyListeners() {
    if (!_alive) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _alive = false;
    super.dispose();
  }
}
