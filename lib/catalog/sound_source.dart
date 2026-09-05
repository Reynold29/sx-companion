enum SoundSource { preset, expansion, usb }

extension SoundSourceLabel on SoundSource {
  String get label => switch (this) {
        SoundSource.preset => 'Preset',
        SoundSource.expansion => 'Expansion',
        SoundSource.usb => 'USB / User',
      };

  /// Yamaha panel content source byte used in SX-family SysEx.
  int get sysex => switch (this) {
        SoundSource.preset => 0x00,
        SoundSource.expansion => 0x02,
        SoundSource.usb => 0x03,
      };
}
