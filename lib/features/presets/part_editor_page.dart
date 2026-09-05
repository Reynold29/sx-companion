import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/style.dart';
import '../../catalog/voice.dart';
import '../../catalog/sound_source.dart';
import '../../music/harmony.dart';
import '../../presets/models.dart';
import '../../state/providers.dart';
import '../../widgets/chart_editor.dart';
import '../../widgets/pad_button.dart';
import '../../widgets/sound_browser.dart';
import 'presets_page.dart';

class PartEditorPage extends ConsumerStatefulWidget {
  const PartEditorPage({super.key, required this.songId, required this.partId});

  final String songId;
  final String partId;

  @override
  ConsumerState<PartEditorPage> createState() => _PartEditorPageState();
}

class _PartEditorPageState extends ConsumerState<PartEditorPage> {
  final _name = TextEditingController();
  String _role = 'main';

  @override
  void initState() {
    super.initState();
    final part = _part();
    if (part != null) {
      _name.text = part.name;
      _role = part.role;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  SongPreset? _song() {
    final store = ref.read(presetStoreProvider);
    return store.songs.cast<SongPreset?>().firstWhere(
          (item) => item?.id == widget.songId,
          orElse: () => null,
        );
  }

  SongPart? _part() {
    final song = _song();
    if (song == null) return null;
    return song.parts.cast<SongPart?>().firstWhere(
          (item) => item?.id == widget.partId,
          orElse: () => null,
        );
  }

  Future<void> _save(void Function(SongPart part) edit) async {
    final song = _song();
    final part = _part();
    if (song == null || part == null) return;
    edit(part);
    await ref.read(presetStoreProvider).upsert(song);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final part = _part();
    if (part == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Part')),
        body: const Center(child: Text('Part not found')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit part'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final song = _song();
              if (song == null) return;
              song.parts.removeWhere((item) => item.id == part.id);
              await ref.read(presetStoreProvider).upsert(song);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Part name'),
            onChanged: (value) => _save((part) => part.name = value),
          ),
          const SizedBox(height: 12),
          const SectionLabel('Role'),
          Wrap(
            spacing: 8,
            children: [
              for (final role in const ['intro', 'verse', 'chorus', 'main', 'fill', 'bridge', 'outro', 'custom'])
                ChoiceChip(
                  label: Text(role),
                  selected: _role == role,
                  onSelected: (_) {
                    setState(() => _role = role);
                    _save((part) => part.role = role);
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          const SectionLabel('Style section'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final choice in styleSectionChoices)
                FilterChip(
                  label: Text(choice.$1),
                  selected: part.styleSection == choice.$2,
                  onSelected: (_) => _save((p) => p.styleSection = choice.$2),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const SectionLabel('Style (Preset / Expansion / USB)'),
          _PickTile(
            label: part.style?.name ?? 'Choose style',
            detail: part.style == null ? 'Not set' : part.style!.source.label,
            onTap: () async {
              final style = await pickStyle(context);
              if (style is SxStyle) {
                await _save((p) => p.style = SoundPick.style(style));
              }
            },
          ),
          const SizedBox(height: 16),
          const SectionLabel('Voices (Preset / Expansion / USB)'),
          _voiceTile('Right 1', part.right1, (pick) => _save((p) => p.right1 = pick)),
          _voiceTile('Right 2', part.right2, (pick) => _save((p) => p.right2 = pick)),
          _voiceTile('Left', part.left, (pick) => _save((p) => p.left = pick)),
          const SizedBox(height: 16),
          const SectionLabel('Registration memory'),
          SwitchListTile(
            title: const Text('Recall a registration with this part'),
            value: part.registrationSlot != null,
            onChanged: (on) => _save((p) {
              p.registrationSlot = on ? 1 : null;
              p.registrationBank = on ? 1 : null;
            }),
          ),
          if (part.registrationSlot != null) ...[
            ListTile(
              title: Text('Bank ${part.registrationBank ?? 1}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _save((p) => p.registrationBank = ((p.registrationBank ?? 1) - 1).clamp(1, 99)),
                    icon: const Icon(Icons.remove),
                  ),
                  IconButton(
                    onPressed: () => _save((p) => p.registrationBank = ((p.registrationBank ?? 1) + 1).clamp(1, 99)),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 1; i <= 8; i++)
                  ChoiceChip(
                    label: Text('$i'),
                    selected: part.registrationSlot == i,
                    onSelected: (_) => _save((p) => p.registrationSlot = i),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const SectionLabel('Tempo override'),
          SwitchListTile(
            title: const Text('Send tempo'),
            value: part.tempo != null,
            onChanged: (on) => _save((p) => p.tempo = on ? 120 : null),
          ),
          if (part.tempo != null)
            Slider(
              min: 40,
              max: 220,
              value: part.tempo!.clamp(40, 220).toDouble(),
              label: '${part.tempo}',
              onChanged: (value) => _save((p) => p.tempo = value.round()),
            ),
          const SizedBox(height: 16),
          const SectionLabel('Chord chart (hands-free ACMP)'),
          ChartEditor(
            chart: part.chart,
            songKey: HarmonyKey(tonic: _song()?.tonic ?? 0, minor: _song()?.minor ?? false),
            onChanged: (chart) => _save((p) => p.chart = chart),
          ),
          SwitchListTile(
            title: const Text('Loop this chart'),
            subtitle: const Text('Keep vamping these chords until you stop or jump to another part.'),
            value: part.loopChart,
            onChanged: (on) => _save((p) => p.loopChart = on),
          ),
          const SizedBox(height: 8),
          const SectionLabel('Interlude clip (optional right hand)'),
          Text(
            'Record a take from the SX700 keys (or the Practice keyboard). On Play, chords still drive the style and this clip is sent to Right 1 so the keyboard is not silent while you play guitar.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          _ClipControls(part: part, onSave: _save),
        ],
      ),
    );
  }

  Widget _voiceTile(String label, SoundPick? pick, ValueChanged<SoundPick?> onPicked) {
    return _PickTile(
      label: pick?.name ?? label,
      detail: pick == null ? 'Tap to choose $label' : '${pick.source.label}  ·  $label',
      onTap: () async {
        final voice = await pickVoice(context);
        if (voice is SxVoice) {
          onPicked(SoundPick.voice(voice, index: voice.selectIndex));
        }
      },
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({required this.label, required this.detail, required this.onTap});

  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(detail),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _ClipControls extends ConsumerWidget {
  const _ClipControls({
    required this.part,
    required this.onSave,
  });

  final SongPart part;
  final Future<void> Function(void Function(SongPart part) edit) onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final midi = ref.watch(midiSessionProvider);
    final store = ref.read(presetStoreProvider);
    return Column(
      children: [
        if (part.clipId != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.graphic_eq),
            title: const Text('Clip saved'),
            subtitle: const Text('Plays with this part on Play'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await store.deleteClip(part.clipId);
                await onSave((p) => p.clipId = null);
              },
            ),
          ),
        PadButton(
          label: midi.recording ? 'Stop & attach clip' : 'Record clip',
          selected: midi.recording,
          color: midi.recording ? const Color(0xFFFF6B6B) : null,
          onPressed: () async {
            if (midi.recording) {
              final bytes = midi.stopRecording(bpm: midi.tempoBpm);
              if (bytes == null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nothing was recorded. Play the keys while Record is on.')),
                  );
                }
                return;
              }
              final id = part.id;
              await store.saveClip(id, bytes);
              await onSave((p) => p.clipId = id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Clip attached to this part.')),
                );
              }
            } else {
              midi.startRecording();
            }
          },
        ),
      ],
    );
  }
}
