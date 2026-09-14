import 'package:flutter/material.dart';

import '../volume.dart';
import 'theme.dart';

/// How loud the bell will ring, next to how loud it rang last time.
///
/// Nothing at all when the level cannot be read: a bar stuck at some default
/// would be a confident wrong answer.
class VolumeIndicator extends StatelessWidget {
  const VolumeIndicator({
    super.key,
    required this.volume,
    required this.lastSitting,
  });

  final VolumeLevel? volume;

  /// The level at the last sitting's opening bell, if there has been one.
  final double? lastSitting;

  static const double width = 280;

  @override
  Widget build(BuildContext context) {
    final volume = this.volume;
    if (volume == null) {
      return const SizedBox.shrink();
    }
    final comparison = volume.compareWith(lastSitting);
    final caption = switch (comparison) {
      VolumeComparison.silent => 'silent — the bell will not be heard',
      VolumeComparison.noPrevious => null,
      VolumeComparison.same => 'as last time',
      VolumeComparison.louder => 'louder than last time',
      VolumeComparison.quieter => 'quieter than last time',
    };

    return Semantics(
      label: 'Volume ${(volume.level * 100).round()} percent',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: width),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  volume.isSilent ? Icons.volume_off : Icons.volume_up,
                  size: 16,
                  color: volume.isSilent
                      ? JikidoColors.vermilion
                      : JikidoColors.faded,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 12,
                    child: CustomPaint(
                      painter: _LevelPainter(
                        level: volume.level,
                        // No tick at silence: the caption says all there is.
                        tick: volume.isSilent ? null : lastSitting,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Always the same height, so that the controls below do not
            // jump when the caption comes and goes.
            SizedBox(
              height: 22,
              child: caption == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        caption,
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1,
                          color: comparison == VolumeComparison.silent
                              ? JikidoColors.vermilion
                              : JikidoColors.faded,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelPainter extends CustomPainter {
  const _LevelPainter({required this.level, required this.tick});

  final double level;
  final double? tick;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final line = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      line..color = JikidoColors.faded.withValues(alpha: 0.4),
    );
    if (level > 0) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width * level, y),
        line..color = JikidoColors.paper,
      );
    }
    final tick = this.tick;
    if (tick != null) {
      final x = size.width * tick;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..strokeWidth = 1.5
          ..color = JikidoColors.faded,
      );
    }
  }

  @override
  bool shouldRepaint(_LevelPainter old) =>
      old.level != level || old.tick != tick;
}
