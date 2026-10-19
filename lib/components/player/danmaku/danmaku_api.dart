import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'danmaku_item.dart';

class DanmakuAnime {
  final int id;
  final String title;
  final String platformName;
  final int episodeCount;
  const DanmakuAnime({
    required this.id,
    required this.title,
    required this.platformName,
    required this.episodeCount,
  });
}

/// 单个弹幕源（同一集在不同平台的弹幕）
class DanmakuSource {
  final int episodeId;
  final int episodeNumber;
  final String platformKey; // 如 qq、bilibili
  final String platformName; // 如 腾讯视频
  final String animeTitle;
  final String episodeLabel; // 如 【qq】 长安的荔枝_01

  const DanmakuSource({
    required this.episodeId,
    this.episodeNumber = 0,
    required this.platformKey,
    required this.platformName,
    required this.episodeLabel,
    this.animeTitle = '',
  });
  Map<String, dynamic> toJson() => {
    'episodeId': episodeId,
    'episodeNumber': episodeNumber,
    'platformKey': platformKey,
    'platformName': platformName,
    'animeTitle': animeTitle,
    'episodeLabel': episodeLabel,
  };
  factory DanmakuSource.fromJson(Map<String, dynamic> json) => DanmakuSource(
    episodeId: (json['episodeId'] as num).toInt(),
    episodeNumber: (json['episodeNumber'] as num?)?.toInt() ?? 0,
    platformKey: json['platformKey'] as String,
    platformName: json['platformName'] as String,
    animeTitle: json['animeTitle'] as String? ?? '',
    episodeLabel: json['episodeLabel'] as String? ?? '',
  );
}

/// 弹幕 API 客户端（弹弹play 兼容协议，参考 danmu_api 项目）。
/// 默认指向用户自建的弹幕服务，可在设置里修改。
class DanmakuApi {
  static const String defaultBaseUrl = 'https://danmu.cynn.top/cynnsq';
  static const String _prefKey = 'danmaku_base_url';

  /// 平台键名 → 中文名（对应 danmu_api 的 source key / logName）
  static const Map<String, String> platformNames = {
    'tencent': '腾讯视频',
    'qq': '腾讯视频',
    'iqiyi': '爱奇艺',
    'qiyi': '爱奇艺',
    'youku': '优酷',
    'mango': '芒果TV',
    'imgo': '芒果TV',
    'bilibili': '哔哩哔哩',
    'bilibili1': '哔哩哔哩',
    'migu': '咪咕视频',
    'sohu': '搜狐视频',
    'leshi': '乐视视频',
    'xigua': '西瓜视频',
    'ixigua': '西瓜视频',
    'douyin': '抖音',
    'baha': '巴哈姆特',
    'bahamut': '巴哈姆特',
    'dandan': '弹弹play',
    'dandanplay': '弹弹play',
    'renren': '人人视频',
    'hanjutv': '韩剧TV',
    '360': '360影视',
    '360kan': '360影视',
    'kan360': '360影视',
    'aiyifan': '爱壹帆',
    'hongguo': '红果短剧',
    'nipp': 'Nipaplay',
    'vod': '在线源',
    'custom': '自定义源',
    'tmdb': 'TMDB',
    'douban': '豆瓣',
  };

  final String baseUrl;

  DanmakuApi(this.baseUrl);

  static String _norm(String url) => url.trim().replaceAll(RegExp(r'/+$'), '');

  static Future<String> loadBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_prefKey);
      if (v != null && v.trim().isNotEmpty) return _norm(v);
    } catch (_) {}
    return defaultBaseUrl;
  }

  static String normalizeBaseUrl(String value) {
    final url = _norm(value);
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.hasQuery ||
        uri.hasFragment ||
        RegExp(r'\s').hasMatch(url)) {
      throw const FormatException('请输入完整的 HTTP 或 HTTPS 接口基础地址，不含查询参数');
    }
    return url;
  }

  static Future<void> saveBaseUrl(String url) async {
    final normalized = normalizeBaseUrl(url);
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_prefKey, normalized)) {
      throw StateError('保存失败，请重试');
    }
  }

  /// Match supplies a preferred source; search/episodes supplies other platforms.
  /// Run independently so a server without the search endpoint still works.
  Future<List<DanmakuSource>> matchSources(String keyword) async {
    final ep = RegExp(
      r'^(.*?)\s+S\d+E(\d+)$',
      caseSensitive: false,
    ).firstMatch(keyword);
    final title = ep?.group(1)?.trim() ?? keyword.trim();
    final episode = ep == null ? 'movie' : int.parse(ep.group(2)!).toString();
    final results = await Future.wait([
      _autoMatchSources(keyword),
      _searchSources(title, episode),
    ]);
    final preferred = results[0];
    final titleKey = _canonicalTitle(title);
    final matchingTitles = {
      titleKey,
      ...preferred.map((s) => _canonicalTitle(s.animeTitle)),
    };
    final seenIds = <int>{};
    final seenPlatforms = <String>{};
    final all = <DanmakuSource>[];
    for (final source in [
      ...preferred,
      ...results[1].where(
        (s) => matchingTitles.contains(_canonicalTitle(s.animeTitle)),
      ),
    ]) {
      final platform = source.platformKey == 'unknown'
          ? 'unknown_${source.episodeId}'
          : source.platformName;
      if (!seenIds.add(source.episodeId) || !seenPlatforms.add(platform)) {
        continue;
      }
      all.add(source);
    }
    return all;
  }

  static String _canonicalTitle(String title) => title
      .replaceAll(RegExp(r'from\s+[a-z0-9]+', caseSensitive: false), '')
      .replaceAll(RegExp(r'【[^】]*】|\(\d{4}\)|（\d{4}）'), '')
      .replaceAll(RegExp(r'[\s·:：_\-]'), '')
      .toLowerCase();

  Future<List<DanmakuSource>> _searchSources(
    String title,
    String episode,
  ) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/api/v2/search/episodes',
      ).replace(queryParameters: {'anime': title, 'episode': episode});
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] != true) return [];
      final sources = <DanmakuSource>[];
      for (final anime in (data['animes'] as List? ?? const [])) {
        if (anime is! Map) continue;
        final animeTitle = anime['animeTitle'] as String? ?? '';
        for (final ep in (anime['episodes'] as List? ?? const [])) {
          if (ep is! Map) continue;
          final id = int.tryParse('${ep['episodeId']}') ?? 0;
          if (id <= 0) continue;
          final label = ep['episodeTitle'] as String? ?? '';
          final key = _platformKey(label, animeTitle);
          sources.add(
            DanmakuSource(
              episodeId: id,
              platformKey: key,
              platformName: platformNames[key] ?? key.toUpperCase(),
              episodeLabel: label.isEmpty ? animeTitle : label,
              animeTitle: animeTitle,
            ),
          );
        }
      }
      return sources;
    } catch (_) {
      return [];
    }
  }

  /// 按关键词匹配剧集，返回所有平台的源（同一集在不同平台各一条）。
  /// keyword 形如 "长安的荔枝 S01E01"，服务端会自动解析标题/季/集。
  Future<List<DanmakuSource>> _autoMatchSources(String keyword) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$baseUrl/api/v2/match'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'fileName': keyword}),
          )
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) return [];
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['success'] != true || data['isMatched'] != true) return [];
      final matches = data['matches'] as List<dynamic>?;
      if (matches == null || matches.isEmpty) return [];
      final sources = <DanmakuSource>[];
      for (final m in matches) {
        final map = m as Map<String, dynamic>;
        final epId = map['episodeId'];
        final id = epId is int ? epId : (epId is num ? epId.toInt() : 0);
        if (id <= 0) continue;
        final epTitle = (map['episodeTitle'] as String?) ?? '';
        final animeTitle = (map['animeTitle'] as String?) ?? '';
        final key = _platformKey(epTitle, animeTitle);
        sources.add(
          DanmakuSource(
            episodeId: id,
            platformKey: key,
            platformName: platformNames[key] ?? key.toUpperCase(),
            episodeLabel: epTitle.isNotEmpty ? epTitle : animeTitle,
            animeTitle: animeTitle,
          ),
        );
      }
      return sources;
    } catch (_) {
      return [];
    }
  }

  /// 按关键词匹配剧集，返回第一个平台的 episodeId（用于取弹幕）。
  Future<int?> matchEpisode(String keyword) async {
    final sources = await matchSources(keyword);
    return sources.isEmpty ? null : sources.first.episodeId;
  }

  /// 从 episodeTitle 的【xx】前缀或 animeTitle 的 from xxx 解析平台键名
  static String _platformKey(String episodeTitle, String animeTitle) {
    final m = RegExp(r'【([^】]+)】').firstMatch(episodeTitle);
    if (m != null) {
      final key = m.group(1)!.trim().toLowerCase();
      if (key.isNotEmpty) return key;
    }
    final f = RegExp(
      r'from\s+([a-z0-9]+)',
      caseSensitive: false,
    ).firstMatch(animeTitle);
    if (f != null) return f.group(1)!.toLowerCase();
    return 'unknown';
  }

  Future<Map<String, dynamic>> _manualGet(Uri uri) async {
    final response = await http.get(uri).timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw Exception('弹幕接口请求失败（HTTP ${response.statusCode}），请稍后重试');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['errorMessage'] ?? '弹幕接口暂时不可用');
    }
    return data;
  }

  Future<List<DanmakuAnime>> searchAnime(String keyword) async {
    if (keyword.trim().isEmpty) return [];
    final data = await _manualGet(
      Uri.parse(
        '$baseUrl/api/v2/search/anime',
      ).replace(queryParameters: {'keyword': keyword.trim()}),
    );
    return (data['animes'] as List? ?? const [])
        .whereType<Map>()
        .where((a) => (int.tryParse('${a['animeId']}') ?? 0) > 0)
        .map((a) {
          final title = a['animeTitle'] as String? ?? '';
          final key = a['source'] as String? ?? _platformKey('', title);
          return DanmakuAnime(
            id: int.parse('${a['animeId']}'),
            title: title,
            platformName: platformNames[key] ?? key.toUpperCase(),
            episodeCount: int.tryParse('${a['episodeCount']}') ?? 0,
          );
        })
        .toList();
  }

  Future<List<DanmakuSource>> fetchEpisodes(DanmakuAnime anime) async {
    final data = await _manualGet(
      Uri.parse('$baseUrl/api/v2/bangumi/${anime.id}'),
    );
    final bangumi = data['bangumi'] as Map? ?? const {};
    final title = bangumi['animeTitle'] as String? ?? anime.title;
    final result = <DanmakuSource>[];
    final episodes = (bangumi['episodes'] as List? ?? const [])
        .whereType<Map>();
    for (final ep in episodes) {
      final id = int.tryParse('${ep['episodeId']}') ?? 0;
      if (id <= 0) continue;
      final label = ep['episodeTitle'] as String? ?? '';
      final key = _platformKey(label, title);
      result.add(
        DanmakuSource(
          episodeId: id,
          episodeNumber:
              int.tryParse('${ep['episodeNumber']}') ?? result.length + 1,
          platformKey: key,
          platformName: platformNames[key] ?? anime.platformName,
          animeTitle: title,
          episodeLabel: label,
        ),
      );
    }
    result.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
    return result;
  }

  /// 取指定剧集的全部弹幕
  Future<List<DanmakuItem>> fetchComments(int episodeId) async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/v2/comment/$episodeId?format=json'))
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) return [];
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final comments = data['comments'] as List<dynamic>?;
      if (comments == null) return [];
      final items = <DanmakuItem>[];
      for (var i = 0; i < comments.length; i++) {
        final item = _parseComment(comments[i] as Map<String, dynamic>, i);
        if (item != null) items.add(item);
      }
      items.sort((a, b) => a.timeMs.compareTo(b.timeMs));
      return items;
    } catch (_) {
      return [];
    }
  }

  /// dandanplay 标准格式：p = "time(秒),mode,color,..."，m = 文本
  /// mode: 1=滚动 4=底部 5=顶部
  DanmakuItem? _parseComment(Map<String, dynamic> c, int index) {
    final text = (c['m'] as String?)?.trim() ?? '';
    if (text.isEmpty) return null;
    final p = (c['p'] as String?) ?? '';
    final parts = p.split(',');
    if (parts.length < 3) return null;
    final timeSec = double.tryParse(parts[0]) ?? 0;
    final mode = int.tryParse(parts[1]) ?? 1;
    final colorDec = int.tryParse(parts[2]) ?? 16777215;
    final type = switch (mode) {
      4 => DanmakuType.bottom,
      5 => DanmakuType.top,
      _ => DanmakuType.scroll,
    };
    return DanmakuItem(
      id: 'api_$index',
      text: text.length > 120 ? text.substring(0, 120) : text,
      timeMs: (timeSec * 1000).toInt(),
      color: 0xFF000000 | (colorDec & 0xFFFFFF),
      type: type,
    );
  }
}
