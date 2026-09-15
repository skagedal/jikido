import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jikido/src/ui/theme.dart';
import 'package:jikido/src/ui/volume_indicator.dart';
import 'package:jikido/src/volume.dart';

void main() {
  Future<void> pump(WidgetTester tester, VolumeLevel? volume) =>
      tester.pumpWidget(MaterialApp(
        theme: jikidoTheme(),
        home: Scaffold(
          body: Center(child: VolumeIndicator(volume: volume)),
        ),
      ));

  testWidgets('the level as a percentage', (tester) async {
    await pump(tester, const VolumeLevel(level: 0.5, steps: 16));
    final text = tester.widget<Text>(find.text('50%'));
    expect(text.style?.color, JikidoColors.faded);

    await pump(tester, const VolumeLevel(level: 1 / 3, steps: 15));
    expect(find.text('33%'), findsOneWidget);
  });

  testWidgets('silent is vermilion', (tester) async {
    await pump(tester, const VolumeLevel(level: 0, steps: 16));
    final text = tester.widget<Text>(find.text('0%'));
    expect(text.style?.color, JikidoColors.vermilion);
  });

  testWidgets('nothing at all when the level cannot be read', (tester) async {
    await pump(tester, null);
    expect(find.byType(Text), findsNothing);
  });
}
