import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../midi/yamaha_sysex.dart';
import '../../state/providers.dart';
import 'preset_live_page.dart';

class PresetsPage extends ConsumerWidget {
  const PresetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(presetStoreProvider);
    return Scaffold(
      body: store.songs.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Save a song, write a chord chart for each part, then Play. The style follows the chart so you can switch to guitar. Record a clip if the right hand should play an interlude.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              itemCount: store.songs.length,
              itemBuilder: (context, index) {
                final song = store.songs[index];
                return Card(
                  child: ListTile(
                    title: Text(song.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${song.parts.length} parts  ·  ${song.tempo} BPM'),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => PresetLivePage(songId: song.id)),
                      );
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => store.deleteSong(song.id),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New song'),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Song preset'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Song name'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Create')),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) return;
    final song = await ref.read(presetStoreProvider).createSong(name);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PresetLivePage(songId: song.id)),
    );
  }
}

const styleSectionChoices = <(String, int)>[
  ('Intro A', YamahaSysex.introA),
  ('Intro B', YamahaSysex.introB),
  ('Intro C', YamahaSysex.introC),
  ('Intro D', YamahaSysex.introD),
  ('Main A', YamahaSysex.mainA),
  ('Main B', YamahaSysex.mainB),
  ('Main C', YamahaSysex.mainC),
  ('Main D', YamahaSysex.mainD),
  ('Fill AA', YamahaSysex.fillAA),
  ('Fill BB', YamahaSysex.fillBB),
  ('Fill CC', YamahaSysex.fillCC),
  ('Fill DD', YamahaSysex.fillDD),
  ('Break', YamahaSysex.breakFill),
  ('Ending A', YamahaSysex.endingA),
  ('Ending B', YamahaSysex.endingB),
  ('Ending C', YamahaSysex.endingC),
  ('Ending D', YamahaSysex.endingD),
];

String sectionLabel(int id) {
  for (final choice in styleSectionChoices) {
    if (choice.$2 == id) return choice.$1;
  }
  return 'Section';
}
