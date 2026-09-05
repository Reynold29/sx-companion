import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'pad_button.dart';

class RegistrationMemoryPad extends ConsumerWidget {
  const RegistrationMemoryPad({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final midi = ref.watch(midiSessionProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Registration memory'),
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: () => midi.setRegistrationBank(midi.registrationBankNumber - 1),
              icon: const Icon(Icons.remove),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Bank ${midi.registrationBankNumber}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text('Slot ${midi.registrationSlot}', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            IconButton.filledTonal(
              onPressed: () => midi.setRegistrationBank(midi.registrationBankNumber + 1),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.4,
          children: [
            for (var i = 1; i <= 8; i++)
              PadButton(
                label: '$i',
                selected: midi.registrationSlot == i,
                height: 56,
                onPressed: () => midi.recallRegistration(i),
              ),
          ],
        ),
      ],
    );
  }
}
