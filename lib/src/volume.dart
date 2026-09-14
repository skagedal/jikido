import 'dart:async';

import 'package:flutter/services.dart';

/// The volume the bell will ring at, as the platform reports it.
class VolumeLevel {
  const VolumeLevel({required this.level, required this.steps});

  /// From 0.0 (silent) to 1.0.
  final double level;

  /// How many presses of a volume button take it from silent to full.
  final int steps;

  bool get isSilent => level <= 0;

  /// How this level compares with [last], the level at the last sitting's
  /// opening bell, or null if there has not been one.
  ///
  /// Within one step either way counts as the same: a single press of a
  /// button is not a difference anyone would hear across a room.
  VolumeComparison compareWith(double? last) {
    if (isSilent) {
      return VolumeComparison.silent;
    }
    if (last == null) {
      return VolumeComparison.noPrevious;
    }
    final step = steps > 0 ? 1 / steps : 0.0;
    // Levels arrive as quotients, so a step apart can be a hair over a step.
    const tolerance = 1e-6;
    final difference = level - last;
    if (difference.abs() <= step + tolerance) {
      return VolumeComparison.same;
    }
    return difference > 0 ? VolumeComparison.louder : VolumeComparison.quieter;
  }

  @override
  bool operator ==(Object other) =>
      other is VolumeLevel && other.level == level && other.steps == steps;

  @override
  int get hashCode => Object.hash(level, steps);

  @override
  String toString() => 'VolumeLevel($level of $steps steps)';
}

enum VolumeComparison { silent, noPrevious, same, louder, quieter }

/// Reads the volume the bell will ring at, and says when it changes.
abstract class Volume {
  /// The current level, or null if the platform will not say.
  Future<VolumeLevel?> read();

  /// Every change in level. Empty if the platform will not say.
  Stream<VolumeLevel> get changes;
}

/// [Volume] over Jikido's own platform channels: the alarm stream on
/// Android, the output volume on iOS. See
/// `specs/drafts/volume-indicator.md` for why not a plugin.
class PlatformVolume implements Volume {
  const PlatformVolume();

  static const MethodChannel _methods = MethodChannel('jikido/volume');
  static const EventChannel _events = EventChannel('jikido/volume/changes');

  @override
  Future<VolumeLevel?> read() async {
    try {
      return _parse(await _methods.invokeMethod<Object?>('get'));
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Stream<VolumeLevel> get changes => _events
      .receiveBroadcastStream()
      .handleError((Object _) {},
          test: (error) =>
              error is MissingPluginException || error is PlatformException)
      .map(_parse)
      .where((level) => level != null)
      .cast<VolumeLevel>();

  static VolumeLevel? _parse(Object? message) {
    if (message is! Map) {
      return null;
    }
    final level = message['level'];
    final steps = message['steps'];
    if (level is! num || steps is! int) {
      return null;
    }
    return VolumeLevel(level: level.toDouble().clamp(0.0, 1.0), steps: steps);
  }
}
