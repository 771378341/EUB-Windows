import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ecohub_android/components/player/danmaku/danmaku_controller.dart';
import 'package:ecohub_android/components/player/danmaku/danmaku_panel.dart';
import 'package:ecohub_android/components/player/danmaku/danmaku_sheet.dart';
import 'package:ecohub_android/components/player/danmaku/danmaku_store.dart';

void main() {
  test(
    'independent opacity settings persist and clamp unreadable extremes',
    () async {
      SharedPreferences.setMockInitialValues({});
      final c = DanmakuController();
      await c.setOpacity(0.6);
      await c.setOpacity(0.72, panel: true);
      expect(await DanmakuStore.loadOpacity(), 0.6);
      expect(await DanmakuStore.loadOpacity(panel: true), 0.72);
      await c.setOpacity(-1, panel: true);
      expect(c.panelOpacity, 0.35);
      expect(c.opacity, 0.6);
      c.dispose();
    },
  );

  for (final size in [const Size(800, 360), const Size(360, 800)]) {
    testWidgets('panel fits $size and searches inside the same surface', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = DanmakuController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => DanmakuSheet.show(context, controller: c),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final panel = find.byKey(const ValueKey('danmaku-panel'));
      final bounds = tester.getRect(panel);
      expect(bounds.width, size.width > size.height ? 368 : size.width);
      expect(bounds.right, size.width);
      expect(find.text('弹幕透明度'), findsOneWidget);
      expect(find.text('面板透明度'), findsOneWidget);
      await c.setOpacity(0.5, panel: true);
      await tester.pump();
      final surface = tester.widget<Material>(
        find.descendant(of: panel, matching: find.byType(Material)).first,
      );
      expect(surface.color!.a, closeTo(0.5, 0.01));
      await tester.tap(find.text('手动搜索弹幕'));
      await tester.pumpAndSettle();
      expect(find.byType(DanmakuPanel), findsOneWidget);
      expect(tester.getRect(panel), bounds);
      expect(
        find.byKey(const ValueKey('danmaku-search-query')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('返回搜索结果'));
      await tester.pumpAndSettle();
      expect(find.text('弹幕透明度'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  }
}
