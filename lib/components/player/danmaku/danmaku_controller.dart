import 'package:flutter/foundation.dart';

import 'danmaku_api.dart';
import 'danmaku_item.dart';
import 'danmaku_store.dart';

/// 弹幕加载状态
enum DanmakuStatus { idle, loading, ready, empty, error }

/// 弹幕控制器：
/// - 从自建弹幕服务按「剧名 S01E01」匹配拉取弹幕
/// - 用户自己发的弹幕叠加在上面，存本机
class DanmakuController extends ChangeNotifier {
  DanmakuApi? _api;
  bool _closed = false;
  bool _manual = false;
  bool get isManualMatch => _manual;
  String get videoTitle => _title;
  int get videoEpisode => _episode;
  String get videoKey => _videoKey;
  String _videoKey = '';

  bool _enabled = true;
  bool get enabled => _enabled;

  double _opacity = DanmakuStore.defaultOpacity;
  double get opacity => _opacity;
  double _panelOpacity = DanmakuStore.defaultPanelOpacity;
  double get panelOpacity => _panelOpacity;

  Future<void> setOpacity(double value, {bool panel = false}) async {
    if (panel) {
      _panelOpacity = value.clamp(0.35, 1.0);
    } else {
      _opacity = value.clamp(0.1, 1.0);
    }
    _emit();
    await DanmakuStore.saveOpacity(
      panel ? _panelOpacity : _opacity,
      panel: panel,
    );
  }

  double _fontSize = DanmakuStore.defaultFontSize;
  double get fontSize => _fontSize;

  DanmakuStatus _status = DanmakuStatus.idle;
  DanmakuStatus get status => _status;

  int _remoteCount = 0;
  int get remoteCount => _remoteCount;

  List<DanmakuSource> _sources = [];
  List<DanmakuSource> get sources => _sources;
  int _sourceIndex = 0;
  int get sourceIndex => _sourceIndex;
  DanmakuSource? get currentSource => _sources.isEmpty
      ? null
      : _sources[_sourceIndex.clamp(0, _sources.length - 1)];

  double _area = DanmakuStore.defaultArea;
  double get area => _area; // 滚动弹幕占用屏幕高度比例

  double _danmakuSpeed = DanmakuStore.defaultSpeed;
  double get danmakuSpeed => _danmakuSpeed; // 滚动速度倍率

  List<DanmakuItem> _items = [];
  List<DanmakuItem> get items => _items;

  int _loadGen = 0; // 防止换集时的竞态：旧请求的返回直接丢弃

  // 记住上次加载参数，供换接口地址后重载使用
  String _title = '';
  int _episode = 0;
  bool _isSeries = false;

  String get baseUrl => _api?.baseUrl ?? DanmakuApi.defaultBaseUrl;

  void _emit() {
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    _loadGen++;
    super.dispose();
  }

  Future<DanmakuApi> _getApi() async =>
      _api ??= DanmakuApi(await DanmakuApi.loadBaseUrl());

  Future<List<DanmakuAnime>> searchAnime(String keyword) async =>
      (await _getApi()).searchAnime(keyword);

  Future<List<DanmakuSource>> fetchEpisodes(DanmakuAnime anime) async =>
      (await _getApi()).fetchEpisodes(anime);

  Future<void> applyManualSource(
    DanmakuSource source, {
    String? expectedVideoKey,
  }) async {
    if (_closed ||
        (expectedVideoKey != null && expectedVideoKey != _videoKey)) {
      return;
    }
    final gen = ++_loadGen;
    final key = _videoKey;
    _manual = true;
    _sources = [source];
    _sourceIndex = 0;
    _remoteCount = 0;
    _status = DanmakuStatus.loading;
    _emit();
    final api = await _getApi();
    final local = await DanmakuStore.load(key);
    if (gen != _loadGen) return;
    await DanmakuStore.saveManualMatch(key, api.baseUrl, source);
    if (gen != _loadGen) return;
    await _loadSourceComments(0, local, gen);
  }

  Future<void> restoreAutomatic() async {
    await DanmakuStore.clearManualMatch(_videoKey);
    if (_closed) return;
    await _loadRemote(title: _title, episode: _episode, isSeries: _isSeries);
  }

  Future<void> init({
    required String videoUrl,
    required String title,
    required int episode, // 1-based，0 表示电影/未知
    required bool isSeries,
  }) async {
    final initGen = ++_loadGen;
    _manual = false;
    _title = title;
    _episode = episode;
    _isSeries = isSeries;
    _videoKey = DanmakuStore.videoKey(videoUrl);
    _enabled = await DanmakuStore.loadEnabled();
    _opacity = await DanmakuStore.loadOpacity();
    _panelOpacity = await DanmakuStore.loadOpacity(panel: true);
    _fontSize = await DanmakuStore.loadFontSize();
    _area = await DanmakuStore.loadArea();
    _danmakuSpeed = await DanmakuStore.loadSpeed();
    final baseUrl = await DanmakuApi.loadBaseUrl();
    if (_closed || initGen != _loadGen) return;
    _api = DanmakuApi(baseUrl);
    final manual = await DanmakuStore.loadManualMatch(_videoKey, baseUrl);
    if (_closed || initGen != _loadGen) return;
    if (manual != null) {
      await applyManualSource(manual);
      return;
    }
    _emit();
    await _loadRemote(title: title, episode: episode, isSeries: isSeries);
  }

  String _keyword(String title, int episode, bool isSeries) {
    final t = title.trim();
    if (t.isEmpty) return '';
    if (isSeries && episode > 0) {
      final ep = episode.toString().padLeft(2, '0');
      return '$t S01E$ep';
    }
    return t;
  }

  Future<void> _loadRemote({
    required String title,
    required int episode,
    required bool isSeries,
  }) async {
    if (_closed) return;
    _manual = false;
    _remoteCount = 0;
    _sources = [];
    final gen = ++_loadGen;
    final keyword = _keyword(title, episode, isSeries);
    if (keyword.isEmpty || _api == null) {
      _setStatus(DanmakuStatus.idle, []);
      return;
    }
    _status = DanmakuStatus.loading;
    _emit();

    // 先叠加本机弹幕，保证开关/发送即时可用
    final local = await DanmakuStore.load(_videoKey);
    if (gen != _loadGen) return;

    final sources = await _api!.matchSources(keyword);
    if (gen != _loadGen) return; // 已换集，丢弃
    _sources = sources;
    _sourceIndex = 0;
    if (sources.isEmpty) {
      _setStatus(DanmakuStatus.empty, local);
      return;
    }
    await _loadSourceComments(0, local, gen);
  }

  /// 加载指定平台源的弹幕
  Future<void> _loadSourceComments(
    int index,
    List<DanmakuItem> local,
    int gen,
  ) async {
    final sources = _sources;
    if (index < 0 || index >= sources.length || _api == null) return;
    _sourceIndex = index;
    final remote = await _api!.fetchComments(sources[index].episodeId);
    if (gen != _loadGen) return;
    _remoteCount = remote.length;
    final merged = [...remote, ...local]
      ..sort((a, b) => a.timeMs.compareTo(b.timeMs));
    _setStatus(
      merged.isEmpty ? DanmakuStatus.empty : DanmakuStatus.ready,
      merged,
    );
  }

  /// 切换弹幕平台源
  Future<void> selectSource(int index) async {
    if (index < 0 || index >= _sources.length || index == _sourceIndex) return;
    final gen = ++_loadGen;
    _sourceIndex = index;
    _status = DanmakuStatus.loading;
    _emit();
    final local = await DanmakuStore.load(_videoKey);
    if (gen != _loadGen) return;
    await _loadSourceComments(index, local, gen);
  }

  void _setStatus(DanmakuStatus status, List<DanmakuItem> items) {
    _status = status;
    _items = items;
    _emit();
  }

  /// 换集时调用
  Future<void> switchVideo({
    required String videoUrl,
    required String title,
    required int episode,
    required bool isSeries,
  }) async {
    final key = DanmakuStore.videoKey(videoUrl);
    if (key == _videoKey && _status != DanmakuStatus.idle) return;
    _loadGen++; // 作废进行中的旧请求
    await init(
      videoUrl: videoUrl,
      title: title,
      episode: episode,
      isSeries: isSeries,
    );
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    await DanmakuStore.saveEnabled(value);
    _emit();
  }

  Future<void> toggle() => setEnabled(!_enabled);

  Future<void> setFontSize(double value) async {
    final v = value.clamp(DanmakuStore.minFontSize, DanmakuStore.maxFontSize);
    if ((_fontSize - v).abs() < 0.01) return;
    _fontSize = v;
    await DanmakuStore.saveFontSize(v);
    _emit();
  }

  Future<void> setArea(double value) async {
    final v = value.clamp(DanmakuStore.minArea, DanmakuStore.maxArea);
    if ((_area - v).abs() < 0.01) return;
    _area = v;
    await DanmakuStore.saveArea(v);
    _emit();
  }

  Future<void> setDanmakuSpeed(double value) async {
    final v = value.clamp(DanmakuStore.minSpeed, DanmakuStore.maxSpeed);
    if ((_danmakuSpeed - v).abs() < 0.01) return;
    _danmakuSpeed = v;
    await DanmakuStore.saveSpeed(v);
    _emit();
  }

  /// 换弹幕接口地址后重载（用上次的剧集参数）
  Future<void> reload() async {
    final baseUrl = await DanmakuApi.loadBaseUrl();
    _api = DanmakuApi(baseUrl);
    await _loadRemote(title: _title, episode: _episode, isSeries: _isSeries);
  }

  /// 设置弹幕接口地址并立即重载
  Future<void> setBaseUrl(String url) async {
    final u = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (u.isEmpty) return;
    await DanmakuApi.saveBaseUrl(u);
    await reload();
  }

  /// 恢复默认接口地址并重载
  Future<void> resetBaseUrl() async {
    await DanmakuApi.saveBaseUrl(DanmakuApi.defaultBaseUrl);
    await reload();
  }
}
