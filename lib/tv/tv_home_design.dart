import 'dart:math' as math;
import '../desktop/app_window.dart';

import 'package:flutter/material.dart';

import '../common/app_theme.dart';
import '../models/film_models.dart';

/// Proportional canvas; height also constrains artwork on wide TV displays.
class TvHomeMetrics {
  final double width;
  const TvHomeMetrics(this.width);
  double get scale =>
      (width / 960).clamp(.65, AppWindow.isWindows ? 1.15 : 2.0);
  double get edge => 24 * scale;
  double get gap => 12 * scale;
  double get navHeight => 40 * scale;
  double get posterWidth => (width - edge * 2 - gap * 5) / 6;
  double titleHeightFor(TextScaler scaler) =>
      math.max(16 * scale, scaler.scale(13 * scale) * 1.2);
  double metaHeightFor(TextScaler scaler) =>
      math.max(13 * scale, scaler.scale(10 * scale) * 1.2);
  double captionHeightFor(TextScaler scaler) =>
      4 * scale + titleHeightFor(scaler) + metaHeightFor(scaler);
  double posterHeightFor(double height) =>
      (posterWidth * 1.26).clamp(0, height * .37);
}

class TvHomeNavigation extends StatelessWidget implements PreferredSizeWidget {
  final double width;
  final List<CategoryItem> categories;
  final int selectedTab;
  final bool hasUpdate;
  final ValueChanged<int> onSelectTab;
  final ValueChanged<CategoryItem> onCategory;
  final VoidCallback onSearch, onHistory;
  const TvHomeNavigation({
    super.key,
    required this.width,
    required this.categories,
    required this.selectedTab,
    this.hasUpdate = false,
    required this.onSelectTab,
    required this.onCategory,
    required this.onSearch,
    required this.onHistory,
  });
  @override
  Size get preferredSize => Size.fromHeight(TvHomeMetrics(width).navHeight);

  @override
  Widget build(BuildContext context) {
    final m = TvHomeMetrics(width), s = m.scale;
    final style = TextStyle(fontSize: 13 * s, fontWeight: FontWeight.w500);
    double textWidth(String text) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: style.copyWith(fontWeight: FontWeight.w700),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final result = painter.width;
      painter.dispose();
      return result;
    }

    Widget action(
      String label,
      VoidCallback onTap, {
      bool active = false,
      bool autofocus = false,
      IconData? icon,
      String? tooltip,
      bool badge = false,
    }) => _TvNavAction(
      label: label,
      onTap: onTap,
      active: active,
      autofocus: autofocus,
      icon: icon,
      tooltip: tooltip,
      badge: badge,
      scale: s,
    );
    final items = {
      for (final c in categories.where((c) => c.show)) c.id: c,
    }.values.toList();
    return Material(
      color: AppTheme.bg,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: m.navHeight,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: m.edge),
            child: Row(
              children: [
                Semantics(
                  label: 'EUB弹幕',
                  child: ExcludeSemantics(
                    child: Text.rich(
                      const TextSpan(
                        children: [
                          TextSpan(
                            text: 'EUB',
                            style: TextStyle(color: AppTheme.accent),
                          ),
                          TextSpan(
                            text: '弹幕',
                            style: TextStyle(color: Color(0xFFB8BECC)),
                          ),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: 18 * s,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 18 * s),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final visible = <CategoryItem>[];
                      var remaining =
                          constraints.maxWidth - textWidth('推荐') - 14 * s;
                      final total = items.fold<double>(
                        0,
                        (v, c) => v + textWidth(c.name) + 14 * s,
                      );
                      if (total > remaining) {
                        remaining -= textWidth('分类') + 30 * s;
                      }
                      for (final item in items) {
                        final needed = textWidth(item.name) + 14 * s;
                        if (needed > remaining) break;
                        visible.add(item);
                        remaining -= needed;
                      }
                      final hidden = items.skip(visible.length).toList();
                      return Row(
                        children: [
                          action(
                            '推荐',
                            () => onSelectTab(0),
                            active: selectedTab == 0,
                            autofocus: true,
                          ),
                          for (final item in visible)
                            action(item.name, () => onCategory(item)),
                          if (hidden.isNotEmpty)
                            PopupMenuButton<CategoryItem>(
                              tooltip: '更多分类',
                              padding: EdgeInsets.zero,
                              onSelected: onCategory,
                              itemBuilder: (_) => [
                                for (final item in hidden)
                                  PopupMenuItem(
                                    value: item,
                                    child: Text(item.name),
                                  ),
                              ],
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 7 * s,
                                  vertical: 7 * s,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('分类', style: style),
                                    Icon(Icons.expand_more, size: 16 * s),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                SizedBox(width: 4 * s),
                action('搜索', onSearch, icon: Icons.search, tooltip: '搜索影片'),
                action('历史', onHistory, icon: Icons.history, tooltip: '观看历史'),
                action('更新', () => onSelectTab(1), active: selectedTab == 1),
                action(
                  '我的',
                  () => onSelectTab(2),
                  active: selectedTab == 2,
                  badge: hasUpdate,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact focus treatment confined to the navigation, without a heavy box.
class _TvNavAction extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool active, autofocus, badge;
  final IconData? icon;
  final String? tooltip;
  final double scale;
  const _TvNavAction({
    required this.label,
    required this.onTap,
    required this.scale,
    this.active = false,
    this.autofocus = false,
    this.badge = false,
    this.icon,
    this.tooltip,
  });
  @override
  State<_TvNavAction> createState() => _TvNavActionState();
}

class _TvNavActionState extends State<_TvNavAction> {
  bool focused = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    final color = focused || widget.active
        ? AppTheme.accent
        : const Color(0xFFB8BECC);
    final button = InkWell(
      autofocus: widget.autofocus,
      onTap: widget.onTap,
      onFocusChange: (v) => setState(() => focused = v),
      focusColor: Colors.transparent,
      borderRadius: BorderRadius.circular(3 * s),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 7 * s),
        decoration: BoxDecoration(
          color: focused
              ? AppTheme.accent.withValues(alpha: .12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(3 * s),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 15 * s, color: color),
                  SizedBox(width: 3 * s),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13 * s,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                if (widget.badge)
                  Padding(
                    padding: EdgeInsets.only(left: 3 * s),
                    child: Container(
                      width: 4 * s,
                      height: 4 * s,
                      decoration: const BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 3 * s),
            Container(
              width: 19 * s,
              height: 1.5 * s,
              color: widget.active || focused
                  ? AppTheme.accent
                  : Colors.transparent,
            ),
          ],
        ),
      ),
    );
    return widget.tooltip == null
        ? button
        : Tooltip(message: widget.tooltip!, child: button);
  }
}
