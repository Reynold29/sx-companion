import 'package:flutter/material.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../midi/yamaha_sysex.dart';
import '../../state/providers.dart';
import '../../widgets/pad_button.dart';

class ConnectPage extends ConsumerStatefulWidget {
  const ConnectPage({super.key});

  @override
  ConsumerState<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends ConsumerState<ConnectPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(midiSessionProvider).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final midi = ref.watch(midiSessionProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  midi.isConnected ? 'Connected' : 'USB MIDI',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(midi.connectionLabel),
                const SizedBox(height: 8),
                Text(
                  'IN ${midi.activity.inbound}   ·   OUT ${midi.activity.outbound}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (midi.keyboardIdentity != null) ...[
                  const SizedBox(height: 8),
                  Text('Identity: ${midi.keyboardIdentity}'),
                ],
                if (midi.lastError != null) ...[
                  const SizedBox(height: 8),
                  Text(midi.lastError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: midi.scanning ? null : () => midi.refreshDevices(),
                      icon: midi.scanning
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh),
                      label: const Text('Scan'),
                    ),
                    const SizedBox(width: 8),
                    if (midi.isConnected)
                      OutlinedButton(
                        onPressed: () async {
                          await midi.disconnect();
                          await WakelockPlus.disable();
                        },
                        child: const Text('Disconnect'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const SectionLabel('Devices'),
        if (midi.devices.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.usb_off),
              title: Text('No MIDI devices yet'),
              subtitle: Text(
                'Use a USB-C/Lightning OTG adapter plus USB-A to USB-B into [USB TO HOST]. iOS Simulator cannot see USB MIDI.',
              ),
            ),
          )
        else
          for (final device in midi.devices) _DeviceTile(device: device),
        const SizedBox(height: 16),
        const SectionLabel('Keyboard MIDI template'),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('On the PSR-SX700: [MENU] → [MIDI]'),
                SizedBox(height: 8),
                Text('1. Template: All Parts'),
                Text('2. System Exclusive Receive = On'),
                Text('3. Chord SysEx Transmit = On  and  Chord SysEx Receive = On'),
                Text('4. Chord Detect Receive = On for Left / channel 3'),
                Text('5. Program Change Transmit = On (so the app can name panel voices)'),
                Text('6. Start/Stop = Style'),
                Text('7. Clock = Internal'),
                SizedBox(height: 8),
                Text(
                  'USB1 is Style / keyboard. USB2 is Song. If a mixer slider hits the wrong group, assign Port 1 / Port 2 below after connecting both endpoints.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const SectionLabel('Cable'),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Android USB-C: OTG + USB-A to USB-B, or USB-C to USB-B.\n'
              'iPhone 15+ / USB-C iPad: USB-C to USB-B.\n'
              'Lightning: Camera adapter + USB-A to USB-B.\n\n'
              'The SX700 has no built-in Bluetooth MIDI. Wireless needs a UD-BT01 or MD-BT01.',
            ),
          ),
        ),
      ],
    );
  }
}

class _DeviceTile extends ConsumerWidget {
  const _DeviceTile({required this.device});

  final MidiDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final midi = ref.watch(midiSessionProvider);
    final isUsb1 = midi.usb1?.id == device.id;
    final isUsb2 = midi.usb2?.id == device.id;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                device.connected ? Icons.usb : Icons.usb_outlined,
                color: device.connected ? const Color(0xFF3DDC84) : null,
              ),
              title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                '${device.type.name}  ·  ${device.outputPorts.length} out / ${device.inputPorts.length} in',
              ),
              trailing: FilledButton(
                onPressed: () async {
                  await midi.connect(device, role: MidiPortRole.usb1);
                  if (midi.isConnected) {
                    await WakelockPlus.enable();
                  }
                },
                child: Text(device.connected || isUsb1 ? 'Connected' : 'Connect'),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: PadButton(
                    label: isUsb1 ? 'USB1 ✓' : 'Use as USB1',
                    selected: isUsb1,
                    onPressed: () => midi.assignRole(device, MidiPortRole.usb1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PadButton(
                    label: isUsb2 ? 'USB2 ✓' : 'Use as USB2',
                    selected: isUsb2,
                    onPressed: () async {
                      if (!device.connected) {
                        await midi.connect(device, role: MidiPortRole.usb2);
                      } else {
                        midi.assignRole(device, MidiPortRole.usb2);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
