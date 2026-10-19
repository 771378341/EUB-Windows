import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ecohub_android/common/app_theme.dart';
import 'package:ecohub_android/components/player/danmaku/danmaku_api.dart';
import 'package:ecohub_android/components/player/danmaku/danmaku_controller.dart';
import 'package:ecohub_android/components/player/danmaku/danmaku_sheet.dart';

const anime = DanmakuAnime(
  id: 8880868,
  title: '把黑夜点燃(2026)【电视剧】from iqiyi',
  platformName: '爱奇艺',
  episodeCount: 3,
);
final episodes = List.generate(
  3,
  (i) => DanmakuSource(
    episodeId: 32851483 + i,
    episodeNumber: i + 1,
    platformKey: 'qiyi',
    platformName: '爱奇艺',
    animeTitle: anime.title,
    episodeLabel: '【qiyi】 把黑夜点燃第${i + 1}集',
  ),
);
http.Response response(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class _Controller extends DanmakuController {
  DanmakuSource? selected;
  @override
  String get videoTitle => '把黑夜点燃';
  @override
  int get videoEpisode => 2;
  @override
  Future<List<DanmakuAnime>> searchAnime(String keyword) async => [anime];
  @override
  Future<List<DanmakuSource>> fetchEpisodes(DanmakuAnime anime) async =>
      episodes;
  @override
  Future<void> applyManualSource(
    DanmakuSource source, {
    String? expectedVideoKey,
  }) async {
    selected = source;
  }
}

void main() {
  test(
    'manual debug API path works when auto matching misses; saves exact episode',
    () async {
      SharedPreferences.setMockInitialValues({});
      final commentRequests = <String>[];
      await http.runWithClient(
        () async {
          final c = DanmakuController();
          await c.init(
            videoUrl: 'https://example.com/ep2',
            title: '采集站标题不同',
            episode: 2,
            isSeries: true,
          );
          expect(c.status, DanmakuStatus.empty);
          final animes = await c.searchAnime('把黑夜点燃');
          expect(animes.single.platformName, '爱奇艺');
          final found = await c.fetchEpisodes(animes.single);
          expect(found.map((e) => e.episodeNumber), [1, 2, 3]);
          await c.applyManualSource(found[1]);
          expect(c.isManualMatch, isTrue);
          expect(c.items.single.text, '第二集弹幕');
          expect(commentRequests, ['/cynnsq/api/v2/comment/32851484']);
          c.dispose();
          final reopened = DanmakuController();
          await reopened.init(
            videoUrl: 'https://example.com/ep2',
            title: '旧标题',
            episode: 2,
            isSeries: true,
          );
          expect(reopened.currentSource!.episodeId, 32851484);
          expect(reopened.isManualMatch, isTrue);
          await reopened.restoreAutomatic();
          expect(reopened.isManualMatch, isFalse);
          expect(reopened.status, DanmakuStatus.empty);
          reopened.dispose();
        },
        () => MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/search/anime')) {
            expect(request.url.queryParameters['keyword'], '把黑夜点燃');
            return response({
              'success': true,
              'animes': [
                {
                  'animeId': anime.id,
                  'animeTitle': anime.title,
                  'source': 'iqiyi',
                  'episodeCount': 3,
                },
              ],
            });
          }
          if (path.endsWith('/bangumi/8880868')) {
            return response({
              'success': true,
              'bangumi': {
                'animeTitle': anime.title,
                'episodes': episodes
                    .map(
                      (e) => {
                        'episodeId': e.episodeId,
                        'episodeNumber': '${e.episodeNumber}',
                        'episodeTitle': e.episodeLabel,
                      },
                    )
                    .toList(),
              },
            });
          }
          if (path.contains('/comment/')) {
            commentRequests.add(path);
            return response({
              'comments': [
                {'p': '1,1,16777215', 'm': '第二集弹幕'},
              ],
            });
          }
          return response({
            'success': true,
            'isMatched': false,
            'matches': [],
            'animes': [],
          });
        }),
      );
    },
  );
  test(
    'manual network failures remain distinguishable from zero results',
    () async {
      await http.runWithClient(() async {
        await expectLater(
          DanmakuApi('https://example.com').searchAnime('把黑夜点燃'),
          throwsException,
        );
      }, () => MockClient((_) async => http.Response('unavailable', 503)));
    },
  );
  testWidgets('settings removes preview and picker selects the exact episode', (
    tester,
  ) async {
    final c = _Controller();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: DanmakuSheet(controller: c)),
      ),
    );
    expect(find.text('弹幕效果预览'), findsNothing);
    expect(find.text('预览'), findsNothing);
    await tester.tap(find.text('手动搜索弹幕'));
    await tester.pumpAndSettle();
    expect(find.text('把黑夜点燃(2026)'), findsOneWidget);
    expect(find.text('爱奇艺 · 3 集'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('manual-anime-8880868')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('manual-episode-32851484')));
    await tester.pumpAndSettle();
    expect(c.selected!.episodeId, 32851484);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
