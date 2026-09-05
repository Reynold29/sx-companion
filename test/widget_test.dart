import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sx700_remote/catalog/expansion.dart';
import 'package:sx700_remote/catalog/styles.dart';
import 'package:sx700_remote/catalog/voices.dart';
import 'package:sx700_remote/main.dart';

void main() {
  test('catalogs are populated', () {
    expect(sx700Voices, isNotEmpty);
    expect(sx700Styles, isNotEmpty);
    expect(sx700ExpansionVoices, isNotEmpty);
    expect(sx700Voices.first.name, isNotEmpty);
  });

  testWidgets('app shell loads', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: Sx700App()));
    await tester.pump();
    expect(find.text('Live'), findsWidgets);
    expect(find.text('Presets'), findsWidgets);
    expect(find.text('Setup'), findsWidgets);
  });
}
