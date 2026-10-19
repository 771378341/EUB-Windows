import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecohub_android/components/player/danmaku/danmaku_controller.dart';
import 'package:ecohub_android/components/player/danmaku/danmaku_item.dart';
import 'package:ecohub_android/components/player/danmaku/danmaku_layer.dart';

class _Controller extends DanmakuController {
  @override
  DanmakuStatus get status => DanmakuStatus.ready;
  @override
  List<DanmakuItem> get items => const [
    DanmakuItem(id: '1', text: '平滑弹幕测试', timeMs: 0),
  ];
}

class _Canvas implements Canvas {
  final offsets = <Offset>[];
  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) =>
      offsets.add(offset);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets(
    'moves between unchanged samples without rebuilding widgets; pauses and seeks',
    (tester) async {
      final controller = _Controller();
      var playing = true;
      var revision = 0;
      var raw = 0.0;
      final layer = DanmakuLayer(
        controller: controller,
        positionSec: () => raw,
        speed: () => 1,
        isPlaying: () => playing,
        seekRevision: () => revision,
      );
      await tester.pumpWidget(
        MaterialApp(home: SizedBox(width: 600, height: 300, child: layer)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      final finder = find.descendant(
        of: find.byType(DanmakuLayer),
        matching: find.byType(CustomPaint),
      );
      final widgetBefore = tester.widget<CustomPaint>(finder);
      double x() {
        final canvas = _Canvas();
        tester
            .widget<CustomPaint>(finder)
            .painter!
            .paint(canvas, const Size(600, 300));
        return canvas.offsets.single.dx;
      }

      final first = x();
      await tester.pump(const Duration(milliseconds: 16));
      expect(x(), lessThan(first));
      expect(
        identical(tester.widget<CustomPaint>(finder), widgetBefore),
        isTrue,
      );
      playing = false;
      final paused = x();
      await tester.pump(const Duration(milliseconds: 100));
      expect(x(), paused);
      revision++;
      raw = 300;
      await tester.pump(const Duration(milliseconds: 16));
      final canvas = _Canvas();
      tester
          .widget<CustomPaint>(finder)
          .painter!
          .paint(canvas, const Size(600, 300));
      expect(canvas.offsets, isEmpty);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
