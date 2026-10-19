import 'package:flutter_test/flutter_test.dart';
import 'package:ecohub_android/components/player/danmaku/danmaku_clock.dart';

void main() {
  test('moves every frame between sparse player samples', () {
    final clock = DanmakuClock();
    clock.update(rawMs: 1000, frame: Duration.zero, playing: true, speed: 1);
    for (var frame = 1; frame <= 5; frame++) {
      clock.update(
        rawMs: 1000,
        frame: Duration(milliseconds: frame * 16),
        playing: true,
        speed: 1,
      );
      expect(clock.positionMs, 1000 + frame * 16);
    }
    clock.update(
      rawMs: 1100,
      frame: const Duration(milliseconds: 100),
      playing: true,
      speed: 1,
    );
    expect(clock.positionMs, 1100);
  });
  test('applies double speed once and freezes during pause or buffering', () {
    final clock = DanmakuClock();
    clock.update(rawMs: 0, frame: Duration.zero, playing: true, speed: 2);
    clock.update(
      rawMs: 0,
      frame: const Duration(milliseconds: 100),
      playing: true,
      speed: 2,
    );
    expect(clock.positionMs, 200);
    clock.update(
      rawMs: 200,
      frame: const Duration(milliseconds: 200),
      playing: false,
      speed: 2,
    );
    clock.update(
      rawMs: 200,
      frame: const Duration(milliseconds: 500),
      playing: false,
      speed: 2,
    );
    expect(clock.positionMs, 200);
    clock.update(
      rawMs: 200,
      frame: const Duration(milliseconds: 600),
      playing: true,
      speed: 2,
    );
    expect(clock.positionMs, 400);
  });
  test(
    'small explicit seek and large forward/backward seeks reset the stage',
    () {
      final clock = DanmakuClock();
      clock.update(rawMs: 10000, frame: Duration.zero, playing: true, speed: 1);
      expect(
        clock.update(
          rawMs: 9500,
          frame: const Duration(milliseconds: 16),
          playing: false,
          speed: 1,
          seek: true,
        ),
        isTrue,
      );
      expect(clock.positionMs, 9500);
      expect(
        clock.update(
          rawMs: 60000,
          frame: const Duration(milliseconds: 32),
          playing: true,
          speed: 1,
        ),
        isTrue,
      );
      expect(clock.positionMs, 60000);
      expect(
        clock.update(
          rawMs: 0,
          frame: const Duration(milliseconds: 48),
          playing: true,
          speed: 1,
        ),
        isTrue,
      );
      expect(clock.positionMs, 0);
    },
  );
  test('stops extrapolating if backend stalls without a buffering event', () {
    final clock = DanmakuClock();
    for (var ms = 0; ms <= 1200; ms += 100) {
      clock.update(
        rawMs: 0,
        frame: Duration(milliseconds: ms),
        playing: true,
        speed: 1,
      );
    }
    expect(clock.positionMs, 1000);
  });
}
