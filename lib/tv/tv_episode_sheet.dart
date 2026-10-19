import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common/app_theme.dart';
import '../models/film_models.dart';
import 'tv_controls.dart';

/// TV playback keeps the full video surface; this route temporarily covers its bottom.
class TvEpisodeSheet extends StatefulWidget {
  final String title;
  final List<PlaySource> sources;
  final String playingSourceId;
  final int episodeIndex;
  final void Function(String sourceId, int index) onSelect;
  const TvEpisodeSheet({
    super.key,
    required this.title,
    required this.sources,
    required this.playingSourceId,
    required this.episodeIndex,
    required this.onSelect,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<PlaySource> sources,
    required String playingSourceId,
    required int episodeIndex,
    required void Function(String, int) onSelect,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    constraints: BoxConstraints.tightFor(
      width: MediaQuery.sizeOf(context).width,
    ),
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black12,
    builder: (_) => TvEpisodeSheet(
      title: title,
      sources: sources,
      playingSourceId: playingSourceId,
      episodeIndex: episodeIndex,
      onSelect: onSelect,
    ),
  );
  @override
  State<TvEpisodeSheet> createState() => _TvEpisodeSheetState();
}

class _TvEpisodeSheetState extends State<TvEpisodeSheet> {
  late String viewing;
  static const pageSize = 20;
  late int group;
  late int target;
  int revision = 0;
  final sourceScroll = ScrollController();
  final sourceKeys = <String, GlobalKey>{};

  @override
  void dispose() {
    sourceScroll.dispose();
    super.dispose();
  }

  void _revealSource() {
    final ctx = sourceKeys[viewing]?.currentContext;
    final render = ctx?.findRenderObject();
    if (ctx == null || render == null || !sourceScroll.hasClients) return;
    // Only the source strip moves; episode focus never hides this row vertically.
    sourceScroll.position.ensureVisible(
      render,
      alignment: .5,
      duration: Duration.zero,
    );
  }

  @override
  void initState() {
    super.initState();
    viewing = widget.sources.any((s) => s.id == widget.playingSourceId)
        ? widget.playingSourceId
        : (widget.sources.firstOrNull?.id ?? '');
    target = widget.episodeIndex;
    group = target ~/ pageSize;
    for (final source in widget.sources) {
      sourceKeys[source.id] = GlobalKey();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _revealSource();
    });
  }

  void _locate(int index) {
    setState(() {
      target = index;
      group = index ~/ pageSize;
      revision++;
    });
  }

  Future<void> _chooseRange(int count) async {
    final chosen = await showDialog<int>(
      context: context,
      builder: (_) =>
          _EpisodeRangeDialog(count: count, page: group, pageSize: pageSize),
    );
    // Modal route children remain mounted until their closing animation finishes.
    if (mounted && chosen != null) _locate(chosen * pageSize);
  }

  Future<void> _jump(int count) async {
    final chosen = await showDialog<int>(
      context: context,
      builder: (_) => _EpisodeJumpDialog(count: count),
    );
    if (mounted && chosen != null) _locate(chosen - 1);
  }

  Widget _chip(
    String text,
    bool active,
    VoidCallback onTap,
    double scale, {
    Key? key,
  }) => Padding(
    padding: EdgeInsets.only(right: 8 * scale),
    child: TvInkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(6 * scale),
      child: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: 10 * scale),
        decoration: BoxDecoration(
          color: active ? AppTheme.accentSoft : Colors.white10,
          borderRadius: BorderRadius.circular(6 * scale),
        ),
        child: Text(
          text,
          maxLines: 1,
          style: TextStyle(
            fontSize: 12 * scale,
            color: active ? AppTheme.accent : Colors.white70,
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final scale = math
        .min(
          size.width / 960,
          (size.height - MediaQuery.paddingOf(context).bottom) / 200,
        )
        .clamp(.8, 1.25)
        .toDouble();
    final textScale = MediaQuery.textScalerOf(context);
    final source = widget.sources.where((s) => s.id == viewing).firstOrNull;
    final count = source?.linkList.length ?? 0;
    final groups = math.max(1, (count / pageSize).ceil());
    final currentGroup = group.clamp(0, groups - 1);
    final start = currentGroup * pageSize;
    final end = math.min(count, start + pageSize);
    final active = viewing == widget.playingSourceId ? widget.episodeIndex : -1;
    final headerHeight = math.max(
      30 * scale,
      textScale.scale(14 * scale) * 1.3 + 6 * scale,
    );
    final sourcesHeight = widget.sources.length > 1
        ? math.max(30 * scale, textScale.scale(12 * scale) * 1.3 + 10 * scale)
        : 0.0;
    final toolbarHeight = count > 0
        ? math.max(32 * scale, textScale.scale(12 * scale) * 1.3 + 10 * scale)
        : 0.0;
    final episodeHeight = math.max(
      42 * scale,
      textScale.scale(13 * scale) * 1.3 + 14 * scale,
    );
    final bottom = MediaQuery.paddingOf(context).bottom;
    final panelHeight =
        headerHeight +
        sourcesHeight +
        toolbarHeight +
        6 * scale +
        episodeHeight +
        10 * scale +
        bottom;
    Widget tool(String text, VoidCallback? action) => TextButton(
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 8 * scale),
        minimumSize: Size(0, toolbarHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 12 * scale,
        ),
      ),
      onPressed: action,
      child: Text(text),
    );
    return SizedBox(
      key: const ValueKey('tv-episode-panel'),
      height: panelHeight,
      child: Material(
        color: const Color(0xF2181A20),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12 * scale)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24 * scale,
            0,
            24 * scale,
            bottom + 10 * scale,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: headerHeight,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '选集 · ${widget.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14 * scale,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (size.width >= 760)
                      Text(
                        '左右选择 · 确认播放',
                        style: TextStyle(
                          fontSize: 10 * scale,
                          color: Colors.white54,
                        ),
                      ),
                    SizedBox(width: 8 * scale),
                    IconButton(
                      tooltip: '关闭选集',
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints.tightFor(
                        width: 28 * scale,
                        height: 28 * scale,
                      ),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, size: 20 * scale),
                    ),
                  ],
                ),
              ),
              if (widget.sources.length > 1)
                SizedBox(
                  key: const ValueKey('tv-source-strip'),
                  height: sourcesHeight,
                  child: SingleChildScrollView(
                    controller: sourceScroll,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(
                      horizontal: 3 * scale,
                      vertical: 3 * scale,
                    ),
                    child: Row(
                      children: [
                        for (final s in widget.sources)
                          _chip(
                            s.name,
                            s.id == viewing,
                            () {
                              setState(() {
                                viewing = s.id;
                                target = s.id == widget.playingSourceId
                                    ? widget.episodeIndex
                                    : 0;
                                group = target ~/ pageSize;
                                revision++;
                              });
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) _revealSource();
                              });
                            },
                            scale,
                            key: sourceKeys[s.id],
                          ),
                      ],
                    ),
                  ),
                ),
              if (count > 0)
                SizedBox(
                  key: const ValueKey('tv-episode-toolbar'),
                  height: toolbarHeight,
                  child: Row(
                    children: [
                      tool(
                        '上一页',
                        currentGroup > 0
                            ? () => _locate((currentGroup - 1) * pageSize)
                            : null,
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 3 * scale),
                        child: _chip(
                          '${start + 1}–$end / 共$count集 ▾',
                          true,
                          () => _chooseRange(count),
                          scale,
                        ),
                      ),
                      tool(
                        '下一页',
                        currentGroup < groups - 1
                            ? () => _locate((currentGroup + 1) * pageSize)
                            : null,
                      ),
                      const Spacer(),
                      tool('跳转集数', () => _jump(count)),
                      tool('最新一集', () => _locate(count - 1)),
                    ],
                  ),
                ),
              SizedBox(height: 6 * scale),
              if (count == 0)
                SizedBox(
                  height: episodeHeight,
                  child: const Center(
                    child: Text(
                      '暂无可用剧集',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                )
              else
                _EpisodeRow(
                  key: ValueKey('$viewing-$currentGroup-$revision'),
                  source: source!,
                  start: start,
                  end: end,
                  active: active,
                  target: target.clamp(start, end - 1),
                  scale: scale,
                  height: episodeHeight,
                  onSelect: (index) {
                    Navigator.pop(context);
                    widget.onSelect(viewing, index);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpisodeRow extends StatefulWidget {
  final PlaySource source;
  final int start, end, active, target;
  final ValueChanged<int> onSelect;
  final double scale, height;
  const _EpisodeRow({
    super.key,
    required this.source,
    required this.start,
    required this.end,
    required this.active,
    required this.target,
    required this.onSelect,
    required this.scale,
    required this.height,
  });
  @override
  State<_EpisodeRow> createState() => _EpisodeRowState();
}

class _EpisodeRowState extends State<_EpisodeRow> {
  late final ScrollController scroll;
  @override
  void initState() {
    super.initState();
    scroll = ScrollController(
      initialScrollOffset:
          math.max(0, widget.target - widget.start - 2) * 82.0 * widget.scale,
    );
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.height,
    child: ListView.builder(
      controller: scroll,
      scrollDirection: Axis.horizontal,
      itemCount: widget.end - widget.start,
      itemExtent: 82 * widget.scale,
      itemBuilder: (context, offset) {
        final index = widget.start + offset;
        final selected = index == widget.active;
        return Padding(
          padding: EdgeInsets.only(
            right: 8 * widget.scale,
            bottom: 3 * widget.scale,
            top: 3 * widget.scale,
          ),
          child: TvInkWell(
            key: ValueKey('tv-episode-$index'),
            autofocus: index == widget.target,
            onTap: () => widget.onSelect(index),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppTheme.accentSoft : Colors.white10,
                border: Border.all(
                  color: selected ? AppTheme.accent : Colors.transparent,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.source.linkList[index].episode,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13 * widget.scale,
                  color: selected ? AppTheme.accent : Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _EpisodeJumpDialog extends StatefulWidget {
  final int count;
  const _EpisodeJumpDialog({required this.count});
  @override
  State<_EpisodeJumpDialog> createState() => _EpisodeJumpDialogState();
}

class _EpisodeJumpDialogState extends State<_EpisodeJumpDialog> {
  String digits = '';
  int? get number => int.tryParse(digits);
  bool get valid => number != null && number! >= 1 && number! <= widget.count;
  void _digit(String digit) {
    if (digits.length < widget.count.toString().length) {
      setState(() => digits += digit);
    }
  }

  void _delete() {
    if (digits.isNotEmpty) {
      setState(() => digits = digits.substring(0, digits.length - 1));
    }
  }

  void _confirm() {
    if (valid) Navigator.pop(context, number);
  }

  @override
  Widget build(BuildContext context) => Focus(
    onKeyEvent: (_, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      final label = event.character ?? event.logicalKey.keyLabel;
      if (RegExp(r'^[0-9]$').hasMatch(label)) {
        _digit(label);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        _delete();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: AlertDialog(
      scrollable: true,
      titlePadding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      title: const Text('跳转集数', style: TextStyle(fontSize: 20)),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              digits.isEmpty ? '输入集数' : '第$digits集',
              key: const ValueKey('tv-jump-value'),
              style: const TextStyle(fontSize: 24),
            ),
            Text(
              '1–${widget.count}集 · 定位后按确认播放',
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 140,
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 3.25,
                children: [
                  for (final digit in [
                    '1',
                    '2',
                    '3',
                    '4',
                    '5',
                    '6',
                    '7',
                    '8',
                    '9',
                    '清空',
                    '0',
                    '删除',
                  ])
                    TvInkWell(
                      autofocus: digit == '1',
                      onTap: () {
                        if (digit == '清空') {
                          setState(() => digits = '');
                        } else if (digit == '删除') {
                          _delete();
                        } else {
                          _digit(digit);
                        }
                      },
                      child: Center(child: Text(digit)),
                    ),
                ],
              ),
            ),
            if (digits.isNotEmpty && !valid)
              Text(
                '请输入1–${widget.count}之间的集数',
                style: const TextStyle(color: Colors.orange, fontSize: 12),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(onPressed: valid ? _confirm : null, child: const Text('定位')),
      ],
    ),
  );
}

class _EpisodeRangeDialog extends StatefulWidget {
  final int count, page, pageSize;
  const _EpisodeRangeDialog({
    required this.count,
    required this.page,
    required this.pageSize,
  });
  @override
  State<_EpisodeRangeDialog> createState() => _EpisodeRangeDialogState();
}

class _EpisodeRangeDialogState extends State<_EpisodeRangeDialog> {
  late final ScrollController controller = ScrollController(
    initialScrollOffset: (widget.page ~/ 4) * 48.0,
  );
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('选择集数区间 · 共${widget.count}集'),
    content: SizedBox(
      width: 560,
      height: 240,
      child: GridView.builder(
        controller: controller,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisExtent: 48,
          crossAxisSpacing: 6,
        ),
        itemCount: (widget.count / widget.pageSize).ceil(),
        itemBuilder: (context, page) => Padding(
          padding: const EdgeInsets.all(2),
          child: TvInkWell(
            autofocus: page == widget.page,
            onTap: () => Navigator.pop(context, page),
            child: Center(
              child: Text(
                '${page * widget.pageSize + 1}–${math.min(widget.count, (page + 1) * widget.pageSize)}',
                style: TextStyle(
                  color: page == widget.page ? AppTheme.accent : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
    ],
  );
}
