import 'package:flutter/material.dart';

import '../midi/yamaha_sysex.dart';
import '../music/chart.dart';
import '../music/harmony.dart';
import 'pad_button.dart';

class ChartEditor extends StatelessWidget {
  const ChartEditor({
    super.key,
    required this.chart,
    required this.songKey,
    required this.onChanged,
  });

  final List<ChartChord> chart;
  final HarmonyKey songKey;
  final ValueChanged<List<ChartChord>> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ChartEditorBody(
      chart: chart,
      songKey: songKey,
      onChanged: onChanged,
    );
  }
}

class _ChartEditorBody extends StatefulWidget {
  const _ChartEditorBody({
    required this.chart,
    required this.songKey,
    required this.onChanged,
  });

  final List<ChartChord> chart;
  final HarmonyKey songKey;
  final ValueChanged<List<ChartChord>> onChanged;

  @override
  State<_ChartEditorBody> createState() => _ChartEditorBodyState();
}

class _ChartEditorBodyState extends State<_ChartEditorBody> {
  int _root = 0;
  int _type = 0;
  int _beats = 4;

  void _add(ChartChord chord) {
    widget.onChanged([...widget.chart, chord]);
  }

  @override
  Widget build(BuildContext context) {
    final diatonic = diatonicChords(widget.songKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'The app changes these chords in time so the style keeps going while you play guitar. 4 beats = one bar at the song tempo.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (widget.chart.isEmpty)
          Text('No chords yet. Add the verse / interlude progression.', style: Theme.of(context).textTheme.bodyMedium)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < widget.chart.length; i++)
                InputChip(
                  label: Text('${widget.chart[i].label}  ${widget.chart[i].beatsLabel}'),
                  onDeleted: () {
                    final next = [...widget.chart]..removeAt(i);
                    widget.onChanged(next);
                  },
                ),
            ],
          ),
        const SizedBox(height: 12),
        const SectionLabel('In this key'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final chord in diatonic)
              ActionChip(
                label: Text('${chord.roman} ${chord.name}'),
                onPressed: () => _add(
                  ChartChord(rootPc: chord.rootPc, chordType: chord.chordType, beats: _beats),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const SectionLabel('Length'),
        Wrap(
          spacing: 8,
          children: [
            for (final beats in const [1, 2, 4, 8])
              ChoiceChip(
                label: Text(ChartChord(rootPc: 0, beats: beats).beatsLabel),
                selected: _beats == beats,
                onSelected: (_) => setState(() => _beats = beats),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const SectionLabel('Any chord'),
        Wrap(
          spacing: 6,
          children: [
            for (var i = 0; i < 12; i++)
              ChoiceChip(
                label: Text(YamahaSysex.rootNames[i]),
                selected: _root == i,
                onSelected: (_) => setState(() => _root = i),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            for (final type in acmpChordTypes.take(12))
              ChoiceChip(
                label: Text(type.label),
                selected: _type == type.id,
                onSelected: (_) => setState(() => _type = type.id),
              ),
          ],
        ),
        const SizedBox(height: 8),
        PadButton(
          label: 'Add ${YamahaChord(rootPc: _root, chordType: _type).label}  ·  ${ChartChord(rootPc: 0, beats: _beats).beatsLabel}',
          onPressed: () => _add(ChartChord(rootPc: _root, chordType: _type, beats: _beats)),
        ),
      ],
    );
  }
}
