import '../../desktop/app_window.dart';
import '../../desktop/window_buttons.dart';
import 'package:window_manager/window_manager.dart';
import '../../tv/tv_controls.dart';
import 'package:flutter/material.dart';
import '../../common/app_theme.dart';
import '../../utils/format_util.dart';

/// 播放器顶部控制栏（全屏模式），对齐 OHOS `PlayerSkin.topBar`
class PlayerTopBar extends StatelessWidget {
  final bool isFull;
  final bool showHud;
  final String errorText;
  final String title;
  final double topInset;
  final double leftInset;
  final double rightInset;
  final bool hasPrev;
  final bool hasNext;
  final String castDeviceName;
  final bool canCast;
  final VoidCallback onBack;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onCast;
  final VoidCallback? onStopCast;
  final VoidCallback? onPip;

  const PlayerTopBar({
    super.key,
    required this.isFull,
    required this.showHud,
    required this.errorText,
    required this.title,
    this.topInset = 0,
    this.leftInset = 0,
    this.rightInset = 0,
    this.hasPrev = false,
    this.hasNext = false,
    this.castDeviceName = '',
    this.canCast = false,
    required this.onBack,
    this.onPrev,
    this.onNext,
    this.onCast,
    this.onStopCast,
    this.onPip,
  });

  double _edge(double base, double inset) => base > inset ? base : inset;

  @override
  Widget build(BuildContext context) {
    if (AppWindow.isWindows) {
      return ValueListenableBuilder<bool>(
        valueListenable: AppWindow.isMini,
        builder: (context, mini, _) => _buildBar(context, mini),
      );
    }
    return _buildBar(context, false);
  }

  Widget _buildBar(BuildContext context, bool mini) {
    if (!isFull || (!showHud && errorText.isEmpty)) {
      return mini
          ? const SizedBox(height: 32,
              child: DragToMoveArea(child: ColoredBox(color: Colors.transparent)))
          : const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: _edge(mini ? 2 : 8, topInset),
        left: _edge(mini ? 4 : 8, leftInset),
        right: _edge(mini ? 4 : 8, rightInset),
        bottom: mini ? 2 : 8,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xAA000000), Color(0x55000000), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 18,
            ),
            tooltip: mini ? '恢复窗口' : '返回',
            constraints: BoxConstraints.tightFor(width: mini ? 32 : 40, height: mini ? 32 : 40),
            padding: const EdgeInsets.all(6),
            onPressed: mini ? AppWindow.exitMini : onBack,
          ),
          Expanded(
            child: mini
                ? DragToMoveArea(
                    child: SizedBox(height: 32, child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(title, maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                    )),
                  )
                : Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white,
                      fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          if (AppWindow.isWindows) const DesktopWindowButtons(),
          if (onPip != null && castDeviceName.isEmpty && errorText.isEmpty)
            IconButton(
              icon: const Icon(
                Icons.picture_in_picture_alt_rounded,
                color: Colors.white,
                size: 20,
              ),
              tooltip: '画中画',
              onPressed: onPip,
            ),
        ],
      ),
    );
  }
}

/// 播放器底部控制栏，对齐 OHOS `PlayerSkin.bottomBar`
class PlayerBottomBar extends StatefulWidget {
  final bool isReady;
  final bool isOpening;
  final bool showHud;
  final String errorText;
  final bool cinemaHud;
  final bool isFull;
  final bool isPlaying;
  final bool muted;
  final Duration currentPosition;
  final Duration totalDuration;
  final double currentSpeed;
  final String scaleLabel;
  final double leftInset;
  final double rightInset;
  final double bottomInset;
  final String castDeviceName;
  final bool danmakuEnabled;
  final bool hasPrev;
  final bool hasNext;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onTogglePlay;
  final VoidCallback onToggleFull;
  final VoidCallback onToggleMute;
  final VoidCallback onSpeed;
  final VoidCallback? onScale;
  final VoidCallback? onToggleDanmaku;
  final VoidCallback? onOpenDanmakuSettings;
  final VoidCallback? onOpenEpisodes;
  final ValueChanged<Duration>? onSeekStart;
  final ValueChanged<Duration>? onSeekProgress;
  final ValueChanged<Duration>? onSeekEnd;
  final ValueChanged<Duration> onSeekTo;

  const PlayerBottomBar({
    super.key,
    required this.isReady,
    required this.isOpening,
    required this.showHud,
    required this.errorText,
    required this.cinemaHud,
    required this.isFull,
    required this.isPlaying,
    required this.muted,
    required this.currentPosition,
    required this.totalDuration,
    required this.currentSpeed,
    required this.scaleLabel,
    this.leftInset = 0,
    this.rightInset = 0,
    this.bottomInset = 0,
    this.castDeviceName = '',
    this.danmakuEnabled = false,
    this.hasPrev = false,
    this.hasNext = false,
    this.onPrev,
    this.onNext,
    required this.onTogglePlay,
    required this.onToggleFull,
    required this.onToggleMute,
    required this.onSpeed,
    this.onScale,
    this.onToggleDanmaku,
    this.onOpenDanmakuSettings,
    this.onOpenEpisodes,
    this.onSeekStart,
    this.onSeekProgress,
    this.onSeekEnd,
    required this.onSeekTo,
  });

  @override
  State<PlayerBottomBar> createState() => _PlayerBottomBarState();
}

class _PlayerBottomBarState extends State<PlayerBottomBar> {
  bool _isDragging = false;
  double _dragMs = 0;

  double _edge(double base, double inset) => base > inset ? base : inset;

  Widget _buildSlider(BuildContext context) {
    final maxMs = widget.totalDuration.inMilliseconds > 0
        ? widget.totalDuration.inMilliseconds.toDouble()
        : 1.0;
    final curMs = _isDragging
        ? _dragMs.clamp(0.0, maxMs)
        : widget.currentPosition.inMilliseconds
              .clamp(0, maxMs.toInt())
              .toDouble();

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 2.5,
        tickMarkShape: SliderTickMarkShape.noTickMark,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        activeTrackColor: AppTheme.accent,
        inactiveTrackColor: Colors.white24,
        thumbColor: Colors.white,
      ),
      child: Slider(
        value: curMs,
        min: 0.0,
        max: maxMs,
        divisions: (maxMs / 10000).ceil().clamp(1, 100000),
        onChangeStart: (val) {
          setState(() {
            _isDragging = true;
            _dragMs = val;
          });
          widget.onSeekStart?.call(Duration(milliseconds: val.toInt()));
        },
        onChanged: (val) {
          setState(() {
            _dragMs = val;
          });
          widget.onSeekProgress?.call(Duration(milliseconds: val.toInt()));
        },
        onChangeEnd: (val) {
          setState(() {
            _isDragging = false;
          });
          final target = Duration(milliseconds: val.toInt());
          widget.onSeekEnd?.call(target);
          widget.onSeekTo(target);
        },
      ),
    );
  }

  /// Same icon size, hit target and colors as the other player controls.
  Widget _buildDanmakuIconBtn({
    required bool isToggle,
    required VoidCallback? onTap,
    bool compact = false,
  }) {
    return IconButton(
      key: ValueKey(isToggle ? 'danmaku-toggle' : 'danmaku-settings'),
      tooltip: isToggle ? (widget.danmakuEnabled ? '关闭弹幕' : '开启弹幕') : '弹幕设置',
      onPressed: onTap,
      padding: const EdgeInsets.all(6),
      constraints: BoxConstraints.tightFor(
        width: compact ? 32 : 40,
        height: compact ? 32 : 40,
      ),
      icon: Icon(
        isToggle ? Icons.subtitles_outlined : Icons.tune_rounded,
        size: compact ? 20 : 22,
        color: isToggle
            ? (widget.danmakuEnabled ? AppTheme.accent : Colors.white54)
            : Colors.white,
      ),
    );
  }

  /// 两个弹幕按钮并排：开关 + 设置
  Widget _buildDanmakuBtns({bool compact = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDanmakuIconBtn(
          isToggle: true,
          onTap: widget.onToggleDanmaku,
          compact: compact,
        ),
        const SizedBox(width: 2),
        _buildDanmakuIconBtn(
          isToggle: false,
          onTap: widget.onOpenDanmakuSettings,
          compact: compact,
        ),
      ],
    );
  }

  Widget _buildCompactDesktop(BuildContext context, double displaySec) {
    Widget action(IconData icon, String label, VoidCallback? onPressed) =>
        IconButton(
          tooltip: label, onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          icon: Icon(icon, size: 20, color: onPressed == null ? Colors.white30 : Colors.white),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
      color: const Color(0xB8000000),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(height: 24, child: Row(children: [
          Text(FormatUtil.duration(displaySec),
              style: const TextStyle(color: Colors.white70, fontSize: 10)),
          Expanded(child: _buildSlider(context)),
          Text(FormatUtil.duration(widget.totalDuration.inSeconds.toDouble()),
              style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ])),
        Row(children: [
          if (widget.hasPrev || widget.hasNext)
            action(Icons.skip_previous_rounded, '上一集',
                widget.hasPrev ? widget.onPrev : null),
          action(widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              widget.isPlaying ? '暂停' : '播放', widget.onTogglePlay),
          if (widget.hasPrev || widget.hasNext)
            action(Icons.skip_next_rounded, '下一集',
                widget.hasNext ? widget.onNext : null),
          const Spacer(),
          action(widget.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              widget.muted ? '取消静音' : '静音', widget.onToggleMute),
          if (widget.onToggleDanmaku != null)
            _buildDanmakuIconBtn(isToggle: true,
                onTap: widget.onToggleDanmaku, compact: true),
          SizedBox(width: 32, height: 32, child: PopupMenuButton<String>(
            key: const ValueKey('desktop-player-more'),
            menuPadding: EdgeInsets.zero,
            tooltip: '更多播放操作',
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.more_horiz, size: 20, color: Colors.white),
            onSelected: (value) {
              switch (value) {
                case 'speed': widget.onSpeed(); break;
                case 'scale': widget.onScale?.call(); break;
                case 'danmaku': widget.onOpenDanmakuSettings?.call(); break;
                case 'episodes': widget.onOpenEpisodes?.call(); break;
                case 'fullscreen': AppWindow.toggleFullscreen(); break;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(height: 28, value: 'speed', child: Text('倍速 ${widget.currentSpeed}x')),
              if (widget.onScale != null)
                PopupMenuItem(height: 28, value: 'scale', child: Text('画面比例 · ${widget.scaleLabel}')),
              if (widget.onOpenDanmakuSettings != null)
                const PopupMenuItem(height: 28, value: 'danmaku', child: Text('弹幕设置')),
              if (widget.onOpenEpisodes != null)
                const PopupMenuItem(height: 28, value: 'episodes', child: Text('选集')),
              const PopupMenuItem(height: 28, value: 'fullscreen', child: Text('切换全屏')),
            ],
          )),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isReady ||
        widget.isOpening ||
        !widget.showHud ||
        widget.errorText.isNotEmpty ||
        widget.castDeviceName.isNotEmpty) {
      return const SizedBox.shrink();
    }

    final displaySec = _isDragging
        ? (_dragMs / 1000.0)
        : widget.currentPosition.inSeconds.toDouble();
    final timeStr =
        '${FormatUtil.duration(displaySec)} / ${FormatUtil.duration(widget.totalDuration.inSeconds.toDouble())}';

    if (AppWindow.isWindows && MediaQuery.sizeOf(context).width < 700) {
      return _buildCompactDesktop(context, displaySec);
    }

    if (widget.cinemaHud) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          left: _edge(12, widget.leftInset),
          right: _edge(12, widget.rightInset),
          bottom: _edge(4, widget.bottomInset),
          top: 4,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xCC000000), Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  FormatUtil.duration(displaySec),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Expanded(child: _buildSlider(context)),
                Text(
                  FormatUtil.duration(
                    widget.totalDuration.inSeconds.toDouble(),
                  ),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            Row(
              children: [
                if (widget.hasPrev || widget.hasNext)
                  IconButton(tooltip: '上一集', onPressed: widget.hasPrev ? widget.onPrev : null,
                    icon: const Icon(Icons.skip_previous_rounded, size: 24)),
                IconButton(
                  icon: Icon(
                    widget.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  tooltip: widget.isPlaying ? '暂停' : '播放',
                  onPressed: widget.onTogglePlay,
                ),
                if (widget.hasPrev || widget.hasNext)
                  IconButton(tooltip: '下一集', onPressed: widget.hasNext ? widget.onNext : null,
                    icon: const Icon(Icons.skip_next_rounded, size: 24)),
                const Spacer(),
                TvInkWell(
                  onTap: widget.onSpeed,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: Text(
                      '${widget.currentSpeed}x',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (widget.onScale != null)
                  TvInkWell(
                    onTap: widget.onScale,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    child: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusPill,
                        ),
                      ),
                      child: Text(
                        widget.scaleLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  icon: Icon(
                    widget.muted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: widget.onToggleMute,
                ),
                if (widget.onToggleDanmaku != null) _buildDanmakuBtns(),
                if (widget.onOpenEpisodes != null)
                  TextButton.icon(
                    onPressed: widget.onOpenEpisodes,
                    icon: const Icon(Icons.playlist_play, size: 22),
                    label: const Text('选集'),
                  )
                else
                  IconButton(
                    icon: Icon(
                      widget.isFull
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: widget.onToggleFull,
                  ),
              ],
            ),
          ],
        ),
      );
    }

    // 竖屏底栏（精简对齐 OHOS：隐藏比例与静音，保留充足进度条宽度）
    return Container(
      width: double.infinity,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xB8000000), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 22,
            ),
            onPressed: widget.onTogglePlay,
          ),
          Expanded(child: _buildSlider(context)),
          Text(
            timeStr,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
          const SizedBox(width: 4),
          if (widget.onToggleDanmaku != null) _buildDanmakuBtns(compact: true),
          TvInkWell(
            onTap: widget.onSpeed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Text(
                '${widget.currentSpeed}x',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.fullscreen_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: widget.onToggleFull,
          ),
        ],
      ),
    );
  }
}
