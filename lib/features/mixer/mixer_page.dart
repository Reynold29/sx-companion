import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../midi/midi_session.dart';
import '../../state/providers.dart';
import '../../widgets/pad_button.dart';

class MixerPage extends ConsumerStatefulWidget {
  const MixerPage({super.key});

  @override
  ConsumerState<MixerPage> createState() => _MixerPageState();
}

class _MixerPageState extends ConsumerState<MixerPage> {
  double style = 100;
  double song = 100;
  double master = 110;
  double right1 = 100;
  double right2 = 90;
  double left = 90;
  bool muteStyle = false;
  bool muteSong = false;

  @override
  Widget build(BuildContext context) {
    final midi = ref.watch(midiSessionProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          'Style sliders go to USB1. Song sliders go to USB2 so they do not move each other.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        _Fader(
          label: 'Master',
          value: master,
          onChanged: (value) {
            setState(() => master = value);
            midi.setMasterVolume(value.round());
          },
        ),
        _Fader(
          label: muteStyle ? 'Style (muted)' : 'Style  ·  USB1',
          value: muteStyle ? 0 : style,
          onChanged: (value) {
            setState(() {
              muteStyle = false;
              style = value;
            });
            midi.setStyleVolume(value.round());
          },
          trailing: IconButton(
            icon: Icon(muteStyle ? Icons.volume_off : Icons.volume_up),
            onPressed: () {
              setState(() => muteStyle = !muteStyle);
              midi.setStyleVolume(muteStyle ? 0 : style.round());
            },
          ),
        ),
        _Fader(
          label: muteSong ? 'Song (muted)' : 'Song  ·  USB2',
          value: muteSong ? 0 : song,
          onChanged: (value) {
            setState(() {
              muteSong = false;
              song = value;
            });
            midi.setSongVolume(value.round());
          },
          trailing: IconButton(
            icon: Icon(muteSong ? Icons.volume_off : Icons.volume_up),
            onPressed: () {
              setState(() => muteSong = !muteSong);
              midi.setSongVolume(muteSong ? 0 : song.round());
            },
          ),
        ),
        const SectionLabel('Keyboard'),
        _Fader(
          label: 'Right 1',
          value: right1,
          onChanged: (value) {
            setState(() => right1 = value);
            midi.setPartVolume(KeyboardPart.right1, value.round());
          },
        ),
        _Fader(
          label: 'Right 2',
          value: right2,
          onChanged: (value) {
            setState(() => right2 = value);
            midi.setPartVolume(KeyboardPart.right2, value.round());
          },
        ),
        _Fader(
          label: 'Left',
          value: left,
          onChanged: (value) {
            setState(() => left = value);
            midi.setPartVolume(KeyboardPart.left, value.round());
          },
        ),
        const SizedBox(height: 8),
        PadButton(
          label: 'Reset mixer to 100',
          onPressed: () {
            setState(() {
              style = song = right1 = right2 = left = 100;
              master = 110;
              muteStyle = muteSong = false;
            });
            midi.setStyleVolume(100);
            midi.setSongVolume(100);
            midi.setMasterVolume(110);
            midi.setPartVolume(KeyboardPart.right1, 100);
            midi.setPartVolume(KeyboardPart.right2, 100);
            midi.setPartVolume(KeyboardPart.left, 100);
          },
        ),
      ],
    );
  }
}

class _Fader extends StatelessWidget {
  const _Fader({
    required this.label,
    required this.value,
    required this.onChanged,
    this.trailing,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
                Text('${value.round()}'),
                ?trailing,
              ],
            ),
            Slider(max: 127, value: value.clamp(0, 127), onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
