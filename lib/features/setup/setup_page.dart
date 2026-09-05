import 'package:flutter/material.dart';

import '../connect/connect_page.dart';
import '../library/library_page.dart';
import '../practice/practice_page.dart';

class SetupPage extends StatelessWidget {
  const SetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: 'USB'),
              Tab(text: 'Practice'),
              Tab(text: 'Files'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ConnectPage(),
                PracticePage(),
                LibraryPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
