import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../catalog/keyboard_catalog.dart';
import '../catalog/sound_source.dart';
import '../catalog/style.dart';
import '../catalog/voice.dart';
import '../midi/midi_session.dart';
import '../state/providers.dart';
import 'pad_button.dart';

enum SoundBrowserKind { voices, styles }

class SoundBrowser extends ConsumerStatefulWidget {
  const SoundBrowser({
    super.key,
    required this.kind,
    this.part,
    this.onPart,
    required this.onVoice,
    required this.onStyle,
  });

  final SoundBrowserKind kind;
  final KeyboardPart? part;
  final ValueChanged<KeyboardPart>? onPart;
  final ValueChanged<SxVoice> onVoice;
  final ValueChanged<SxStyle> onStyle;

  static const voices = SoundBrowserKind.voices;
  static const styles = SoundBrowserKind.styles;

  @override
  ConsumerState<SoundBrowser> createState() => _SoundBrowserState();
}

class _SoundBrowserState extends ConsumerState<SoundBrowser> {
  SoundSource _source = SoundSource.preset;
  String _query = '';
  String? _category;

  Future<void> _import(KeyboardCatalog catalog) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json', 'csv', 'txt', 'JSON', 'CSV', 'TXT'],
    );
    if (files.isEmpty) return;
    final text = utf8.decode(await files.first.readAsBytes());
    final count = await catalog.importText(text, source: _source == SoundSource.preset ? SoundSource.usb : _source);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(catalog.lastImportNote ?? 'Imported $count')),
    );
  }

  Future<void> _learn(KeyboardCatalog catalog, MidiSession midi) async {
    final known = catalog.lookupVoice(
      msb: midi.lastBankMsb,
      lsb: midi.lastBankLsb,
      pc: midi.lastProgram,
    );
    if (known != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Already in catalog: ${known.name}')),
      );
      return;
    }
    await catalog.learnVoice(
      SxVoice(
        name: midi.lastSysexName ?? 'User ${midi.lastBankMsb}.${midi.lastBankLsb}.${midi.lastProgram}',
        category: 'Learned',
        type: 'USB/User',
        msb: midi.lastBankMsb,
        lsb: midi.lastBankLsb,
        pc: midi.lastProgram,
        slot: (midi.lastProgram - 1) + midi.lastBankLsb * 128,
        source: _source == SoundSource.expansion ? SoundSource.expansion : SoundSource.usb,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(catalog.lastImportNote ?? 'Learned')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(keyboardCatalogProvider);
    final midi = ref.watch(midiSessionProvider);
    final isVoices = widget.kind == SoundBrowserKind.voices;
    final voices = catalog.voices(_source);
    final styles = catalog.styles(_source);
    final categories = isVoices
        ? ({for (final v in voices) v.category}.toList()..sort())
        : ({for (final s in styles) s.category}.toList()..sort());
    final filteredVoices = voices.where((voice) {
      if (_category != null && voice.category != _category) return false;
      return voice.matches(_query);
    }).toList();
    final filteredStyles = styles.where((style) {
      if (_category != null && style.category != _category) return false;
      return style.matches(_query);
    }).toList();
    final fromPanel = catalog.lookupVoice(
      msb: midi.lastBankMsb,
      lsb: midi.lastBankLsb,
      pc: midi.lastProgram,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              if (isVoices && widget.part != null && widget.onPart != null)
                SegmentedButton<KeyboardPart>(
                  segments: [
                    for (final p in KeyboardPart.values)
                      ButtonSegment(value: p, label: Text(p.label)),
                  ],
                  selected: {widget.part!},
                  onSelectionChanged: (value) => widget.onPart!(value.first),
                ),
              if (isVoices) const SizedBox(height: 8),
              SegmentedButton<SoundSource>(
                segments: [
                  for (final source in SoundSource.values)
                    ButtonSegment(
                      value: source,
                      label: Text(switch (source) {
                        SoundSource.preset => 'Preset',
                        SoundSource.expansion => 'Exp',
                        SoundSource.usb => 'USB',
                      }),
                    ),
                ],
                selected: {_source},
                onSelectionChanged: (value) => setState(() {
                  _source = value.first;
                  _category = null;
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: isVoices
                      ? 'Search ${_source.label.toLowerCase()} voices'
                      : 'Search ${_source.label.toLowerCase()} styles',
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              if (_source != SoundSource.preset) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: PadButton(
                        label: 'Import names',
                        height: 44,
                        onPressed: () => _import(catalog),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PadButton(
                        label: 'Learn from panel',
                        height: 44,
                        onPressed: () => _learn(catalog, midi),
                      ),
                    ),
                  ],
                ),
              ],
              if (fromPanel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Keyboard last sent: ${fromPanel.name}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: const Text('All'),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
              ),
              for (final cat in categories)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: _category == cat,
                    onSelected: (_) => setState(() => _category = cat),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: isVoices
              ? (filteredVoices.isEmpty
                  ? _EmptySource(
                      source: _source,
                      kind: 'voices',
                      onImport: () => _import(catalog),
                    )
                  : ListView.builder(
                      itemCount: filteredVoices.length,
                      itemBuilder: (context, index) {
                        final voice = filteredVoices[index];
                        return ListTile(
                          title: Text(voice.name),
                          subtitle: Text('${voice.source.label}  ·  ${voice.category}  ·  ${voice.subtitle}'),
                          onTap: () => widget.onVoice(voice),
                        );
                      },
                    ))
              : (filteredStyles.isEmpty
                  ? _EmptySource(
                      source: _source,
                      kind: 'styles',
                      onImport: () => _import(catalog),
                    )
                  : ListView.builder(
                      itemCount: filteredStyles.length,
                      itemBuilder: (context, index) {
                        final style = filteredStyles[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text('${style.index + 1}', style: const TextStyle(fontSize: 12)),
                          ),
                          title: Text(style.name),
                          subtitle: Text(style.subtitle),
                          onTap: () => widget.onStyle(style),
                        );
                      },
                    )),
        ),
      ],
    );
  }
}

class _EmptySource extends StatelessWidget {
  const _EmptySource({
    required this.source,
    required this.kind,
    required this.onImport,
  });

  final SoundSource source;
  final String kind;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final usb = source == SoundSource.usb;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          usb ? 'No USB / User $kind yet' : 'No extra $kind yet',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          usb
              ? 'Connecting USB MIDI does not list files from USER or a USB stick. Import a name list, or play a User voice on the panel with Program Change Transmit on, then tap Learn from panel.'
              : 'Factory expansion $kind are listed when this tab has the Yamaha pre-installed packs. Extra pack names can be imported.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        PadButton(label: 'Import name list', onPressed: onImport),
      ],
    );
  }
}

Future<SxVoice?> pickVoice(BuildContext context) {
  return showModalBottomSheet<SxVoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: SoundBrowser(
          kind: SoundBrowser.voices,
          onVoice: (voice) => Navigator.pop(context, voice),
          onStyle: (_) {},
        ),
      );
    },
  );
}

Future<SxStyle?> pickStyle(BuildContext context) {
  return showModalBottomSheet<SxStyle>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: SoundBrowser(
          kind: SoundBrowser.styles,
          onVoice: (_) {},
          onStyle: (style) => Navigator.pop(context, style),
        ),
      );
    },
  );
}
