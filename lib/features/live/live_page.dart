import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../midi/midi_session.dart';
import '../../midi/yamaha_sysex.dart';
import '../../state/providers.dart';
import '../../widgets/articulation_strip.dart';
import '../../widgets/chord_pad.dart';
import '../../widgets/pad_button.dart';
import '../../widgets/registration_memory.dart';

class LivePage extends ConsumerWidget {
  const LivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final midi = ref.watch(midiSessionProvider);
    final chord = midi.liveChord?.label ?? '—';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _StatusStrip(midi: midi, chord: chord),
        const SizedBox(height: 16),
        const SectionLabel('Transport'),
        Row(
          children: [
            Expanded(
              child: PadButton(
                label: 'START',
                color: const Color(0xFF3DDC84),
                height: 64,
                onPressed: midi.startStyle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PadButton(
                label: 'STOP',
                color: const Color(0xFFFF6B6B),
                height: 64,
                onPressed: midi.stopStyle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const SectionLabel('Intro'),
        _Four(ids: [YamahaSysex.introA, YamahaSysex.introB, YamahaSysex.introC, YamahaSysex.introD], labels: const ['A', 'B', 'C', 'D'], midi: midi),
        const SectionLabel('Main'),
        _Four(ids: [YamahaSysex.mainA, YamahaSysex.mainB, YamahaSysex.mainC, YamahaSysex.mainD], labels: const ['A', 'B', 'C', 'D'], midi: midi),
        const SectionLabel('Fill / Break'),
        Row(
          children: [
            for (final entry in [
              ('AA', YamahaSysex.fillAA),
              ('BB', YamahaSysex.fillBB),
              ('CC', YamahaSysex.fillCC),
              ('DD', YamahaSysex.fillDD),
            ]) ...[
              Expanded(child: PadButton(label: entry.$1, onPressed: () => midi.styleSection(entry.$2))),
              if (entry.$1 != 'DD') const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 8),
        PadButton(label: 'BREAK', onPressed: () => midi.styleSection(YamahaSysex.breakFill)),
        const SizedBox(height: 16),
        const SectionLabel('Ending'),
        _Four(ids: [YamahaSysex.endingA, YamahaSysex.endingB, YamahaSysex.endingC, YamahaSysex.endingD], labels: const ['A', 'B', 'C', 'D'], midi: midi),
        const SizedBox(height: 16),
        const SectionLabel('Tempo'),
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: () => midi.setTempo(midi.tempoBpm - 1),
              icon: const Icon(Icons.remove),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '${midi.tempoBpm}',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Slider(
                    min: 30,
                    max: 250,
                    value: midi.tempoBpm.clamp(30, 250).toDouble(),
                    onChanged: (value) => midi.setTempo(value.round()),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              onPressed: () => midi.setTempo(midi.tempoBpm + 1),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const AcmpChordPad(),
        const SizedBox(height: 16),
        const RegistrationMemoryPad(),
        const SizedBox(height: 16),
        const ArticulationStrip(),
        const SizedBox(height: 16),
        const SectionLabel('Keyboard parts'),
        for (final part in KeyboardPart.values)
          _PartRow(part: part, midi: midi),
      ],
    );
  }
}

class _Four extends StatelessWidget {
  const _Four({required this.ids, required this.labels, required this.midi});

  final List<int> ids;
  final List<String> labels;
  final MidiSession midi;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < ids.length; i++) ...[
          Expanded(
            child: PadButton(
              label: labels[i],
              height: 56,
              onPressed: () => midi.styleSection(ids[i]),
            ),
          ),
          if (i != ids.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.midi, required this.chord});

  final MidiSession midi;
  final String chord;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              midi.isConnected ? Icons.usb : Icons.usb_off,
              color: midi.isConnected ? const Color(0xFF3DDC84) : Colors.white38,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    midi.isConnected ? midi.connectionLabel : 'Plug USB TO HOST into this device',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'IN ${midi.activity.inbound}   OUT ${midi.activity.outbound}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(chord, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                Text('${midi.tempoBpm} BPM', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PartRow extends StatefulWidget {
  const _PartRow({required this.part, required this.midi});

  final KeyboardPart part;
  final MidiSession midi;

  @override
  State<_PartRow> createState() => _PartRowState();
}

class _PartRowState extends State<_PartRow> {
  bool on = true;
  double volume = 100;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.part.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  Switch(
                    value: on,
                    onChanged: (value) {
                      setState(() => on = value);
                      widget.midi.setPartOn(widget.part, value);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Slider(
                value: volume,
                max: 127,
                onChanged: (value) {
                  setState(() => volume = value);
                  widget.midi.setPartVolume(widget.part, value.round());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
