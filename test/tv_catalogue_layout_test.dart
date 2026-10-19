import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ecohub_android/common/app_theme.dart';
import 'package:ecohub_android/components/filter_tag_row.dart';
import 'package:ecohub_android/models/film_models.dart';
import 'package:ecohub_android/tv/tv_catalogue_grid.dart';
import 'package:ecohub_android/pages/filter_page.dart';
import 'package:ecohub_android/utils/server_config_manager.dart';

void main() {
  for (final size in [
    const Size(640, 360),
    const Size(960, 446),
    const Size(960, 540),
    const Size(1280, 720),
    const Size(1536, 714),
    const Size(1920, 1080),
  ]) {
    testWidgets('catalogue fits six columns and two whole rows at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 48, child: Text('分类与排序')),
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
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final first = tester.getRect(
        find.byKey(const ValueKey('tv-catalogue-item-0')),
      );
      for (var i = 0; i < 6; i++) {
        final card = tester.getRect(
          find.byKey(ValueKey('tv-catalogue-item-$i')),
        );
        expect(card.top, closeTo(first.top, .1));
        expect(card.right, lessThan(size.width));
      }
      final seventh = tester.getRect(
        find.byKey(const ValueKey('tv-catalogue-item-6')),
      );
      expect(seventh.top, greaterThan(first.bottom));
      final last = tester.getRect(
        find.byKey(const ValueKey('tv-catalogue-item-11')),
      );
      expect(last.bottom, lessThanOrEqualTo(size.height + .1));
      expect(
        tester.getRect(find.text('更新至12集')).bottom,
        lessThanOrEqualTo(size.height),
      );
      FocusScope.of(tester.element(find.byType(TvCatalogueGrid))).nextFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      final secondRow =
          tester
                  .widget<Container>(find.byKey(const ValueKey('tv-poster-7')))
                  .foregroundDecoration
              as BoxDecoration;
      expect(secondRow.border!.top.color, AppTheme.accent);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(0));
      expect(
        tester.getRect(find.byKey(const ValueKey('tv-poster-13'))).bottom,
        lessThanOrEqualTo(size.height),
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'inline compact filters scroll away on remote down and retain source values',
    (tester) async {
      tester.view.physicalSize = const Size(960, 446);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'server_base_url': 'https://example.com/api',
      });
      PackageInfo.setMockInitialValues(
        appName: 'EUB弹幕',
        packageName: 'com.eub.tv.danmaku',
        version: '1.1.3',
        buildNumber: '8',
        buildSignature: '',
      );
      await ServerConfigManager.instance.init();
      final queries = <Map<String, String>>[];
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: const FilterPage(pid: '1'),
            ),
          );
          for (var i = 0; i < 15; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(find.byType(TvCatalogueGrid), findsOneWidget);
          expect(
            tester
                .getSize(find.byKey(const ValueKey('tv-catalogue-toolbar')))
                .height,
            44,
          );
          expect(queries.first['pageSize'], '24');
          expect(find.text('内地剧'), findsOneWidget);
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.text('筛选'), findsNothing);
          final filters = find.byKey(
            const ValueKey('tv-catalogue-filters'),
            skipOffstage: false,
          );
          expect(tester.getSize(filters).height, lessThan(70));
          await tester.tap(find.text('内地剧'));
          await tester.pumpAndSettle();
          expect(queries.last['Category'], '7');
          // Remote down from the final filter row moves into the poster grid.
          Focus.of(tester.element(find.text('最近更新'))).requestFocus();
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
          final viewport = tester.getRect(
            find.byKey(const ValueKey('tv-catalogue-grid')),
          );
          expect(
            tester.getRect(filters).bottom,
            lessThanOrEqualTo(viewport.top + .5),
          );
          expect(
            tester.getRect(find.text('更新至12集')).bottom,
            lessThanOrEqualTo(446),
          );
          final first = tester.getRect(
            find.byKey(const ValueKey('tv-catalogue-item-0')),
          );
          expect(first.top, greaterThanOrEqualTo(viewport.top));
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
          await tester.pumpAndSettle();
          expect(
            tester.getRect(find.text('最近更新')).top,
            greaterThanOrEqualTo(viewport.top),
          );
          final categoryRow = tester
              .widgetList<FilterTagRow>(
                find.byType(FilterTagRow, skipOffstage: false),
              )
              .singleWhere((row) => row.filterKey == 'Category');
          expect(categoryRow.selected, '7');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        },
        () => MockClient((request) async {
          if (!request.url.path.endsWith('/filmClassifySearch')) {
            return http.Response('{"code":0,"data":{}}', 200);
          }
          queries.add(request.url.queryParameters);
          return http.Response(
            jsonEncode({
              'code': 0,
              'data': {
                'title': {'id': 1, 'name': '电视剧'},
                'page': {'total': 24, 'current': 1, 'pageCount': 1},
                'params': request.url.queryParameters.containsKey('Category')
                    ? {'Category': request.url.queryParameters['Category']}
                    : {},
                'search': {
                  'sortList': ['Category', 'Sort'],
                  'titles': {'Category': '类型', 'Sort': '排序'},
                  'tags': {
                    'Category': [
                      {'Name': '全部', 'Value': ''},
                      {'Name': '内地剧', 'Value': '7'},
                    ],
                    'Sort': [
                      {'Name': '最近更新', 'Value': 'update_stamp'},
                      {'Name': '最新上映', 'Value': 'year'},
                    ],
                  },
                },
                'list': List.generate(
                  24,
                  (i) => {
                    'id': i + 1,
                    'name': '影片$i',
                    'remarks': '更新至${i + 1}集',
                  },
                ),
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
    },
  );
}
