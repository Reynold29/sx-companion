import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_shell.dart';
import 'app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: Sx700App()));
}

class Sx700App extends StatelessWidget {
  const Sx700App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SX700 Remote',
      debugShowCheckedModeBanner: false,
      theme: buildSxTheme(),
      home: const AppShell(),
    );
  }
}
