import 'package:flutter/material.dart';

import '../volume.dart';
import 'theme.dart';

/// How loud the bell will ring, as a percentage, for a corner of the screen.
///
/// Nothing at all when the level cannot be read: a number stuck at some
/// default would be a confident wrong answer. At zero it is vermilion, since
/// then the bell will not be heard.
class VolumeIndicator extends StatelessWidget {
  const VolumeIndicator({super.key, required this.volume});

  final VolumeLevel? volume;

  @override
  Widget build(BuildContext context) {
    final volume = this.volume;
    if (volume == null) {
      return const SizedBox.shrink();
    }
    final percent = (volume.level * 100).round();
    return Semantics(
      label: 'Volume $percent percent',
      excludeSemantics: true,
      child: Text(
        '$percent%',
        style: TextStyle(
          fontSize: 13,
          letterSpacing: 1,
          color: volume.isSilent ? JikidoColors.vermilion : JikidoColors.faded,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
