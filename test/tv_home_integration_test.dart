import 'dart:convert';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ecohub_android/common/app_theme.dart';
import 'package:ecohub_android/pages/main_scaffold_page.dart';
import 'package:ecohub_android/tv/tv_home_content.dart';
import 'package:ecohub_android/tv/tv_home_design.dart';
import 'package:ecohub_android/utils/server_config_manager.dart';

void main() {
  testWidgets(
    'loaded TV home has one header and visible film cards below the hero',
    (tester) async {
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      PackageInfo.setMockInitialValues(
        appName: 'EUB弹幕',
        packageName: 'com.eub.tv.danmaku',
        version: '1.0.1',
        buildNumber: '2',
        buildSignature: '',
      );
      SharedPreferences.setMockInitialValues({
        'server_base_url': 'https://example.com/api',
      });
      await ServerConfigManager.instance.init();
      final home = {
        'banners': [
          {
            'id': '1',
            'mid': 1,
            'name': 'Featured movie',
            'blurb': 'synopsis ' * 100,
          },
        ],
        'content': [
          {
            'nav': {'id': 1, 'pid': 0, 'name': '电视剧', 'show': true},
            'movies': [
              for (var i = 0; i < 6; i++)
                {'id': i + 1, 'name': 'Movie $i', 'year': '2026'},
            ],
            'hot': [],
          },
        ],
      };
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: const MainScaffoldPage(),
            ),
          );
          for (var i = 0; i < 20; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(tester.takeException(), isNull);
          expect(find.byType(TvHomeNavigation), findsOneWidget);
          expect(find.text('EUB弹幕'), findsOneWidget);
          expect(find.byTooltip('搜索影片'), findsOneWidget);
          expect(find.byType(TvHomeHighlights), findsOneWidget);
          expect(find.byKey(const ValueKey('tv-highlight-0')), findsOneWidget);
          expect(
            tester.getTopLeft(find.byType(TvHomePoster).first).dy,
            lessThan(540),
          );
          final appbar = find.byType(TvHomeNavigation);
          expect(
            find.descendant(of: appbar, matching: find.text('电视剧')),
            findsOneWidget,
          );
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        },
        () => MockClient((request) async {
          return http.Response(
            jsonEncode({
              'code': 0,
              'msg': 'ok',
              'data': request.url.path.endsWith('/index')
                  ? home
                  : {'siteName': 'EUB弹幕', 'state': true},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
    },
  );
}
