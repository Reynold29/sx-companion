import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../midi/yamaha_sysex.dart';
import '../music/harmony.dart';
import '../state/providers.dart';
import 'pad_button.dart';

class AcmpChordPad extends ConsumerStatefulWidget {
  const AcmpChordPad({super.key, this.initialKey = const HarmonyKey(tonic: 0, minor: false)});

  final HarmonyKey initialKey;

  @override
  ConsumerState<AcmpChordPad> createState() => _AcmpChordPadState();
}

class _AcmpChordPadState extends ConsumerState<AcmpChordPad> {
  late HarmonyKey _key = widget.initialKey;
  int _type = 0;
  int _root = 0;

  @override
  Widget build(BuildContext context) {
    final midi = ref.watch(midiSessionProvider);
    final diatonic = diatonicChords(_key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Key'),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < 12; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(YamahaSysex.rootNames[i]),
                    selected: _key.tonic == i,
                    onSelected: (_) => setState(() => _key = _key.copyWith(tonic: i)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Major')),
            ButtonSegment(value: true, label: Text('Minor')),
          ],
          selected: {_key.minor},
          onSelectionChanged: (value) => setState(() => _key = _key.copyWith(minor: value.first)),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            'Chords in ${_key.label}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.15,
          children: [
            for (final chord in diatonic)
              PadButton(
                label: '${chord.roman}\n${chord.name}',
                selected: midi.liveChord?.rootPc == chord.rootPc && midi.liveChord?.chordType == chord.chordType,
                height: 64,
                onPressed: () => midi.sendChord(rootPc: chord.rootPc, chordType: chord.chordType),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const SectionLabel('All roots'),
        GridView.count(
          crossAxisCount: 6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1.4,
          children: [
            for (var i = 0; i < 12; i++)
              PadButton(
                label: YamahaSysex.rootNames[i],
                selected: _root == i,
                height: 44,
                onPressed: () {
                  setState(() => _root = i);
                  midi.sendChord(rootPc: i, chordType: _type);
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        const SectionLabel('All chord types'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final type in acmpChordTypes)
              FilterChip(
                label: Text(type.label),
                selected: _type == type.id,
                onSelected: (_) {
                  setState(() => _type = type.id);
                  midi.sendChord(rootPc: _root, chordType: type.id);
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: PadButton(
                label: 'Cancel chord',
                onPressed: () => midi.sendChord(rootPc: _root, chordType: 34),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Chord detect ch',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: midi.chordDetectChannel,
                    isExpanded: true,
                    items: [
                      for (var ch = 0; ch < 16; ch++)
                        DropdownMenuItem(value: ch, child: Text('${ch + 1}')),
                    ],
                    onChanged: (value) {
                      if (value != null) midi.setChordDetectChannel(value);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        Text(
          'Sends Yamaha Chord SysEx and holds chord tones on that channel (default 3 = Left). Turn ACMP + Chord Detect Receive on.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
