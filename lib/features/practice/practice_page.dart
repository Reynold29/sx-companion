import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../state/providers.dart';
import '../../widgets/chord_pad.dart';
import '../../widgets/pad_button.dart';

class PracticePage extends ConsumerStatefulWidget {
  const PracticePage({super.key});

  @override
  ConsumerState<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends ConsumerState<PracticePage> {
  bool _metronomeOn = false;
  int _metroBpm = 120;
  int _beat = 0;
  Timer? _metro;
  String? _lastSavePath;

  static const _white = [0, 2, 4, 5, 7, 9, 11];
  static const _black = [1, 3, 6, 8, 10];

  @override
  void dispose() {
    _metro?.cancel();
    super.dispose();
  }

  void _toggleMetronome() {
    if (_metronomeOn) {
      _metro?.cancel();
      setState(() {
        _metronomeOn = false;
        _beat = 0;
      });
      return;
    }
    setState(() => _metronomeOn = true);
    _tick();
    _metro = Timer.periodic(
      Duration(milliseconds: (60000 / _metroBpm).round()),
      (_) => _tick(),
    );
  }

  void _tick() {
    final midi = ref.read(midiSessionProvider);
    setState(() => _beat = (_beat % 4) + 1);
    HapticFeedback.selectionClick();
    midi.noteOn(_beat == 1 ? 76 : 77, channel: 9, velocity: _beat == 1 ? 110 : 70);
    Future<void>.delayed(const Duration(milliseconds: 40), () {
      midi.noteOff(_beat == 1 ? 76 : 77, channel: 9);
    });
  }

  Future<void> _toggleRecord() async {
    final midi = ref.read(midiSessionProvider);
    if (midi.recording) {
      final bytes = midi.stopRecording(bpm: midi.tempoBpm);
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nothing was recorded.')),
          );
        }
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final recordings = Directory('${dir.path}/recordings');
      await recordings.create(recursive: true);
      final name = 'sx700_${DateTime.now().millisecondsSinceEpoch}.mid';
      final file = File('${recordings.path}/$name');
      await file.writeAsBytes(bytes, flush: true);
      setState(() => _lastSavePath = file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved $name')),
        );
      }
    } else {
      midi.startRecording();
    }
  }

  @override
  Widget build(BuildContext context) {
    final midi = ref.watch(midiSessionProvider);
    final chord = midi.liveChord?.label ?? '—';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text('CHORD', style: Theme.of(context).textTheme.labelMedium),
                Text(
                  chord,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  'Updates from the chord pad on Live, and from the keyboard when Chord SysEx Transmit is on.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const AcmpChordPad(),
        const SizedBox(height: 16),
        const SectionLabel('On-screen keys'),
        SizedBox(
          height: 140,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const octaves = 2;
              const start = 48;
              final whiteCount = octaves * 7;
              final w = constraints.maxWidth / whiteCount;
              return Stack(
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < whiteCount; i++)
                        _Key(
                          width: w,
                          black: false,
                          lit: midi.heldNotes.contains(start + _whiteToMidi(i)),
                          onDown: () => midi.noteOn(start + _whiteToMidi(i), channel: 2),
                          onUp: () => midi.noteOff(start + _whiteToMidi(i), channel: 2),
                        ),
                    ],
                  ),
                  ...[
                    for (var i = 0; i < whiteCount; i++)
                      if (_hasBlackAfter(_whiteToMidi(i) % 12))
                        Positioned(
                          left: (i + 1) * w - w * 0.32,
                          child: _Key(
                            width: w * 0.64,
                            height: 84,
                            black: true,
                            lit: midi.heldNotes.contains(start + _whiteToMidi(i) + 1),
                            onDown: () => midi.noteOn(start + _whiteToMidi(i) + 1, channel: 2),
                            onUp: () => midi.noteOff(start + _whiteToMidi(i) + 1, channel: 2),
                          ),
                        ),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Notes go to MIDI channel 3 (Left / chord detect). Enable Chord Detect on that channel if you want the Style to follow.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        const SectionLabel('Metronome'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    for (var b = 1; b <= 4; b++)
                      Expanded(
                        child: Container(
                          height: 18,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: _metronomeOn && _beat == b
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                  ],
                ),
                Slider(
                  min: 40,
                  max: 208,
                  value: _metroBpm.toDouble(),
                  label: '$_metroBpm',
                  onChanged: _metronomeOn
                      ? null
                      : (value) => setState(() => _metroBpm = value.round()),
                ),
                PadButton(
                  label: _metronomeOn ? 'Stop metronome  $_metroBpm' : 'Start metronome  $_metroBpm',
                  selected: _metronomeOn,
                  onPressed: _toggleMetronome,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const SectionLabel('MIDI recorder'),
        PadButton(
          label: midi.recording ? 'Stop & save SMF' : 'Record USB MIDI in',
          color: midi.recording ? const Color(0xFFFF6B6B) : null,
          selected: midi.recording,
          height: 56,
          onPressed: _toggleRecord,
        ),
        if (_lastSavePath != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Last file:\n$_lastSavePath', style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }

  int _whiteToMidi(int whiteIndex) {
    final octave = whiteIndex ~/ 7;
    final pc = _white[whiteIndex % 7];
    return octave * 12 + pc;
  }

  bool _hasBlackAfter(int pc) => _black.contains((pc + 1) % 12) && pc != 4 && pc != 11;
}

class _Key extends StatelessWidget {
  const _Key({
    required this.width,
    required this.black,
    required this.lit,
    required this.onDown,
    required this.onUp,
    this.height = 140,
  });

  final double width;
  final double height;
  final bool black;
  final bool lit;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onDown(),
      onTapUp: (_) => onUp(),
      onTapCancel: onUp,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: black
              ? (lit ? const Color(0xFFE0B84A) : Colors.black)
              : (lit ? const Color(0xFFE0B84A) : Colors.white),
          border: Border.all(color: Colors.black87, width: 0.6),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
