import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/live/live_page.dart';
import '../features/mixer/mixer_page.dart';
import '../features/presets/presets_page.dart';
import '../features/setup/setup_page.dart';
import '../features/sound/sound_page.dart';
import '../state/providers.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  static const _pages = [
    LivePage(),
    MixerPage(),
    SoundPage(),
    PresetsPage(),
    SetupPage(),
  ];

  static const _titles = ['Live', 'Mixer', 'Sound', 'Presets', 'Setup'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(midiSessionProvider).start();
      ref.read(keyboardCatalogProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final midi = ref.watch(midiSessionProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                midi.isConnected ? 'USB' : 'OFF',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: midi.isConnected ? const Color(0xFF3DDC84) : Colors.white38,
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.sports_esports_outlined), selectedIcon: Icon(Icons.sports_esports), label: 'Live'),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'Mixer'),
          NavigationDestination(icon: Icon(Icons.piano_outlined), selectedIcon: Icon(Icons.piano), label: 'Sound'),
          NavigationDestination(icon: Icon(Icons.queue_music_outlined), selectedIcon: Icon(Icons.queue_music), label: 'Presets'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Setup'),
        ],
      ),
    );
  }
}
