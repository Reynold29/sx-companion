import 'expansion.dart';
import 'keyboard_catalog.dart';
import 'sound_source.dart';
import 'style.dart';
import 'styles.dart';
import 'voice.dart';
import 'voices.dart';

List<SxVoice> factoryVoices(SoundSource source) {
  return switch (source) {
    SoundSource.preset => sx700Voices,
    SoundSource.expansion => sx700ExpansionVoices,
    SoundSource.usb => const [],
  };
}

List<SxStyle> factoryStyles(SoundSource source) {
  return switch (source) {
    SoundSource.preset => sx700Styles,
    SoundSource.expansion => sx700ExpansionStyles,
    SoundSource.usb => const [],
  };
}

List<SxVoice> voicesFor(SoundSource source, [KeyboardCatalog? catalog]) {
  return catalog?.voices(source) ?? factoryVoices(source);
}

List<SxStyle> stylesFor(SoundSource source, [KeyboardCatalog? catalog]) {
  return catalog?.styles(source) ?? factoryStyles(source);
}
