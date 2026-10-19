import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecohub_android/desktop/player_input.dart';
import 'package:ecohub_android/components/player/player_device_control_mixin.dart';
import 'package:ecohub_android/tv/tv_home_design.dart';

class VolumeSession extends ChangeNotifier with PlayerDeviceControlMixin {
  final applied = <double>[];
  @override
  void applyPlaybackVolume(double volume) => applied.add(volume);
}

void main() {
  test('Windows volume is local, clamped and respects mute', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final s = VolumeSession();
    addTearDown(s.dispose);
    await s.loadWindowLevels();
    expect(s.volume, 1);
    s.setVolume(.4);
    expect(s.applied.last, .4);
    s.setVolume(2);
    expect(s.applied.last, 1);
    s.setMutedInternal(true);
    s.setVolume(.6);
    expect(s.applied.last, 0);
    expect(s.volume, .6);
    s.setMutedInternal(false);
    s.setVolume(-1);
    expect(s.applied.last, 0);
  });
  test('Windows typography remains compact', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(const TvHomeMetrics(1920).scale, 1.15);
    expect(const TvHomeMetrics(1280).scale, 1.15);
  });
  testWidgets('desktop keyboard playback and fullscreen', (tester) async {
    final e = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DesktopPlayerInput(
            onTogglePlay: () => e.add('play'),
            onShowControls: () {},
            onSeekSeconds: (v) => e.add('seek$v'),
            onAdjustVolume: (v) => e.add('volume$v'),
            onToggleMute: () => e.add('mute'),
            onToggleFullscreen: () => e.add('full'),
            onExitFullscreen: () => e.add('exit'),
            isFullscreen: true,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final k in [
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.keyM,
      LogicalKeyboardKey.keyF,
      LogicalKeyboardKey.f11,
      LogicalKeyboardKey.escape,
    ]) {
      await tester.sendKeyEvent(k);
    }
    expect(e, [
      'play',
      'seek-10',
      'seek10',
      'volume0.05',
      'volume-0.05',
      'mute',
      'full',
      'full',
      'exit',
    ]);
  });
  testWidgets('typing and buttons keep their keyboard actions', (tester) async {
    var actions = 0, buttons = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DesktopPlayerInput(
            onTogglePlay: () => actions++,
            onShowControls: () {},
            onSeekSeconds: (_) => actions++,
            onAdjustVolume: (_) => actions++,
            onToggleMute: () => actions++,
            onToggleFullscreen: () => actions++,
            onExitFullscreen: () => actions++,
            isFullscreen: true,
            child: Column(
              children: [
                const TextField(),
                TextButton(onPressed: () => buttons++, child: const Text('选集')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    for (final k in [
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.keyF,
      LogicalKeyboardKey.keyM,
      LogicalKeyboardKey.arrowLeft,
    ]) {
      await tester.sendKeyEvent(k);
    }
    expect(actions, 0);
    Focus.of(tester.element(find.text('选集'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(buttons, 1);
    expect(actions, 0);
  });
  testWidgets('dialogs keep keys out of background playback', (tester) async {
    var actions = 0;
    late BuildContext page;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            page = context;
            return Scaffold(
              body: DesktopPlayerInput(
                onTogglePlay: () => actions++,
                onShowControls: () {},
                onSeekSeconds: (_) => actions++,
                onAdjustVolume: (_) => actions++,
                onToggleMute: () => actions++,
                onToggleFullscreen: () => actions++,
                onExitFullscreen: () => actions++,
                isFullscreen: true,
                child: const SizedBox.expand(),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    showDialog<void>(
      context: page,
      builder: (_) => const AlertDialog(content: Text('设置')),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(actions, 0);
  });
  testWidgets('mouse hover reveals controls', (tester) async {
    var shows = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DesktopPlayerInput(
            onTogglePlay: () {},
            onShowControls: () => shows++,
            onSeekSeconds: (_) {},
            onAdjustVolume: (_) {},
            onToggleMute: () {},
            onToggleFullscreen: () {},
            onExitFullscreen: () {},
            isFullscreen: false,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    final m = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await m.addPointer(location: Offset.zero);
    await m.moveTo(const Offset(100, 100));
    await tester.pump();
    expect(shows, greaterThan(0));
    await m.removePointer();
  });
}
