import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/sound_source.dart';
import '../../midi/midi_session.dart';
import '../../state/providers.dart';
import '../../widgets/sound_browser.dart';

class SoundPage extends ConsumerStatefulWidget {
  const SoundPage({super.key});

  @override
  ConsumerState<SoundPage> createState() => _SoundPageState();
}

class _SoundPageState extends ConsumerState<SoundPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  KeyboardPart _part = KeyboardPart.right1;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final midi = ref.watch(midiSessionProvider);
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Voices'),
            Tab(text: 'Styles'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              SoundBrowser(
                kind: SoundBrowser.voices,
                part: _part,
                onPart: (part) => setState(() => _part = part),
                onVoice: (voice) => midi.selectVoice(
                  part: _part,
                  msb: voice.msb,
                  lsb: voice.lsb,
                  program: voice.program,
                  source: voice.source.sysex,
                  index: voice.selectIndex,
                ),
                onStyle: (_) {},
              ),
              SoundBrowser(
                kind: SoundBrowser.styles,
                onVoice: (_) {},
                onStyle: (style) => midi.selectStyle(
                  index: style.index,
                  msb: style.msb,
                  lsb: style.lsb,
                  program: style.program,
                  source: style.source.sysex,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
