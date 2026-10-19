import '../../../tv/tv_controls.dart';
import 'package:flutter/material.dart';

import '../../../common/app_theme.dart';
import 'danmaku_controller.dart';
import 'danmaku_store.dart';
import 'danmaku_search_sheet.dart';
import 'danmaku_panel.dart';
import 'danmaku_api.dart';

/// 播放中的弹幕源与显示设置；全局接口地址在「我的」中配置。
class DanmakuSheet extends StatefulWidget {
  final DanmakuController controller;

  const DanmakuSheet({super.key, required this.controller});

  static Future<void> show(
    BuildContext context, {
    required DanmakuController controller,
  }) {
    return DanmakuPanel.show<void>(
      context,
      DanmakuPanel(
        controller: controller,
        child: DanmakuSheet(controller: controller),
      ),
    );
  }

  @override
  State<DanmakuSheet> createState() => _DanmakuSheetState();
}

class _DanmakuSheetState extends State<DanmakuSheet> {
  bool _searching = false;
  String? _searchVideoKey;
  late double _fontSize;
  late double _area;
  late double _speed;

  @override
  void initState() {
    super.initState();
    _fontSize = widget.controller.fontSize;
    _area = widget.controller.area;
    _speed = widget.controller.danmakuSpeed;
    widget.controller.addListener(_onController);
  }

  void _onController() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    super.dispose();
  }

  Future<void> _manualSearch() async {
    _searchVideoKey = widget.controller.videoKey;
    setState(() => _searching = true);
  }

  Future<void> _applySource(DanmakuSource source) async {
    final c = widget.controller;
    final videoKey = _searchVideoKey;
    setState(() => _searching = false);
    try {
      await c.applyManualSource(source, expectedVideoKey: videoKey);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('手动匹配保存失败，请重试')));
      }
    }
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required String valueText,
    required ValueChanged<double> onChanged,
    Color? activeColor,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: activeColor ?? AppTheme.accent,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              trackHeight: 3,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            valueText,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    if (_searching) {
      return DanmakuSearchSheet(
        controller: c,
        onBack: () => setState(() => _searching = false),
        onSelected: _applySource,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '弹幕设置',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                autofocus: true,
                onPressed: _manualSearch,
                icon: const Icon(Icons.search_rounded, size: 17),
                label: const Text('手动搜索弹幕', style: TextStyle(fontSize: 12)),
              ),
              IconButton(
                tooltip: '关闭',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '弹幕源',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ),
                    if (c.isManualMatch)
                      TextButton(
                        onPressed: c.restoreAutomatic,
                        child: const Text(
                          '恢复自动',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
                if (c.sources.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      c.status == DanmakuStatus.loading
                          ? '正在搜索弹幕源…'
                          : '未自动匹配，可手动搜索',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i < c.sources.length; i++)
                        TvInkWell(
                          onTap: () => c.selectSource(i),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: i == c.sourceIndex
                                  ? AppTheme.accentSoft
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: i == c.sourceIndex
                                    ? AppTheme.accent
                                    : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              c.sources[i].platformName,
                              style: TextStyle(
                                fontSize: 12,
                                color: i == c.sourceIndex
                                    ? AppTheme.accent
                                    : Colors.white70,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                if (c.status == DanmakuStatus.loading)
                  const LinearProgressIndicator(minHeight: 2),
                if (c.currentSource != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 4),
                    child: Text(
                      '${c.currentSource!.episodeLabel} · ${c.remoteCount} 条弹幕',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                const Divider(color: Colors.white12, height: 16),
                _sliderRow(
                  label: '字号',
                  value: _fontSize,
                  min: DanmakuStore.minFontSize,
                  max: DanmakuStore.maxFontSize,
                  valueText: _fontSize.toStringAsFixed(0),
                  onChanged: (v) {
                    setState(() => _fontSize = v);
                    c.setFontSize(v);
                  },
                ),
                _sliderRow(
                  label: '显示区域',
                  value: _area,
                  min: DanmakuStore.minArea,
                  max: DanmakuStore.maxArea,
                  valueText: '${(_area * 100).round()}%',
                  onChanged: (v) {
                    setState(() => _area = v);
                    c.setArea(v);
                  },
                ),
                _sliderRow(
                  label: '滚动速度',
                  value: _speed,
                  min: DanmakuStore.minSpeed,
                  max: DanmakuStore.maxSpeed,
                  valueText: '${_speed.toStringAsFixed(1)}x',
                  onChanged: (v) {
                    setState(() => _speed = v);
                    c.setDanmakuSpeed(v);
                  },
                ),
                _sliderRow(
                  label: '弹幕透明度',
                  value: 1 - c.opacity,
                  min: 0,
                  max: 0.9,
                  valueText: '${((1 - c.opacity) * 100).round()}%',
                  onChanged: (v) => c.setOpacity(1 - v),
                ),
                _sliderRow(
                  label: '面板透明度',
                  value: 1 - c.panelOpacity,
                  min: 0,
                  max: 0.65,
                  valueText: '${((1 - c.panelOpacity) * 100).round()}%',
                  onChanged: (v) => c.setOpacity(1 - v, panel: true),
                ),
                const Text(
                  '透明度越大越透明 · 设置与搜索面板共用',
                  style: TextStyle(fontSize: 11, color: Colors.white38),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
