import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jikido/src/ui/theme.dart';
import 'package:jikido/src/ui/volume_indicator.dart';
import 'package:jikido/src/volume.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required VolumeLevel? volume,
    double? lastSitting,
  }) =>
      tester.pumpWidget(MaterialApp(
        theme: jikidoTheme(),
        home: Scaffold(
          body: Center(
            child: VolumeIndicator(volume: volume, lastSitting: lastSitting),
          ),
        ),
      ));

  VolumeLevel presses(int n) => VolumeLevel(level: n / 16, steps: 16);

  testWidgets('silent says so, in vermilion, whatever last time was',
      (tester) async {
    await pump(tester, volume: presses(0), lastSitting: 0.5);

    final caption = tester.widget<Text>(
        find.text('silent — the bell will not be heard'));
    expect(caption.style?.color, JikidoColors.vermilion);
    expect(find.byIcon(Icons.volume_off), findsOneWidget);
  });

  testWidgets('the same as last time', (tester) async {
    await pump(tester, volume: presses(8), lastSitting: 9 / 16);
    expect(find.text('as last time'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
  });

  testWidgets('louder than last time', (tester) async {
    await pump(tester, volume: presses(12), lastSitting: 8 / 16);
    expect(find.text('louder than last time'), findsOneWidget);
  });

  testWidgets('quieter than last time', (tester) async {
    await pump(tester, volume: presses(4), lastSitting: 8 / 16);
    expect(find.text('quieter than last time'), findsOneWidget);
  });

  testWidgets('no caption before any sitting', (tester) async {
    await pump(tester, volume: presses(8));
    expect(find.byType(Text), findsNothing);
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
  });

  testWidgets('nothing at all when the level cannot be read', (tester) async {
    await pump(tester, volume: null, lastSitting: 0.5);
    expect(find.byType(Icon), findsNothing);
    expect(find.byType(Text), findsNothing);
  });
}
