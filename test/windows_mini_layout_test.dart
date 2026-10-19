import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecohub_android/desktop/app_window.dart';
import 'package:ecohub_android/components/player/player_bars.dart';

void main() {
  for (final size in [const Size(320, 180), const Size(480, 270), const Size(640, 400)]) {
    testWidgets('Desktop controls fit ${size.width} and keep secondary actions',
        (tester) async {
      final original = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppWindow.isMini.value = size.width < 640;
      var selections = 0;
      try {
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: Stack(children: [
          const Positioned(top: 0, left: 0, right: 0, child: PlayerTopBar(
            isFull: true, showHud: true, errorText: '',
            title: '很长的播放标题 · 第1000集',
            onBack: _noop,
          )),
          Positioned(bottom: 0, left: 0, right: 0, child: PlayerBottomBar(
            isReady: true, isOpening: false, showHud: true, errorText: '',
            cinemaHud: true, isFull: true, isPlaying: true, muted: false,
            currentPosition: const Duration(seconds: 5),
            totalDuration: const Duration(minutes: 20),
            currentSpeed: 1, scaleLabel: '适应',
            hasPrev: true, hasNext: true, onPrev: _noop, onNext: _noop,
            onTogglePlay: _noop, onToggleFull: _noop, onToggleMute: _noop,
            onSpeed: _noop, onScale: _noop, onToggleDanmaku: _noop,
            onOpenDanmakuSettings: _noop,
            onOpenEpisodes: () => selections++,
            onSeekTo: _seek,
          )),
        ]))));
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('desktop-pin')), findsOneWidget);
        expect(find.byKey(const ValueKey('desktop-mini')), findsOneWidget);
        expect(find.byTooltip('上一集'), findsOneWidget);
        expect(find.byTooltip('下一集'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('desktop-player-more')));
        await tester.pumpAndSettle();
        expect(find.text('弹幕设置'), findsOneWidget);
        await tester.tap(find.text('选集'));
        await tester.pumpAndSettle();
        expect(selections, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        AppWindow.isMini.value = false;
        debugDefaultTargetPlatformOverride = original;
      }
    });
  }
}
void _noop() {}
void _seek(Duration _) {}
