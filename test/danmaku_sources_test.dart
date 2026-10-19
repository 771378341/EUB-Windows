import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ecohub_android/components/player/danmaku/danmaku_controller.dart';
import 'package:ecohub_android/components/player/danmaku/danmaku_api.dart';

void main() {
  Map<String, dynamic> source(int id, String platform, {String season = ''}) =>
      {
        'animeTitle': '庆余年$season(2019)【电视剧】from 360',
        'episodes': [
          {'episodeId': id, 'episodeTitle': '【$platform】 第1集'},
        ],
      };
  final preferred = {
    'success': true,
    'isMatched': true,
    'matches': [
      {
        'episodeId': 1,
        'animeTitle': '庆余年(2019)【电视剧】from tencent',
        'episodeTitle': '【qq】 庆余年_01',
      },
    ],
  };

  test(
    'discovers Tencent and iQiyi, deduplicates platforms and rejects other seasons',
    () async {
      final api = DanmakuApi('https://example.com');
      final sources = await http.runWithClient(
        () => api.matchSources('庆余年 S01E01'),
        () => MockClient((request) async {
          if (request.url.path.endsWith('/match')) {
            return http.Response(
              jsonEncode(preferred),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          expect(request.url.queryParameters, {'anime': '庆余年', 'episode': '1'});
          return http.Response(
            jsonEncode({
              'success': true,
              'animes': [
                source(2, 'qq'),
                source(3, 'qiyi', season: '第二季'),
                source(4, 'qiyi'),
                source(4, 'qiyi'),
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      expect(sources.map((s) => s.platformName), ['腾讯视频', '爱奇艺']);
      expect(sources.map((s) => s.episodeId), [1, 4]);
    },
  );
  test(
    'keeps preferred matching source if search endpoint is unavailable',
    () async {
      final api = DanmakuApi('https://example.com');
      final sources = await http.runWithClient(
        () => api.matchSources('庆余年 S01E01'),
        () => MockClient(
          (request) async => request.url.path.endsWith('/match')
              ? http.Response(
                  jsonEncode(preferred),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                )
              : http.Response('not found', 404),
        ),
      );
      expect(sources.single.episodeId, 1);
    },
  );
  test('can discover sources when automatic match fails', () async {
    final api = DanmakuApi('https://example.com');
    final sources = await http.runWithClient(
      () => api.matchSources('庆余年 S01E01'),
      () => MockClient(
        (request) async => request.url.path.endsWith('/match')
            ? http.Response('error', 500)
            : http.Response(
                jsonEncode({
                  'success': true,
                  'animes': [source(4, 'qiyi')],
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              ),
      ),
    );
    expect(sources.single.platformName, '爱奇艺');
  });
  test('switching platform loads the selected episode comments', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = DanmakuController();
    await http.runWithClient(
      () async {
        await controller.init(
          videoUrl: 'https://example.com/video',
          title: '庆余年',
          episode: 1,
          isSeries: true,
        );
        expect(controller.sources.map((s) => s.platformName), ['腾讯视频', '爱奇艺']);
        expect(controller.items.single.text, '腾讯弹幕');
        await controller.selectSource(1);
        expect(controller.currentSource!.platformName, '爱奇艺');
        expect(controller.items.single.text, '爱奇艺弹幕');
      },
      () => MockClient((request) async {
        final Object data;
        if (request.url.path.endsWith('/match')) {
          data = preferred;
        } else if (request.url.path.endsWith('/search/episodes')) {
          data = {
            'success': true,
            'animes': [source(4, 'qiyi')],
          };
        } else {
          data = {
            'comments': [
              {
                'p': '1,1,16777215',
                'm': request.url.path.endsWith('/4') ? '爱奇艺弹幕' : '腾讯弹幕',
              },
            ],
          };
        }
        return http.Response(
          jsonEncode(data),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    controller.dispose();
  });
}
