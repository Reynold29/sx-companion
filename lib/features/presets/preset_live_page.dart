import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../midi/midi_session.dart';
import '../../midi/yamaha_sysex.dart';
import '../../music/harmony.dart';
import '../../presets/models.dart';
import '../../state/providers.dart';
import '../../widgets/articulation_strip.dart';
import '../../widgets/chord_pad.dart';
import '../../widgets/pad_button.dart';
import '../../widgets/registration_memory.dart';
import 'part_editor_page.dart';
import 'presets_page.dart';

class PresetLivePage extends ConsumerWidget {
  const PresetLivePage({super.key, required this.songId});

  final String songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(presetStoreProvider);
    final midi = ref.watch(midiSessionProvider);
    final song = store.songs.cast<SongPreset?>().firstWhere(
          (item) => item?.id == songId,
          orElse: () => null,
        );
    if (song == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Preset')),
        body: const Center(child: Text('Song not found')),
      );
    }
    final chord = midi.liveChord?.label ?? '—';
    return Scaffold(
      appBar: AppBar(
        title: Text(song.name),
        actions: [
          IconButton(
            tooltip: 'Add part',
            onPressed: () async {
              final part = SongPart(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: 'Part ${song.parts.length + 1}',
                role: 'custom',
              );
              song.parts.add(part);
              await store.upsert(song);
              if (!context.mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PartEditorPage(songId: song.id, partId: part.id),
                ),
              );
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    midi.arrangementPlaying
                        ? (midi.arrangementPartName ?? 'Playing chart')
                        : 'Standby',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    chord,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    midi.arrangementPlaying
                        ? 'Chords are running. Play guitar — ACMP follows the chart.'
                        : 'Play a part to run its chord chart. Tap a part name to load sounds only.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const SectionLabel('Song key'),
          Wrap(
            spacing: 6,
            children: [
              for (var i = 0; i < 12; i++)
                ChoiceChip(
                  label: Text(YamahaSysex.rootNames[i]),
                  selected: song.tonic == i,
                  onSelected: (_) async {
                    song.tonic = i;
                    await store.upsert(song);
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Major')),
              ButtonSegment(value: true, label: Text('Minor')),
            ],
            selected: {song.minor},
            onSelectionChanged: (value) async {
              song.minor = value.first;
              await store.upsert(song);
            },
          ),
          const SizedBox(height: 16),
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
                  onPressed: () => midi.stopArrangement(stopStyleToo: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          PadButton(
            label: midi.arrangementPlaying ? 'Playing chart…' : 'Play song (all parts)',
            selected: midi.arrangementPlaying,
            height: 56,
            onPressed: () => _playParts(ref, song, song.parts),
          ),
          const SizedBox(height: 16),
          const SectionLabel('Song parts'),
          if (song.parts.isEmpty) const Text('Add intro, verse, interlude, outro…'),
          for (final part in song.parts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                color: midi.arrangementPartName == part.name && midi.arrangementPlaying
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: ListTile(
                  title: Text(part.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    [
                      part.role,
                      sectionLabel(part.styleSection),
                      if (part.chart.isNotEmpty) part.chartSummary,
                      if (part.clipId != null) 'clip',
                    ].join('  ·  '),
                  ),
                  onTap: () => part.apply(midi),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Play chart',
                        onPressed: () => _playParts(ref, song, [part]),
                        icon: const Icon(Icons.play_arrow),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PartEditorPage(songId: song.id, partId: part.id),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          AcmpChordPad(initialKey: HarmonyKey(tonic: song.tonic, minor: song.minor)),
          const SizedBox(height: 16),
          const RegistrationMemoryPad(),
          const SizedBox(height: 16),
          const ArticulationStrip(),
        ],
      ),
    );
  }
}

Future<void> _playParts(
  WidgetRef ref,
  SongPreset song,
  List<SongPart> parts,
) async {
  final midi = ref.read(midiSessionProvider);
  final store = ref.read(presetStoreProvider);
  final steps = <ArrangementStep>[];
  for (var i = 0; i < parts.length; i++) {
    final part = parts[i];
    final clip = await store.loadClip(part.clipId);
    final isLast = i == parts.length - 1;
    steps.add(
      ArrangementStep(
        name: part.name,
        chart: List.of(part.chart),
        loop: part.loopChart && isLast,
        clip: clip,
        bpm: part.tempo,
        apply: () => part.apply(midi),
      ),
    );
  }
  midi.playArrangement(steps: steps, bpm: song.tempo);
}
