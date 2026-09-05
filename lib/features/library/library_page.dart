import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../midi/yamaha_sysex.dart';
import '../../state/providers.dart';
import '../../widgets/pad_button.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  String? _songName;
  String? _error;

  Future<void> _pickAndPlay() async {
    final midi = ref.read(midiSessionProvider);
    setState(() => _error = null);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['mid', 'midi', 'MID', 'MIDI'],
      );
      if (files.isEmpty) return;
      final file = files.first;
      final bytes = await file.readAsBytes();
      setState(() => _songName = file.name);
      await midi.playSong(bytes, port: MidiPortRole.usb2);
    } catch (error) {
      setState(() => _error = '$error');
    }
  }

  Future<void> _openRecordings() async {
    final dir = await getApplicationDocumentsDirectory();
    final recordings = Directory('${dir.path}/recordings');
    if (!mounted) return;
    if (!await recordings.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No recordings yet. Use Practice → Record.')),
      );
      return;
    }
    final files = recordings
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.mid'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        if (files.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No SMF recordings saved yet.'),
          );
        }
        return ListView(
          children: [
            for (final file in files)
              ListTile(
                title: Text(file.uri.pathSegments.last),
                subtitle: Text(file.path),
                onTap: () async {
                  Navigator.pop(context);
                  final bytes = await file.readAsBytes();
                  setState(() => _songName = file.uri.pathSegments.last);
                  await ref.read(midiSessionProvider).playSong(bytes);
                },
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final midi = ref.watch(midiSessionProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        const SectionLabel('Play SMF into the keyboard'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The phone streams a Standard MIDI File to USB2 so the SX700 plays it as a 16-channel sound module. Set the MIDI template to Song if parts land on Style instead.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                if (_songName != null) Text('Loaded: $_songName', style: const TextStyle(fontWeight: FontWeight.w700)),
                if (midi.playingLyric != null) Text(midi.playingLyric!),
                if (_error != null)
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: PadButton(
                        label: midi.playing ? 'Playing…' : 'Pick .mid file',
                        selected: midi.playing,
                        onPressed: _pickAndPlay,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PadButton(
                        label: 'Stop',
                        color: const Color(0xFFFF6B6B),
                        onPressed: midi.stopPlayback,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                PadButton(label: 'Play a saved recording', onPressed: _openRecordings),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const SectionLabel('USER drive files (USB stick)'),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'USB TO HOST is MIDI only. It cannot copy .sty, .rgt, .mid, or expansion packs into USER memory the way Musicsoft Downloader does on Windows.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 12),
                Text('To load styles, registration banks, songs, or audio onto the keyboard:'),
                SizedBox(height: 8),
                Text('1. Copy the files onto a USB flash drive.'),
                Text('2. Plug it into [USB TO DEVICE] on the SX700.'),
                Text('3. Open the File Selection display and copy into USER.'),
                SizedBox(height: 12),
                Text(
                  'This app can still play SMF from the phone over MIDI, recall registrations 1–8, and record what the keyboard sends.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
