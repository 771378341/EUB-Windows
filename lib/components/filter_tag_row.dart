import '../tv/tv_controls.dart';

import 'package:flutter/material.dart';

import '../common/app_theme.dart';
import '../tv/tv_home_design.dart';

import 'dart:math' as math;

/// 筛选标签行，对齐 OHOS `FilterTagRow.ets`；横向滚动对齐 EcoTV FilterBar。
class FilterTagRow extends StatefulWidget {
  final bool compact;
  final String filterKey;
  final String title;
  final List<String> names;
  final List<String> values;
  final String selected;
  final void Function(String key, String value) onPick;

  const FilterTagRow({
    super.key,
    required this.filterKey,
    this.compact = false,
    required this.title,
    required this.names,
    required this.values,
    required this.selected,
    required this.onPick,
  });

  @override
  State<FilterTagRow> createState() => _FilterTagRowState();
}

class _FilterTagRowState extends State<FilterTagRow> {
  final ScrollController _scroller = ScrollController();
  List<GlobalKey> _chipKeys = const [];

  @override
  void initState() {
    super.initState();
    _syncKeys();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpSelected(false));
  }

  @override
  void didUpdateWidget(covariant FilterTagRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.names.length != widget.names.length) {
      _syncKeys();
    }
    if (oldWidget.selected != widget.selected ||
        oldWidget.values != widget.values) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpSelected(true));
    }
  }

  @override
  void dispose() {
    _scroller.dispose();
    super.dispose();
  }

  void _syncKeys() {
    _chipKeys = List.generate(widget.names.length, (i) => GlobalKey());
  }

  bool _isSelected(String val) {
    if (widget.filterKey == 'Sort' &&
        (widget.selected.isEmpty || widget.selected == 'update_stamp')) {
      return val == 'update_stamp';
    }
    return widget.selected == val;
  }

  void _jumpSelected(bool smooth) {
    final idx = widget.values.indexOf(widget.selected);
    if (idx < 0 || idx >= _chipKeys.length) return;
    final ctx = _chipKeys[idx].currentContext;
    if (ctx == null) return;
    final renderObject = ctx.findRenderObject();
    // 只滚动当前行的横向 scroller：Scrollable.ensureVisible 会向上遍历所有可滚动祖先，
    // 误触发外层 CustomScrollView 纵向滚动（导致筛选头只露出一半）。
    final scrollable = Scrollable.maybeOf(ctx);
    if (scrollable == null || renderObject == null) return;
    scrollable.position.ensureVisible(
      renderObject,
      alignment: 0,
      duration: smooth ? const Duration(milliseconds: 220) : Duration.zero,
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.names.isEmpty) return const SizedBox.shrink();

    final s = widget.compact
        ? TvHomeMetrics(MediaQuery.sizeOf(context).width).scale
        : 1.0;
    final textHeight =
        MediaQuery.textScalerOf(context).scale((widget.compact ? 11 : 13) * s) *
        1.25;
    return SizedBox(
      height: math.max((widget.compact ? 30 : 44) * s, textHeight + 10 * s),
      child: Padding(
        padding: EdgeInsets.only(
          left: widget.compact
              ? TvHomeMetrics(MediaQuery.sizeOf(context).width).edge
              : AppTheme.spaceLg,
        ),
        child: Row(
          children: [
            SizedBox(
              width: (widget.compact ? 34 : 40) * s,
              child: Text(
                widget.title,
                style: TextStyle(
                  fontSize: (widget.compact ? 11 : 13) * s,
                  color: AppTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroller,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.only(
                  right: widget.compact
                      ? TvHomeMetrics(MediaQuery.sizeOf(context).width).edge
                      : AppTheme.spaceLg,
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < widget.names.length; i++) ...[
                      if (i > 0) SizedBox(width: (widget.compact ? 5 : 8) * s),
                      _chip(i),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(int index) {
    final name = widget.names[index];
    final val = index < widget.values.length ? widget.values[index] : name;
    final active = _isSelected(val);
    final s = widget.compact
        ? TvHomeMetrics(MediaQuery.sizeOf(context).width).scale
        : 1.0;
    final textHeight =
        MediaQuery.textScalerOf(context).scale((widget.compact ? 11 : 13) * s) *
        1.25;
    return TvTap(
      key: _chipKeys[index],
      onTap: () => widget.onPick(widget.filterKey, val),
      child: Container(
        height: math.max((widget.compact ? 25 : 32) * s, textHeight + 6 * s),
        padding: EdgeInsets.symmetric(
          horizontal: (widget.compact ? 9 : 12) * s,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppTheme.accent : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        child: Text(
          name,
          style: TextStyle(
            fontSize: (widget.compact ? 11 : 13) * s,
            color: active ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
