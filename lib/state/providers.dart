import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../catalog/keyboard_catalog.dart';
import '../midi/midi_session.dart';
import '../presets/preset_store.dart';

final midiSessionProvider = ChangeNotifierProvider<MidiSession>((ref) {
  return MidiSession();
});

final keyboardCatalogProvider = ChangeNotifierProvider<KeyboardCatalog>((ref) {
  final catalog = KeyboardCatalog();
  catalog.load();
  return catalog;
});

final presetStoreProvider = ChangeNotifierProvider<PresetStore>((ref) {
  final store = PresetStore();
  store.load();
  return store;
});
