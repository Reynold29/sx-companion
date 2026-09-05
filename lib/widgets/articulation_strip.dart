import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'pad_button.dart';

class ArticulationStrip extends ConsumerStatefulWidget {
  const ArticulationStrip({super.key});

  @override
  ConsumerState<ArticulationStrip> createState() => _ArticulationStripState();
}

class _ArticulationStripState extends ConsumerState<ArticulationStrip> {
  double _x = 0.5;
  double _y = 0.15;

  void _apply(Offset local, Size size, {required bool down}) {
    final midi = ref.read(midiSessionProvider);
    final nx = (local.dx / size.width).clamp(0.0, 1.0);
    final ny = (1 - local.dy / size.height).clamp(0.0, 1.0);
    setState(() {
      _x = nx;
      _y = ny;
    });
    midi.setExpression((nx * 127).round());
    midi.setModulation((ny * 127).round());
    midi.setAftertouch((ny * 127).round());
    midi.setPitchBend((nx * 16383).round());
    if (nx < 0.22) {
      if (!midi.articulation1) midi.setArticulation(1, true);
    } else if (midi.articulation1) {
      midi.setArticulation(1, false);
    }
    if (nx > 0.78) {
      if (!midi.articulation2) midi.setArticulation(2, true);
    } else if (midi.articulation2) {
      midi.setArticulation(2, false);
    }
  }

  void _release() {
    final midi = ref.read(midiSessionProvider);
    midi.setArticulation(1, false);
    midi.setArticulation(2, false);
    midi.setPitchBend(8192);
  }

  @override
  Widget build(BuildContext context) {
    final midi = ref.watch(midiSessionProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Articulation / pedals'),
        Text(
          'Drag across the pad: left = Articulation 1, right = Articulation 2, horizontal = expression + bend, vertical = modulation.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 2.6,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                onPanStart: (d) => _apply(d.localPosition, size, down: true),
                onPanUpdate: (d) => _apply(d.localPosition, size, down: true),
                onPanEnd: (_) => _release(),
                onPanCancel: _release,
                onTapDown: (d) => _apply(d.localPosition, size, down: true),
                onTapUp: (_) => _release(),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        midi.articulation1 ? const Color(0xFFE0B84A) : const Color(0xFF2A3344),
                        const Color(0xFF1C2533),
                        midi.articulation2 ? const Color(0xFFE0B84A) : const Color(0xFF2A3344),
                      ],
                    ),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Stack(
                    children: [
                      const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.all(8), child: Text('ART 1'))),
                      const Align(alignment: Alignment.centerRight, child: Padding(padding: EdgeInsets.all(8), child: Text('ART 2'))),
                      Align(
                        alignment: Alignment(_x * 2 - 1, 1 - _y * 2),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(color: Color(0xFFE0B84A), shape: BoxShape.circle),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: PadButton(
                label: midi.sustainOn ? 'Sustain ON' : 'Sustain',
                selected: midi.sustainOn,
                onPressed: () => midi.setSustain(!midi.sustainOn),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PadButton(
                label: midi.articulation1 ? 'Art 1 ON' : 'Art 1',
                selected: midi.articulation1,
                onPressed: () => midi.setArticulation(1, !midi.articulation1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PadButton(
                label: midi.articulation2 ? 'Art 2 ON' : 'Art 2',
                selected: midi.articulation2,
                onPressed: () => midi.setArticulation(2, !midi.articulation2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        PadButton(
          label: 'Reset pedals',
          onPressed: () {
            setState(() {
              _x = 0.5;
              _y = 0;
            });
            midi.resetPedals();
          },
        ),
      ],
    );
  }
}
