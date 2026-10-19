import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecohub_android/common/app_theme.dart';
import 'package:ecohub_android/models/film_models.dart';
import 'package:ecohub_android/tv/tv_episode_sheet.dart';

void main() {
  for (final size in [
    const Size(640, 360),
    const Size(960, 446),
    const Size(1536, 714),
    const Size(1920, 1080),
  ]) {
    testWidgets(
      'sources and complete episode buttons remain visible at $size with safe inset',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(bottom: 24);
        tester.view.viewPadding = const FakeViewPadding(bottom: 24);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                padding: const EdgeInsets.only(bottom: 24),
              ),
              child: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    child: const Text('open'),
                    onPressed: () => TvEpisodeSheet.show(
                      context,
                      title: '醉梦',
                      sources: List.generate(
                        18,
                        (i) => PlaySource(
                          id: 'S$i',
                          sourceId: 'S$i',
                          name: '线路$i(SUBO)',
                          linkList: List.generate(
                            4,
                            (j) => MovieUrlInfo(
                              episode: '第${j + 1}集',
                              link: 'https://example.com/$i/$j',
                            ),
                          ),
                        ),
                      ),
                      playingSourceId: 'S17',
                      episodeIndex: 0,
                      onSelect: (_, _) {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final panel = tester.getRect(
          find.byKey(const ValueKey('tv-episode-panel')),
        );
        final strip = tester.getRect(
          find.byKey(const ValueKey('tv-source-strip')),
        );
        final toolbar = tester.getRect(
          find.byKey(const ValueKey('tv-episode-toolbar')),
        );
        final line = tester.getRect(find.text('线路17(SUBO)'));
        expect(line.left, greaterThanOrEqualTo(strip.left));
        expect(line.right, lessThanOrEqualTo(strip.right));
        expect(line.top, greaterThanOrEqualTo(strip.top));
        expect(line.bottom, lessThanOrEqualTo(strip.bottom));
        expect(strip.bottom, lessThanOrEqualTo(toolbar.top));
        for (var i = 0; i < 4; i++) {
          final episode = tester.getRect(find.byKey(ValueKey('tv-episode-$i')));
          expect(episode.top, greaterThanOrEqualTo(toolbar.bottom));
          expect(episode.bottom, lessThanOrEqualTo(panel.bottom - 24));
        }
        for (var i = 0; i < 3; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pumpAndSettle();
        }
        expect(tester.getRect(find.text('线路17(SUBO)')), line);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
