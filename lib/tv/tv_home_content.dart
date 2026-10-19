import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../common/app_theme.dart';
import '../models/film_models.dart';
import '../utils/format_util.dart';
import '../utils/nav_util.dart';
import '../utils/server_config_manager.dart';
import '../utils/favorite_manager.dart';
import 'tv_controls.dart';
import 'tv_home_design.dart';

Widget _image(String url, String title) => url.isEmpty
    ? ColoredBox(
        color: AppTheme.bgCard,
        child: Center(
          child: Text(title, style: const TextStyle(color: Colors.white30)),
        ),
      )
    : CachedNetworkImage(
        imageUrl: url,
        httpHeaders: FormatUtil.imageHeaders(url),
        fit: BoxFit.cover,
        placeholder: (_, _) => const ColoredBox(color: AppTheme.bgCard),
        errorWidget: (_, _, _) => const ColoredBox(color: AppTheme.bgCard),
      );

/// Original frame remains fully visible, even when the source is a portrait.
class TvHighlightArtwork extends StatelessWidget {
  final ImageProvider image;
  const TvHighlightArtwork({super.key, required this.image});
  @override
  Widget build(BuildContext context) => ClipRect(
    child: Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Image(
            image: image,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
        ),
        const ColoredBox(color: Color(0x55000000)),
        Image(image: image, fit: BoxFit.contain, excludeFromSemantics: true),
      ],
    ),
  );
}

class TvHomeHighlights extends StatelessWidget {
  final List<BannerItem> banners;
  final List<MovieBasicInfo> fallback;
  const TvHomeHighlights({
    super.key,
    required this.banners,
    this.fallback = const [],
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context),
        m = TvHomeMetrics(MediaQuery.sizeOf(context).width);
    final s = m.scale;
    final items =
        <({String name, String image, String meta, VoidCallback open})>[
          for (final b in banners)
            (
              name: b.name,
              image: ServerConfigManager.instance.resolveMediaUrl(
                FormatUtil.bannerBackdrop(b),
              ),
              meta: FormatUtil.joinMeta([b.cName, b.area]),
              open: () => Navigator.pushNamed(
                context,
                '/play',
                arguments: {'id': b.mid > 0 ? '${b.mid}' : b.id},
              ),
            ),
        ];
    if (items.length < 3) {
      final existing = banners
          .map((b) => b.mid > 0 ? '${b.mid}' : b.id)
          .toSet();
      for (final film in fallback) {
        if (items.length >= 3) break;
        if (!existing.add(FormatUtil.filmId(film))) continue;
        items.add((
          name: film.name,
          image: ServerConfigManager.instance.resolveMediaUrl(
            film.pictureSlide.isNotEmpty
                ? film.pictureSlide
                : FormatUtil.poster(film),
          ),
          meta: FormatUtil.joinMeta([film.cName, film.area]),
          open: () => NavUtil.openPlay(
            context,
            FormatUtil.filmId(film),
            sourceId: film.sourceId,
            sourceMid: film.sourceMid > 0 ? '${film.sourceMid}' : '',
            title: film.name,
          ),
        ));
      }
    }
    if (items.isEmpty) return const SizedBox.shrink();
    final cardWidth = (size.width - m.edge * 2 - m.gap * 2) / 3;
    final imageHeight = (cardWidth * 9 / 16)
        .clamp(0.0, size.height * .24)
        .toDouble();
    return SizedBox(
      height: imageHeight + 44 * s,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: m.edge - 3 * s),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 3 * s, vertical: 3 * s),
          itemCount: items.length,
          separatorBuilder: (_, _) => SizedBox(width: m.gap),
          itemBuilder: (_, i) => _TvHighlightCard(
            key: ValueKey('tv-highlight-$i'),
            name: items[i].name,
            image: items[i].image,
            meta: items[i].meta,
            open: items[i].open,
            width: cardWidth,
            imageHeight: imageHeight,
            scale: s,
          ),
        ),
      ),
    );
  }
}

class _TvHighlightCard extends StatefulWidget {
  final String name, image, meta;
  final VoidCallback open;
  final double width, imageHeight, scale;
  const _TvHighlightCard({
    super.key,
    required this.name,
    required this.image,
    required this.meta,
    required this.open,
    required this.width,
    required this.imageHeight,
    required this.scale,
  });
  @override
  State<_TvHighlightCard> createState() => _TvHighlightCardState();
}

class _TvHighlightCardState extends State<_TvHighlightCard> {
  bool focused = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    return SizedBox(
      width: widget.width,
      child: InkWell(
        onTap: widget.open,
        focusColor: Colors.transparent,
        borderRadius: BorderRadius.circular(4 * s),
        onFocusChange: (value) {
          setState(() => focused = value);
          if (value) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && focused) {
                Scrollable.ensureVisible(
                  context,
                  duration: const Duration(milliseconds: 120),
                  alignmentPolicy:
                      ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
                );
              }
            });
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: widget.imageHeight,
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4 * s),
                border: Border.all(
                  color: focused ? AppTheme.accent : Colors.transparent,
                  width: 1.5 * s,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4 * s),
                child: SizedBox.expand(
                  child: widget.image.isEmpty
                      ? const ColoredBox(color: AppTheme.bgCard)
                      : CachedNetworkImage(
                          imageUrl: widget.image,
                          httpHeaders: FormatUtil.imageHeaders(widget.image),
                          imageBuilder: (_, provider) =>
                              TvHighlightArtwork(image: provider),
                          placeholder: (_, _) =>
                              const ColoredBox(color: AppTheme.bgCard),
                          errorWidget: (_, _, _) =>
                              const ColoredBox(color: AppTheme.bgCard),
                        ),
                ),
              ),
            ),
            SizedBox(height: 4 * s),
            Text(
              widget.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13 * s,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: focused ? AppTheme.accent : Colors.white,
              ),
            ),
            SizedBox(height: 2 * s),
            Text(
              widget.meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10 * s,
                height: 1.2,
                color: const Color(0xFF9199AA),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TvHomeFilmRow extends StatelessWidget {
  final String title;
  final List<MovieBasicInfo> films;
  final VoidCallback onMore;
  const TvHomeFilmRow({
    super.key,
    required this.title,
    required this.films,
    required this.onMore,
  });
  @override
  Widget build(BuildContext context) {
    if (films.isEmpty) return const SizedBox.shrink();
    final m = TvHomeMetrics(MediaQuery.sizeOf(context).width),
        s = TvHomeMetrics(MediaQuery.sizeOf(context).width).scale;
    return Padding(
      padding: EdgeInsets.only(top: 7 * s, bottom: 1 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: m.edge),
            child: SizedBox(
              height: 27 * s,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15 * s,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TvInkWell(
                    onTap: onMore,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 4 * s),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '查看全部',
                            style: TextStyle(
                              fontSize: 11 * s,
                              color: const Color(0xFF9BA3B4),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 13 * s,
                            color: const Color(0xFF9BA3B4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height:
                m.posterHeightFor(MediaQuery.sizeOf(context).height) +
                m.captionHeightFor(MediaQuery.textScalerOf(context)) +
                6 * s,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: m.edge - 3 * s),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.hardEdge,
                padding: EdgeInsets.fromLTRB(3 * s, 3 * s, 3 * s, 0),
                itemCount: films.length,
                separatorBuilder: (_, _) => SizedBox(width: m.gap),
                itemBuilder: (_, index) =>
                    TvHomePoster(film: films[index], metrics: m),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TvHomePoster extends StatefulWidget {
  final MovieBasicInfo film;
  final TvHomeMetrics metrics;
  final double? posterHeight, cardWidth;
  final ValueChanged<BuildContext>? onFocused;
  const TvHomePoster({
    super.key,
    required this.film,
    required this.metrics,
    this.posterHeight,
    this.cardWidth,
    this.onFocused,
  });
  @override
  State<TvHomePoster> createState() => _TvHomePosterState();
}

class _TvHomePosterState extends State<TvHomePoster> {
  bool focused = false;
  @override
  Widget build(BuildContext context) {
    final f = widget.film, m = widget.metrics, s = widget.metrics.scale;
    return SizedBox(
      width: widget.cardWidth ?? m.posterWidth,
      child: InkWell(
        onFocusChange: (value) {
          if (!mounted) return;
          setState(() => focused = value);
          if (value) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && focused) {
                if (widget.onFocused != null) {
                  widget.onFocused!(context);
                  return;
                }
                Scrollable.ensureVisible(
                  context,
                  duration: const Duration(milliseconds: 120),
                  alignmentPolicy:
                      ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
                );
              }
            });
          }
        },
        onTap: () => NavUtil.openPlay(
          context,
          FormatUtil.filmId(f),
          sourceId: f.sourceId,
          sourceMid: f.sourceMid > 0 ? '${f.sourceMid}' : '',
          title: f.name,
        ),
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        borderRadius: BorderRadius.circular(4 * s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              key: ValueKey('tv-poster-${f.id}'),
              height:
                  widget.posterHeight ??
                  m.posterHeightFor(MediaQuery.sizeOf(context).height),
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4 * s),
                border: Border.all(
                  color: focused ? AppTheme.accent : Colors.transparent,
                  width: 2 * s,
                ),
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4 * s),
                boxShadow: focused
                    ? [
                        BoxShadow(
                          color: AppTheme.accent.withValues(alpha: .3),
                          blurRadius: 7 * s,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4 * s),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _image(
                      ServerConfigManager.instance.resolveMediaUrl(
                        FormatUtil.poster(f),
                      ),
                      '',
                    ),
                    if (f.dbScore.isNotEmpty)
                      Positioned(
                        top: 5 * s,
                        right: 6 * s,
                        child: Text(
                          f.dbScore,
                          style: TextStyle(
                            fontSize: 13 * s,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accent,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      left: 4 * s,
                      top: 4 * s,
                      child: ValueListenableBuilder<int>(
                        valueListenable: FavoriteManager.favoriteVersion,
                        builder: (_, _, _) =>
                            FavoriteManager.isFavoriteSync(FormatUtil.filmId(f))
                            ? Icon(
                                Icons.star_rounded,
                                size: 13 * s,
                                color: AppTheme.accent,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 4 * s),
            SizedBox(
              height: m.titleHeightFor(MediaQuery.textScalerOf(context)),
              child: Text(
                f.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13 * s,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ),
            SizedBox(
              height: m.metaHeightFor(MediaQuery.textScalerOf(context)),
              child: Text(
                FormatUtil.remarks(f.remarks).isNotEmpty
                    ? FormatUtil.remarks(f.remarks)
                    : FormatUtil.joinMeta([f.year, f.cName]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10 * s,
                  color: const Color(0xFF9199AA),
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
