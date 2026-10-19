import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecohub_android/common/app_theme.dart';
import 'package:ecohub_android/models/film_models.dart';
import 'package:ecohub_android/tv/tv_episode_sheet.dart';
import 'package:ecohub_android/tv/tv_controls.dart';
import 'package:ecohub_android/components/home_banner.dart';

PlaySource source(String id, int count) => PlaySource(
  id: id,
  sourceId: id,
  name: id,
  linkList: List.generate(
    count,
    (i) => MovieUrlInfo(
      episode: '第${i + 1}集',
      link: 'https://example.com/$id/$i.mp4',
    ),
  ),
);

void main() {
  for (final size in [
    const Size(640, 360),
    const Size(960, 540),
    const Size(1280, 720),
  ]) {
    testWidgets('TV hero fits and leaves space for film rows at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            appBar: AppBar(title: const Text('EUB弹幕')),
            body: Column(
              children: [
                HomeBanner(
                  tvLayout: true,
                  banners: [
                    BannerItem(
                      id: '1',
                      mid: 1,
                      name: 'TV test movie',
                      year: '2026',
                      cName: '电视剧',
                      blurb: 'long synopsis ' * 50,
                    ),
                  ],
                ),
                const Text('影片列表'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(find.text('影片列表')).dy,
        lessThan(size.height * 0.7),
      );
      expect(find.text('EUB弹幕'), findsOneWidget);
    });
  }

  testWidgets('down opens episodes instead of moving into a tablet sidebar', (
    tester,
  ) async {
    var episodes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvRemotePlayer(
            onTogglePlay: () {},
            onSeekSeconds: (_) {},
            onShowControls: () {},
            onSettings: () {},
            onOpenEpisodes: () => episodes++,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(episodes, 1);
  });

  testWidgets(
    'episodes cover only the bottom and confirm selects the focused episode',
    (tester) async {
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? selected;
      int? selectedIndex;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => TvEpisodeSheet.show(
                  context,
                  title: 'Test',
                  sources: [source('A', 220), source('B', 10)],
                  playingSourceId: 'A',
                  episodeIndex: 104,
                  onSelect: (s, i) {
                    selected = s;
                    selectedIndex = i;
                  },
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final bounds = tester.getRect(
        find.byKey(const ValueKey('tv-episode-panel')),
      );
      expect(bounds.bottom, 540);
      expect(bounds.top, greaterThan(270));
      expect(bounds.width, 960);
      expect(bounds.height, lessThanOrEqualTo(190));
      final episodeSize = tester.getSize(
        find.byKey(const ValueKey('tv-episode-104')),
      );
      expect(episodeSize.width, lessThanOrEqualTo(90));
      expect(episodeSize.height, lessThanOrEqualTo(44));
      expect(find.byKey(const ValueKey('tv-episode-104')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, 'A');
      expect(selectedIndex, 105);
      expect(find.byKey(const ValueKey('tv-episode-panel')), findsNothing);
      expect(find.text('open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'source switching in bottom selector loads the chosen source episode',
    (tester) async {
      String? selected;
      int? index;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => TvEpisodeSheet.show(
                  context,
                  title: 'Test',
                  sources: [source('A', 220), source('B', 10)],
                  playingSourceId: 'A',
                  episodeIndex: 104,
                  onSelect: (s, i) {
                    selected = s;
                    index = i;
                  },
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, 'B');
      expect(index, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('back dismisses selection while retaining the playback route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => TvEpisodeSheet.show(
                context,
                title: 'Test',
                sources: [source('A', 3)],
                playingSourceId: 'A',
                episodeIndex: 0,
                onSelect: (_, _) {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tv-episode-panel')), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
