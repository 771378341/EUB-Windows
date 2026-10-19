import 'package:flutter_test/flutter_test.dart';
import 'package:ecohub_android/models/api_parser.dart';
import 'package:ecohub_android/utils/family_content_policy.dart';

void main() {
  test(
    'category policy accepts regular genres and handles traditional and spaced labels',
    () {
      expect(FamilyContentPolicy.allowsCategory('电视剧'), isTrue);
      for (final label in ['伦理', '伦理片', '倫理片', '伦 理']) {
        expect(FamilyContentPolicy.allowsCategory(label), isFalse);
      }
    },
  );
  test(
    'home removes blocked sections, nested categories and labelled banners',
    () {
      final data = ApiParser.parseHome({
        'banners': [
          {'id': 'a', 'name': 'regular', 'cName': '剧情'},
          {'id': 'b', 'name': 'blocked', 'cName': '伦理片'},
        ],
        'content': [
          {
            'nav': {
              'id': 1,
              'name': '电影',
              'children': [
                {'id': 2, 'name': '伦理'},
                {'id': 3, 'name': '喜剧'},
              ],
            },
            'movies': [],
          },
          {
            'nav': {'id': 2, 'name': '伦理'},
            'movies': [
              {'id': 7, 'name': 'untagged'},
            ],
          },
        ],
      });
      expect(data.banners.map((b) => b.name), ['regular']);
      expect(data.content.map((s) => s.nav.name), ['电影']);
      expect(data.content.first.nav.children.map((c) => c.name), ['喜剧']);
    },
  );
  test(
    'daily categories and mixed film results omit blocked classification metadata',
    () {
      final rows = [
        {'id': 1, 'name': 'ordinary', 'cName': '动漫'},
        {'id': 2, 'name': 'blocked', 'cName': '伦理'},
        {'id': 3, 'name': 'blocked2', 'classTag': '剧情,倫理'},
        {'id': 4, 'name': '伦理学讲座', 'cName': '纪录片'},
      ];
      final data = ApiParser.parseDailyUpdate({
        'categories': [
          {'pid': 1, 'name': '动漫'},
          {'pid': 2, 'name': '伦理'},
        ],
        'list': rows,
      });
      expect(data.categories.map((c) => c.name), ['动漫']);
      expect(data.list.map((m) => m.id), [1, 4]);
      expect(ApiParser.parseSearch({'list': rows}).list.map((m) => m.id), [
        1,
        4,
      ]);
    },
  );
  test(
    'filter names stay aligned with their values and remove blocked preset',
    () {
      final data = ApiParser.parseFilter({
        'title': {'id': 1, 'name': '电影'},
        'params': {'Category': '伦理', 'Area': '中国'},
        'search': {
          'tags': {
            'Category': [
              {'Name': '全部', 'Value': ''},
              {'Name': '伦理', 'Value': '99'},
              {'Name': '喜剧', 'Value': '3'},
            ],
          },
        },
      });
      expect(data.search.tagNames.first, ['全部', '喜剧']);
      expect(data.search.tagValues.first, ['', '3']);
      expect(data.paramKeys, isNot(contains('Category')));
      expect(data.paramKeys, ['Area']);
      expect(data.params, ['中国']);
    },
  );
  test(
    'direct blocked category and blocked playback detail cannot expose its films',
    () {
      final data = ApiParser.parseFilter({
        'title': {'id': 99, 'name': '伦理'},
        'list': [
          {'id': 3, 'name': 'untagged'},
        ],
      });
      expect(data.list, isEmpty);
      expect(
        () => ApiParser.parsePlay({
          'detail': {
            'id': 3,
            'name': 'blocked',
            'descriptor': {'cName': '伦理'},
          },
        }),
        throwsException,
      );
    },
  );
}
