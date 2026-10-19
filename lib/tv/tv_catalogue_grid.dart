import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/film_models.dart';
import '../components/empty_state.dart';
import 'tv_home_content.dart';
import 'tv_home_design.dart';

/// Exactly six columns and two complete rows in the available TV viewport.
/// Poster width shrinks inside its cell on short screens instead of clipping captions.
class TvCatalogueGrid extends StatefulWidget {
  final List<MovieBasicInfo> films;
  final ScrollController controller;
  final Widget? filters;
  const TvCatalogueGrid({
    super.key,
    required this.films,
    required this.controller,
    this.filters,
  });

  @override
  State<TvCatalogueGrid> createState() => _TvCatalogueGridState();
}

class _TvCatalogueGridState extends State<TvCatalogueGrid> {
  final _filterKey = GlobalKey();

  void _revealPoster(BuildContext context) {
    if (!widget.controller.hasClients) return;
    final header = _filterKey.currentContext?.size?.height ?? 0;
    final position = widget.controller.position;
    if (position.pixels < header - .5) {
      widget.controller.animateTo(
        header.clamp(position.minScrollExtent, position.maxScrollExtent),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    } else {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 120),
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final m = TvHomeMetrics(MediaQuery.sizeOf(context).width), s = m.scale;
      final padding = 3 * s, gap = 10 * s;
      final cellWidth = (constraints.maxWidth - m.edge * 2 - m.gap * 5) / 6;
      final rowHeight = (constraints.maxHeight - padding * 2 - gap) / 2;
      final caption = m.captionHeightFor(MediaQuery.textScalerOf(context));
      final posterWidth = math.min(
        cellWidth,
        math.max(1.0, rowHeight - caption) * .8,
      );
      return CustomScrollView(
        key: const ValueKey('tv-catalogue-grid'),
        controller: widget.controller,
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        // Keep the filter and films in the same vertical scrollable. The grid
        // keeps its two-row viewport size when the filter moves off screen.
        slivers: [
          if (widget.filters != null)
            SliverToBoxAdapter(
              child: KeyedSubtree(key: _filterKey, child: widget.filters!),
            ),
          if (widget.films.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(title: '没有符合条件的影片'),
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: m.edge,
                vertical: padding,
              ),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisExtent: rowHeight,
                  crossAxisSpacing: m.gap,
                  mainAxisSpacing: gap,
                ),
                itemCount: widget.films.length,
                itemBuilder: (_, index) => Align(
                  alignment: Alignment.topCenter,
                  child: TvHomePoster(
                    key: ValueKey('tv-catalogue-item-$index'),
                    film: widget.films[index],
                    metrics: m,
                    cardWidth: posterWidth,
                    posterHeight: posterWidth / .8,
                    onFocused: _revealPoster,
                  ),
                ),
              ),
            ),
          if (widget.films.isNotEmpty && widget.films.length <= 6)
            SliverToBoxAdapter(child: SizedBox(height: rowHeight + gap)),
        ],
      );
    },
  );
}
