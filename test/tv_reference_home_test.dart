import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecohub_android/common/app_theme.dart';
import 'package:ecohub_android/models/film_models.dart';
import 'package:ecohub_android/tv/tv_home_content.dart';
import 'package:ecohub_android/tv/tv_home_design.dart';

void main() {
  for (final size in [
    const Size(640, 360),
    const Size(960, 540),
    const Size(960, 446),
    const Size(1536, 714),
    const Size(1280, 720),
    const Size(1920, 1080),
  ]) {
    testWidgets(
      'reference home has three complete highlights and six complete posters at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final films = List.generate(
          10,
          (i) => MovieBasicInfo(
            id: i + 1,
            name: '影片$i',
            remarks: '更新至24集',
            dbScore: i == 0 ? '9.2' : '',
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              appBar: TvHomeNavigation(
                width: size.width,
                categories: [
                  for (var i = 0; i < 7; i++)
                    CategoryItem(
                      id: i,
                      pid: 0,
                      name: ['电视剧', '电影', '动漫', '综艺', '体育', '短剧', '纪录片'][i],
                    ),
                ],
                selectedTab: 0,
                onSelectTab: (_) {},
                onCategory: (_) {},
                onSearch: () {},
                onHistory: () {},
              ),
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    TvHomeHighlights(
                      banners: [
                        BannerItem(id: 'a', mid: 99, name: '推荐一'),
                        BannerItem(id: 'b', mid: 98, name: '推荐二'),
                        BannerItem(id: 'c', mid: 97, name: '推荐三'),
                      ],
                    ),
                    TvHomeFilmRow(title: '热门电视剧', films: films, onMore: () {}),
                    TvHomeFilmRow(title: '精选电影', films: films, onMore: () {}),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final first = tester.getRect(
          find.byKey(const ValueKey('tv-highlight-0')),
        );
        final second = tester.getRect(
          find.byKey(const ValueKey('tv-highlight-1')),
        );
        final third = tester.getRect(
          find.byKey(const ValueKey('tv-highlight-2')),
        );
        expect(first.width, closeTo(second.width, .1));
        expect(first.width, closeTo(third.width, .1));
        expect(third.right, lessThan(size.width));
        expect(find.text('我的').hitTestable(), findsOneWidget);
        expect(tester.getRect(find.text('我的')).right, lessThan(size.width));
        expect(first.height, lessThan(size.height * .35));
        final cards = find.descendant(
          of: find.byType(TvHomeFilmRow).first,
          matching: find.byType(TvHomePoster),
        );
        expect(cards, findsAtLeastNWidgets(6));
        final sixth = tester.getRect(cards.at(5));
        expect(sixth.right, lessThan(size.width));
        expect(sixth.bottom, lessThan(size.height));
        expect(tester.getTopLeft(find.text('精选电影')).dy, lessThan(size.height));
        expect(find.text('9.2'), findsAtLeastNWidgets(1));
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'many categories keep My visible and excess categories remain reachable',
    (tester) async {
      tester.view.physicalSize = const Size(960, 446);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int selected = -1;
      int category = -1;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            appBar: TvHomeNavigation(
              width: 960,
              categories: List.generate(
                20,
                (i) => CategoryItem(id: i, pid: 0, name: '完整分类$i'),
              ),
              selectedTab: 0,
              onSelectTab: (i) => selected = i,
              onCategory: (c) => category = c.id,
              onSearch: () {},
              onHistory: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('我的').hitTestable(), findsOneWidget);
      await tester.tap(find.text('我的'));
      expect(selected, 2);
      await tester.tap(find.byTooltip('更多分类'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('完整分类19'),
        150,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('完整分类19'));
      await tester.pumpAndSettle();
      expect(category, 19);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('remote reaches fourth recommendation and opens its own id', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 446);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (_) =>
              Scaffold(body: Text('play ${(settings.arguments as Map)['id']}')),
        ),
        home: Scaffold(
          body: TvHomeHighlights(
            banners: List.generate(
              8,
              (i) => BannerItem(id: 'item$i', mid: i + 10, name: '推荐$i'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    FocusScope.of(tester.element(find.byType(TvHomeHighlights))).nextFocus();
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
    }
    expect(
      tester.getRect(find.byKey(const ValueKey('tv-highlight-3'))).right,
      lessThanOrEqualTo(960),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('play 13'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'remote traverses past six posters, reveals focus, and opens the focused film',
    (tester) async {
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          onGenerateRoute: (settings) => MaterialPageRoute(
            builder: (_) => Scaffold(
              body: Text('play ${(settings.arguments as Map)['id']}'),
            ),
          ),
          home: Scaffold(
            body: TvHomeFilmRow(
              title: '热门电视剧',
              films: List.generate(
                10,
                (i) => MovieBasicInfo(id: i + 1, name: '电影$i'),
              ),
              onMore: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scope = FocusScope.of(tester.element(find.byType(TvHomeFilmRow)));
      scope.nextFocus(); // 查看全部
      await tester.pumpAndSettle();
      scope.nextFocus(); // first film
      await tester.pumpAndSettle();
      for (var i = 0; i < 6; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
      final focused = find.byKey(const ValueKey('tv-poster-7'));
      expect(tester.getRect(focused).right, lessThanOrEqualTo(960));
      final decoration =
          tester.widget<Container>(focused).foregroundDecoration
              as BoxDecoration;
      expect(decoration.border!.top.color, AppTheme.accent);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('play 7'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
