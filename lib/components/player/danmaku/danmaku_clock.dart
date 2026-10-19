/// A smooth media clock between the player's relatively infrequent samples.
/// Playback speed is applied here exactly once, never again in the renderer.
class DanmakuClock {
  double positionMs = 0;
  double? _rawMs;
  Duration? _lastFrame;
  Duration _lastSample = Duration.zero;

  void reset(double rawMs, Duration frame) {
    positionMs = rawMs;
    _rawMs = rawMs;
    _lastFrame = frame;
    _lastSample = frame;
  }

  /// Returns true for a discontinuity requiring the visible stage to reset.
  bool update({
    required double rawMs,
    required Duration frame,
    required bool playing,
    required double speed,
    bool seek = false,
  }) {
    if (_lastFrame == null || seek) {
      reset(rawMs, frame);
      return seek;
    }
    final dt = (frame - _lastFrame!).inMicroseconds / 1000.0;
    _lastFrame = frame;
    final changed = rawMs != _rawMs;
    if (changed && (rawMs - _rawMs!).abs() > 1500) {
      reset(rawMs, frame);
      return true;
    }
    // Avoid an unbounded drift if a backend stops reporting progress.
    if (playing && (frame - _lastSample).inMilliseconds <= 1000) {
      positionMs += dt.clamp(0.0, 1000.0) * speed;
    }
    if (changed) {
      _rawMs = rawMs;
      _lastSample = frame;
      final error = rawMs - positionMs;
      if (error.abs() > 1500) {
        reset(rawMs, frame);
        return true;
      }
      // Correct small timing differences gently, without stepping backwards.
      if (playing) positionMs += error.clamp(-dt * 0.1, dt * 0.1);
    }
    return false;
  }
}
