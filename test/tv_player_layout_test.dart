import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecohub_android/common/app_theme.dart';
import 'package:ecohub_android/components/player/player_skin_view.dart';

void main() {
  for (final width in [560.0, 960.0, 1280.0]) {
    testWidgets('TV player controls fit width $width', (tester) async {
      tester.view.physicalSize = Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SizedBox(
              width: width,
              height: 540,
              child: PlayerSkinView(
                isFull: true,
                showHud: true,
                title: 'EUB弹幕',
                isPlaying: true,
                isReady: true,
                isBuffering: false,
                currentPosition: const Duration(minutes: 30),
                totalDuration: const Duration(hours: 2),
                onBack: () {},
                onTogglePlay: () {},
                onToggleFull: () {},
                onToggleMute: () {},
                onSpeed: () {},
                onScale: () {},
                onRetry: () {},
                onPrev: () {},
                onNext: () {},
                hasPrev: true,
                hasNext: true,
                onSeekBack10: () {},
                onSeekFwd10: () {},
                onSeekTo: (_) {},
                onToggleDanmaku: () {},
                onOpenDanmakuSettings: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('弹幕设置'), findsOneWidget);
    });
  }
}
