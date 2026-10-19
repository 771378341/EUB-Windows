import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecohub_android/components/player/player_skin_view.dart';

void main() {
  testWidgets(
    'episode controls sit either side of pause and invoke the matching callback',
    (tester) async {
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var prev = 0, next = 0, pause = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerSkinView(
              isFull: true,
              showHud: true,
              isPlaying: true,
              isReady: true,
              isBuffering: false,
              title: 'title',
              currentPosition: Duration.zero,
              totalDuration: const Duration(hours: 1),
              hasPrev: true,
              hasNext: true,
              onBack: () {},
              onTogglePlay: () => pause++,
              onToggleFull: () {},
              onToggleMute: () {},
              onSpeed: () {},
              onRetry: () {},
              onPrev: () => prev++,
              onNext: () => next++,
              onSeekBack10: () {},
              onSeekFwd10: () {},
              onSeekTo: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final p = tester.getCenter(find.byTooltip('上一集')),
          c = tester.getCenter(find.byTooltip('暂停')),
          n = tester.getCenter(find.byTooltip('下一集'));
      expect(p.dx, lessThan(c.dx));
      expect(c.dx, lessThan(n.dx));
      expect(p.dy, c.dy);
      expect(n.dy, c.dy);
      expect(p.dy, greaterThan(400));
      expect(find.text('上集'), findsNothing);
      expect(find.text('下集'), findsNothing);
      await tester.tap(find.byTooltip('上一集'));
      await tester.tap(find.byTooltip('暂停'));
      await tester.tap(find.byTooltip('下一集'));
      expect([prev, pause, next], [1, 1, 1]);
      expect(tester.takeException(), isNull);
    },
  );
}
