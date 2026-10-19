import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecohub_android/common/app_theme.dart';
import 'package:ecohub_android/components/filter_bar.dart';
import 'package:ecohub_android/models/film_models.dart';
import 'package:ecohub_android/tv/tv_catalogue_grid.dart';
import 'package:ecohub_android/tv/tv_home_design.dart';

void main() {
  for (final size in [
    const Size(640, 360),
    const Size(960, 446),
    const Size(960, 540),
    const Size(1280, 720),
    const Size(1536, 714),
    const Size(1920, 1080),
  ]) {
    testWidgets('remote scrolls compact filters out and back at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      const keys = ['Category', 'Area', 'Year', 'Sort'];
      final selected = <String, String>{
        'Category': '',
        'Area': '',
        'Year': '',
        'Sort': '',
      };
      final m = TvHomeMetrics(size.width);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  SizedBox(height: 44 * m.scale, child: const Text('电视剧')),
                  Expanded(
                    child: TvCatalogueGrid(
                      controller: controller,
                      films: List.generate(
                        24,
                        (i) => MovieBasicInfo(
                          id: i + 1,
                          name: '影片$i',
                          remarks: '更新至${i + 1}集',
                        ),
                      ),
                      filters: FilterBar(
                        key: const ValueKey('inline-filters'),
                        compact: true,
                        keys: keys,
                        titleOf: (k) => k,
                        namesOf: (k) => ['全部$k', '选项$k'],
                        valuesOf: (_) => ['', '1'],
                        selectedOf: (k) => selected[k]!,
                        onPick: (k, v) => selected[k] = v,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final header = find.byKey(
        const ValueKey('inline-filters'),
        skipOffstage: false,
      );
      final viewport = tester.getRect(
        find.byKey(const ValueKey('tv-catalogue-grid')),
      );
      expect(tester.getSize(header).height, closeTo(126 * m.scale, .1));
      expect(tester.getRect(header).top, closeTo(viewport.top, .1));
      Focus.of(tester.element(find.text('全部Sort'))).requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThanOrEqualTo(126 * m.scale - .5));
      expect(
        tester.getRect(header).bottom,
        lessThanOrEqualTo(viewport.top + .5),
      );
      expect(
        tester.getRect(find.text('更新至12集')).bottom,
        lessThanOrEqualTo(viewport.bottom),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('全部Sort')).top,
        greaterThanOrEqualTo(viewport.top - .5),
      );
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
      }
      expect(
        tester.getRect(find.text('全部Category')).top,
        greaterThanOrEqualTo(viewport.top - .5),
      );
      expect(
        tester.getRect(find.text('全部Category')).bottom,
        lessThanOrEqualTo(viewport.bottom),
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('empty results keep inline filters available', (tester) async {
    final c = ScrollController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvCatalogueGrid(
            controller: c,
            films: const [],
            filters: FilterBar(
              compact: true,
              keys: const ['Year'],
              titleOf: (_) => '年份',
              namesOf: (_) => ['全部', '2026'],
              valuesOf: (_) => ['', '2026'],
              selectedOf: (_) => '2026',
              onPick: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('没有符合条件的影片'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
