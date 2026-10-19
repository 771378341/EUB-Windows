import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'danmaku_item.dart';
import 'danmaku_api.dart';

/// 弹幕本地存储：按视频 key 存 JSON 列表
class DanmakuStore {
  static const String _prefix = 'danmaku_v1_';
  static const String keyEnabled = 'danmaku_enabled';
  static const String keyFontSize = 'danmaku_font_size';
  static const String keyArea = 'danmaku_area';
  static const String keySpeed = 'danmaku_speed';
  static const keyOpacity = 'danmaku_opacity';
  static const keyPanelOpacity = 'danmaku_panel_opacity';
  static const double defaultOpacity = 1.0;
  static const double defaultPanelOpacity = 0.88;
  static const int maxPerVideo = 500;
  static const double defaultFontSize = 17;
  static const double minFontSize = 12;
  static const double maxFontSize = 32;
  static const double defaultArea = 0.55;
  static const double minArea = 0.25;
  static const double maxArea = 1.0;
  static const double defaultSpeed = 1.0;
  static const double minSpeed = 0.5;
  static const double maxSpeed = 2.0;

  /// FNV-1a 64 位哈希，把不定长的 videoUrl 变成稳定的短 key
  /// （Dart 的 String.hashCode 跨运行不稳定，不能用）
  static String videoKey(String videoUrl) {
    var hash = 0xcbf29ce484222325;
    for (var i = 0; i < videoUrl.length; i++) {
      hash ^= videoUrl.codeUnitAt(i);
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  static String _storeKey(String videoKey) => '$_prefix$videoKey';

  static Future<List<DanmakuItem>> load(String videoKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storeKey(videoKey));
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(DanmakuItem.fromJson)
          .where((e) => e.text.isNotEmpty)
          .toList()
        ..sort((a, b) => a.timeMs.compareTo(b.timeMs));
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(String videoKey, List<DanmakuItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trimmed = items.length > maxPerVideo
          ? items.sublist(items.length - maxPerVideo)
          : items;
      await prefs.setString(
        _storeKey(videoKey),
        jsonEncode(trimmed.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  static Future<DanmakuSource?> loadManualMatch(
    String key,
    String baseUrl,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('danmaku_match_$key');
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['baseUrl'] != baseUrl) return null;
      return DanmakuSource.fromJson(data['source'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveManualMatch(
    String key,
    String baseUrl,
    DanmakuSource source,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'danmaku_match_$key',
      jsonEncode({'baseUrl': baseUrl, 'source': source.toJson()}),
    );
  }

  static Future<void> clearManualMatch(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('danmaku_match_$key');
  }

  static Future<bool> loadEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(keyEnabled) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> saveEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyEnabled, enabled);
    } catch (_) {}
  }

  static Future<double> loadFontSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getDouble(keyFontSize);
      if (v == null) return defaultFontSize;
      return v.clamp(minFontSize, maxFontSize);
    } catch (_) {
      return defaultFontSize;
    }
  }

  static Future<void> saveFontSize(double size) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(keyFontSize, size.clamp(minFontSize, maxFontSize));
    } catch (_) {}
  }

  static Future<double> loadArea() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getDouble(keyArea);
      if (v == null) return defaultArea;
      return v.clamp(minArea, maxArea);
    } catch (_) {
      return defaultArea;
    }
  }

  static Future<void> saveArea(double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(keyArea, value.clamp(minArea, maxArea));
    } catch (_) {}
  }

  static Future<double> loadSpeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getDouble(keySpeed);
      if (v == null) return defaultSpeed;
      return v.clamp(minSpeed, maxSpeed);
    } catch (_) {
      return defaultSpeed;
    }
  }

  static Future<void> saveSpeed(double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(keySpeed, value.clamp(minSpeed, maxSpeed));
    } catch (_) {}
  }

  static Future<double> loadOpacity({bool panel = false}) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getDouble(panel ? keyPanelOpacity : keyOpacity) ??
            (panel ? defaultPanelOpacity : defaultOpacity))
        .clamp(panel ? 0.35 : 0.1, 1.0);
  }

  static Future<void> saveOpacity(double value, {bool panel = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(
      panel ? keyPanelOpacity : keyOpacity,
      value.clamp(panel ? 0.35 : 0.1, 1.0),
    );
  }
}
