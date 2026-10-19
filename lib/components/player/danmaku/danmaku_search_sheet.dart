import 'package:flutter/material.dart';
import '../../../common/app_theme.dart';
import 'danmaku_api.dart';
import 'danmaku_controller.dart';
import 'danmaku_panel.dart';

/// Explicit title -> platform/season -> episode selection. No fuzzy auto-pick.
class DanmakuSearchSheet extends StatefulWidget {
  final DanmakuController controller;
  final VoidCallback? onBack;
  final ValueChanged<DanmakuSource>? onSelected;
  const DanmakuSearchSheet({
    super.key,
    required this.controller,
    this.onBack,
    this.onSelected,
  });

  static Future<DanmakuSource?> show(
    BuildContext context,
    DanmakuController controller,
  ) => DanmakuPanel.show<DanmakuSource>(
    context,
    DanmakuPanel(
      controller: controller,
      child: DanmakuSearchSheet(controller: controller),
    ),
  );

  @override
  State<DanmakuSearchSheet> createState() => _DanmakuSearchSheetState();
}

class _DanmakuSearchSheetState extends State<DanmakuSearchSheet> {
  late final TextEditingController _query;
  List<DanmakuAnime> _animes = [];
  List<DanmakuSource> _episodes = [];
  DanmakuAnime? _selected;
  bool _loading = false;
  bool _searched = false;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: widget.controller.videoTitle);
    if (_query.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _search();
      });
    }
  }

  @override
  void dispose() {
    _request++;
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _query.text.trim();
    if (keyword.isEmpty) return;
    FocusScope.of(context).unfocus();
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      _selected = null;
      _animes = [];
      _episodes = [];
      _searched = true;
    });
    try {
      final results = await widget.controller.searchAnime(keyword);
      if (!mounted || request != _request) return;
      setState(() => _animes = results);
    } catch (_) {
      if (mounted && request == _request) {
        setState(() => _error = '搜索请求失败，请检查弹幕接口或网络后重试');
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _chooseAnime(DanmakuAnime anime) async {
    final request = ++_request;
    setState(() {
      _selected = anime;
      _episodes = [];
      _loading = true;
      _error = null;
    });
    try {
      final episodes = await widget.controller.fetchEpisodes(anime);
      if (mounted && request == _request) setState(() => _episodes = episodes);
    } catch (_) {
      if (mounted && request == _request) {
        setState(() => _error = '剧集加载失败，请重试或选择其他平台');
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  void _backToResults() {
    _request++;
    setState(() {
      _selected = null;
      _episodes = [];
      _error = null;
      _loading = false;
    });
  }

  String _title(String value) => value
      .replaceAll(RegExp(r'\s*from\s+[a-z0-9]+', caseSensitive: false), '')
      .replaceAll(RegExp(r'【[^】]*】'), '')
      .trim();

  Widget _message(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.textSecondary, height: 1.6),
      ),
    ),
  );

  Widget _results() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _message(_error!),
          TextButton.icon(
            onPressed: _selected == null
                ? _search
                : () => _chooseAnime(_selected!),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重试'),
          ),
        ],
      );
    }
    if (_selected != null) {
      if (_episodes.isEmpty) return _message('该结果暂无可用剧集，可返回选择其他平台');
      return ListView.separated(
        itemCount: _episodes.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: AppTheme.border),
        itemBuilder: (context, index) {
          final episode = _episodes[index];
          return ListTile(
            key: ValueKey('manual-episode-${episode.episodeId}'),
            leading: Icon(
              Icons.play_circle_outline_rounded,
              color: episode.episodeNumber == widget.controller.videoEpisode
                  ? AppTheme.accent
                  : AppTheme.textSecondary,
            ),
            title: Text(
              '第 ${episode.episodeNumber} 集',
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            ),
            subtitle: Text(
              episode.episodeLabel.replaceAll(RegExp(r'【[^】]*】'), '').trim(),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textMuted,
            ),
            onTap: () {
              if (widget.onSelected != null) {
                widget.onSelected!(episode);
              } else {
                Navigator.of(context).pop(episode);
              }
            },
          );
        },
      );
    }
    if (_animes.isEmpty) {
      return _message(
        _searched
            ? '当前接口未找到结果，试试剧名别名或粘贴视频平台播放链接'
            : '输入剧名、别名或视频平台播放链接，搜索后选择对应剧集',
      );
    }
    return ListView.separated(
      itemCount: _animes.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: AppTheme.border),
      itemBuilder: (context, index) {
        final anime = _animes[index];
        return ListTile(
          key: ValueKey('manual-anime-${anime.id}'),
          leading: const Icon(Icons.subtitles_outlined, color: AppTheme.accent),
          title: Text(
            _title(anime.title),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          ),
          subtitle: Text(
            '${anime.platformName} · ${anime.episodeCount} 集',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.textMuted,
          ),
          onTap: () => _chooseAnime(anime),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              if (_selected != null || widget.onBack != null)
                IconButton(
                  onPressed: _selected != null ? _backToResults : widget.onBack,
                  tooltip: '返回搜索结果',
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    _selected == null
                        ? '手动搜索弹幕'
                        : '选择剧集 · ${_selected!.platformName}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: '关闭',
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(fontSize: 12),
                  controller: _query,
                  key: const ValueKey('danmaku-search-query'),
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: '剧名 / 别名 / 平台播放链接',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _search, child: const Text('搜索')),
            ],
          ),
        ),
        if (_selected != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _title(_selected!.title),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        Expanded(child: _results()),
      ],
    );
  }
}
