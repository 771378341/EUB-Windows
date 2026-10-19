import '../../desktop/app_window.dart';
import '../../desktop/player_input.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'player_gesture_handler.dart';
import 'player_skin_view.dart';
import 'player_speed_sheet.dart';
import 'player_scale.dart';
import 'player_pip_coordinator.dart';
import 'player_video_surface.dart';
import 'player_playback_controller.dart';
import '../cast/player_cast_controller.dart';
import 'danmaku/danmaku_controller.dart';
import 'danmaku/danmaku_layer.dart';
import 'danmaku/danmaku_sheet.dart';
import '../cast/player_cast_hud.dart';
import '../../types/dlna_types.dart';

/// 跨平台视频播放器，全量对齐 OHOS `VideoPlayer.ets`
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String poster;
  final double initialTime;
  final bool showBack;
  final bool isFull;
  final bool hasPrev;
  final bool hasNext;
  final bool pageActive;
  final bool edgeHud;
  final int reloadToken;
  final double topInset;
  final double leftInset;
  final double rightInset;
  final double bottomInset;
  final VoidCallback? onBack;
  final bool backExitsPage;
  final VoidCallback? onOpenEpisodes;
  final VoidCallback? onEnded;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final void Function(bool full, {bool isPortrait})? onFullscreenChange;
  final void Function(double current, double duration)? onProgress;
  // 弹幕匹配用：剧名 / 集数（1-based，0=电影或未知）/ 是否剧集
  final String danmakuTitle;
  final int danmakuEpisode;
  final bool danmakuIsSeries;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.title = '',
    this.poster = '',
    this.initialTime = 0,
    this.showBack = false,
    this.isFull = false,
    this.hasPrev = false,
    this.hasNext = false,
    this.pageActive = true,
    this.edgeHud = false,
    this.reloadToken = 0,
    this.topInset = 0,
    this.leftInset = 0,
    this.rightInset = 0,
    this.bottomInset = 0,
    this.onBack,
    this.backExitsPage = false,
    this.onOpenEpisodes,
    this.onEnded,
    this.onPrev,
    this.onNext,
    this.onFullscreenChange,
    this.onProgress,
    this.danmakuTitle = '',
    this.danmakuEpisode = 0,
    this.danmakuIsSeries = false,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget>
    with WidgetsBindingObserver
    implements PlayerCastHost {
  final PlayerPlaybackController _playback = PlayerPlaybackController();
  final PlayerCastController _castCtrl = PlayerCastController();
  final DanmakuController _danmaku = DanmakuController();
  late final PlayerPipCoordinator _pipCoord;

  int _lastCastPersistMs = 0;
  DanmakuStatus? _lastDmStatus;

  @override
  double get currentPosition => _castCtrl.isCasting
      ? _castCtrl.session.positionSec
      : _playback.currentPositionSec;
  @override
  double get totalDuration => _castCtrl.isCasting
      ? (_castCtrl.session.durationSec > 0
            ? _castCtrl.session.durationSec
            : _playback.totalDurationSec)
      : _playback.totalDurationSec;
  @override
  bool get isPlaying => _castCtrl.isCasting
      ? (_castCtrl.session.phase == CastPhase.playing)
      : _playback.isPlaying;
  @override
  bool get isOpening => _playback.isOpening;
  @override
  bool get isBuffering => _playback.isBuffering;
  @override
  String get videoUrl => widget.videoUrl;
  @override
  String get title => widget.title;
  @override
  bool get hasNext => widget.hasNext;
  @override
  double get volume => _playback.volume;
  @override
  bool get isFull => widget.isFull;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _castCtrl.attachHost(this);
    _playback.onEnded = widget.onEnded;
    _playback.onProgress = (cur, dur) {
      if (!_castCtrl.isCasting) {
        widget.onProgress?.call(cur, dur);
      }
    };
    _playback.onStateChanged = () {
      _syncAutoPip();
      _pipCoord.updateAspectRatio(_playback.controller?.value.size);
    };

    _pipCoord = PlayerPipCoordinator(
      onStateChanged: () {
        if (mounted) setState(() {});
        if (!_pipCoord.isPipActive) _syncAutoPip();
      },
      onPlay: () {
        if (!_castCtrl.isCasting) {
          _playback.play();
        }
      },
      onPause: () {
        if (!_castCtrl.isCasting) {
          _playback.pause();
        }
      },
      onPrev: widget.onPrev,
      onNext: widget.onNext,
    )..init();

    _playback.loadWindowLevels();
    _playback.initPlayer(widget.videoUrl, initialTime: widget.initialTime);
    _danmaku.addListener(_onDanmakuStatus);
    _danmaku.init(
      videoUrl: widget.videoUrl,
      title: widget.danmakuTitle,
      episode: widget.danmakuEpisode,
      isSeries: widget.danmakuIsSeries,
    );
  }

  Timer? _danmakuNoticeTimer;
  String? _danmakuNotice;

  void _showDanmakuNotice(String message) {
    _danmakuNoticeTimer?.cancel();
    setState(() => _danmakuNotice = message);
    _danmakuNoticeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _danmakuNotice = null);
    });
  }

  void _onDanmakuStatus() {
    final s = _danmaku.status;
    if (s == _lastDmStatus) return;
    _lastDmStatus = s;
    if (!mounted) return;
    if (s == DanmakuStatus.loading) {
      _danmakuNoticeTimer?.cancel();
      if (_danmakuNotice != null) setState(() => _danmakuNotice = null);
    } else if (s == DanmakuStatus.ready) {
      final src = _danmaku.currentSource;
      final platform = src != null ? '（${src.platformName}）' : '';
      _showDanmakuNotice('${_danmaku.remoteCount} 条弹幕$platform');
    } else if (s == DanmakuStatus.empty) {
      _showDanmakuNotice('暂无弹幕');
    }
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _playback.onEnded = widget.onEnded;
    if (oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.reloadToken != widget.reloadToken) {
      if (_castCtrl.isCasting) {
        final consumed = _castCtrl.handleSourceChange();
        if (!consumed) {
          _playback.initPlayer(widget.videoUrl);
        }
      } else {
        _playback.initPlayer(widget.videoUrl);
      }
      _danmaku.switchVideo(
        videoUrl: widget.videoUrl,
        title: widget.danmakuTitle,
        episode: widget.danmakuEpisode,
        isSeries: widget.danmakuIsSeries,
      );
    }
    if (oldWidget.hasPrev != widget.hasPrev ||
        oldWidget.hasNext != widget.hasNext) {
      _syncAutoPip();
    }
  }

  @override
  void dispose() {
    if (AppWindow.isWindows) unawaited(AppWindow.exitMini());
    _danmakuNoticeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _pipCoord.dispose();
    _castCtrl.dispose();
    _playback.dispose();
    _danmaku.dispose();
    super.dispose();
  }

  void _syncAutoPip() {
    _pipCoord.syncAutoPip(
      isCasting: _castCtrl.isCasting,
      videoUrl: widget.videoUrl,
      errorText: _playback.errorText,
      isPlaying: _playback.isPlaying,
      isCompleted: _playback.isCompleted,
      hasPrev: widget.hasPrev,
      hasNext: widget.hasNext,
      videoSize: _playback.controller?.value.size,
    );
  }

  bool _isPortraitVideo() {
    final c = _playback.controller;
    if (c == null || !c.value.isInitialized) return false;
    final size = c.value.size;
    final rot = c.value.rotationCorrection;
    final isRotated = rot == 90 || rot == 270;
    final w = isRotated ? size.height : size.width;
    final h = isRotated ? size.width : size.height;
    if (w > 0 && h > 0) {
      return h > w;
    }
    final aspect = c.value.aspectRatio;
    return aspect > 0 && aspect < 1.0;
  }

  void _toggleFullscreen() {
    if (_castCtrl.isCasting) {
      showToast('投屏中无法全屏，请先停止投屏');
      return;
    }
    widget.onFullscreenChange?.call(
      !widget.isFull,
      isPortrait: _isPortraitVideo(),
    );
  }

  @override
  void parkLocal() {
    _playback.parkForCast();
    _syncAutoPip();
  }

  @override
  void pauseLocal() {
    _playback.pauseLocal();
    _syncAutoPip();
  }

  @override
  void exitFullForCast() {
    if (widget.isFull) {
      widget.onFullscreenChange?.call(false, isPortrait: _isPortraitVideo());
    }
  }

  @override
  void resumeLocal(double targetSec, bool wasPlaying) {
    // 投屏选择器取消时本地播放器仍在：只 seek/play，避免 initPlayer 导致画面重载。
    // 仍在打开中也不要重挂，否则会打断进行中的 initialize。
    final c = _playback.controller;
    if ((c != null && c.value.isInitialized) || _playback.isOpening) {
      _playback.resumeLocal(targetSec, wasPlaying);
    } else {
      _playback.initPlayer(
        widget.videoUrl,
        initialTime: targetSec,
        autoPlay: wasPlaying,
      );
    }
    _syncAutoPip();
  }

  @override
  void remountCompleted(double positionSec, double durationSec) {
    _playback.remountCompleted(positionSec, durationSec);
    _syncAutoPip();
  }

  @override
  void onCastEnded() => widget.onEnded?.call();

  @override
  void syncUi() {
    if (mounted) setState(() {});
  }

  @override
  void syncProgress(double currentSec, double durationSec) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (widget.onProgress != null && durationSec > 0) {
      if (now - _lastCastPersistMs >= 5000) {
        _lastCastPersistMs = now;
        widget.onProgress!(currentSec, durationSec);
      }
    }
  }

  @override
  void showToast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  void setPipAutoStart(bool enable) {
    _syncAutoPip();
  }

  @override
  void stopPip() {}

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _playback,
      builder: (context, _) {
        final pickerOpen = _castCtrl.pausedForPicker && !_castCtrl.isCasting;
        if (_pipCoord.isPipActive) {
          return Container(
            color: Colors.black,
            child: PlayerVideoSurface(
              controller: _playback.controller,
              scaleMode: _playback.scaleMode,
              poster: widget.poster,
              isOpening: _playback.isOpening,
              isReady: _playback.isReady,
            ),
          );
        }

        return PlayerInput(
          isFullscreen: widget.isFull,
          onToggleFullscreen: _toggleFullscreen,
          onExitFullscreen: () => widget.onFullscreenChange?.call(
            false,
            isPortrait: _isPortraitVideo(),
          ),
          onToggleMute: _playback.toggleMute,
          onAdjustVolume: (delta) {
            if (_castCtrl.isCasting) return;
            _playback.setVolume(_playback.volume + delta);
            _playback.showTransient(
              PlayerPanState(
                kind: PlayerTipKind.volume,
                text: '音量 ${(_playback.volume * 100).round()}%',
              ),
            );
          },
          onTogglePlay: () {
            if (!_castCtrl.isCasting) _playback.togglePlay();
          },
          onSeekSeconds: (seconds) {
            if (!_castCtrl.isCasting) {
              _playback.seekTo(
                Duration(
                  milliseconds:
                      (_playback.currentPosition.inMilliseconds +
                              seconds * 1000)
                          .clamp(0, _playback.totalDuration.inMilliseconds),
                ),
              );
            }
          },
          onControlsFocusChanged: _playback.setControlsFocused,
          onSetPlaying: (playing) {
            if (!_castCtrl.isCasting && _playback.isPlaying != playing) {
              _playback.togglePlay();
            }
          },
          onShowControls: _playback.showControls,
          onSettings:
              widget.onOpenEpisodes ??
              () => DanmakuSheet.show(context, controller: _danmaku),
          onOpenEpisodes: widget.onOpenEpisodes,
          child: Container(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PlayerGestureHandler(
                  currentPosition: _playback.currentPosition,
                  totalDuration: _playback.totalDuration,
                  isPlaying: _playback.isPlaying,
                  isFull: widget.isFull,
                  currentSpeed: _playback.currentSpeed,
                  currentBrightness: _playback.brightness,
                  currentVolume: _playback.volume,
                  onSingleTap: _playback.toggleHud,
                  onDoubleTap: () {
                    if (AppWindow.isWindows) {
                      _toggleFullscreen();
                    } else if (!_castCtrl.isCasting) {
                      _playback.togglePlay();
                    }
                  },
                  onSeekProgress: _playback.setDragPreview,
                  onSeekEnd: _playback.seekTo,
                  onSpeedChange: _playback.setSpeed,
                  onBrightnessChange: _playback.setBrightness,
                  onVolumeChange: (v) {
                    _playback.setVolume(v);
                    if (_castCtrl.isCasting) {
                      _castCtrl.pushCastVolume(v);
                    }
                  },
                  onPanStateChange: _playback.setPanState,
                  child: PlayerVideoSurface(
                    controller: _playback.controller,
                    scaleMode: _playback.scaleMode,
                    poster: widget.poster,
                    isOpening: _playback.isOpening,
                    isReady: _playback.isReady,
                  ),
                ),
                if (_castCtrl.deviceName.isNotEmpty && !widget.isFull)
                  Center(
                    child: PlayerCastHud(
                      deviceName: _castCtrl.deviceName,
                      positionSec: _castCtrl.session.positionSec,
                      durationSec: _castCtrl.session.durationSec > 0
                          ? _castCtrl.session.durationSec
                          : totalDuration,
                      phase: _castCtrl.session.phase,
                      transportState: _castCtrl.session.transportState,
                      castSession: _castCtrl.session,
                      onStopCast: () => _castCtrl.endCastByUser(),
                    ),
                  ),
                // 弹幕层：视频之上、控制条之下；投屏/画中画时隐藏
                if (!_castCtrl.isCasting && !_pipCoord.isPipActive)
                  ListenableBuilder(
                    listenable: _danmaku,
                    builder: (context, _) {
                      if (!_danmaku.enabled) return const SizedBox.shrink();
                      return Positioned.fill(
                        child: IgnorePointer(
                          child: DanmakuLayer(
                            controller: _danmaku,
                            playback: _playback,
                            positionSec: () => _playback.currentPositionSec,
                            speed: () => _playback.currentSpeed,
                            isPlaying: () =>
                                _playback.isPlaying &&
                                !_playback.isBuffering &&
                                !_playback.isSeeking,
                            seekRevision: () => _playback.seekRevision,
                          ),
                        ),
                      );
                    },
                  ),
                ListenableBuilder(
                  listenable: _danmaku,
                  builder: (context, _) => PlayerSkinView(
                    isFull: widget.isFull,
                    edgeHud: widget.edgeHud,
                    showHud: _playback.showHud || pickerOpen,
                    showBack: widget.showBack,
                    title: widget.title,
                    isPlaying: _castCtrl.isCasting
                        ? (_castCtrl.session.phase == CastPhase.playing)
                        : _playback.isPlaying,
                    isBuffering: _castCtrl.isCasting
                        ? (_castCtrl.session.phase == CastPhase.launching)
                        : _playback.isBuffering,
                    isOpening: _castCtrl.isCasting
                        ? false
                        : _playback.isOpening,
                    pickerOpen: pickerOpen,
                    loadSessionId: _playback.initSessionId,
                    isReady: _castCtrl.isCasting ? true : _playback.isReady,
                    isCompleted: _castCtrl.isCasting
                        ? false
                        : _playback.isCompleted,
                    muted: _playback.muted,
                    errorText: _playback.errorText,
                    currentPosition: _castCtrl.isCasting
                        ? Duration(
                            seconds: _castCtrl.session.positionSec.toInt(),
                          )
                        : _playback.displayPosition,
                    totalDuration: _castCtrl.isCasting
                        ? (_castCtrl.session.durationSec > 0
                              ? Duration(
                                  seconds: _castCtrl.session.durationSec
                                      .toInt(),
                                )
                              : _playback.totalDuration)
                        : _playback.totalDuration,
                    currentSpeed: _playback.currentSpeed,
                    scaleLabel: PlayerScale.label(_playback.scaleMode),
                    hasPrev: widget.hasPrev,
                    hasNext: widget.hasNext,
                    panState: _playback.panState,
                    topInset: widget.topInset,
                    leftInset: widget.leftInset,
                    rightInset: widget.rightInset,
                    bottomInset: widget.bottomInset,
                    castDeviceName: _castCtrl.deviceName,
                    canCast: false,
                    onBack: () {
                      if (widget.backExitsPage) {
                        widget.onBack?.call();
                      } else if (widget.isFull) {
                        _toggleFullscreen();
                      } else {
                        widget.onBack?.call();
                      }
                    },
                    onTogglePlay: () {
                      if (!_castCtrl.isCasting) {
                        if (_playback.controller == null &&
                            _playback.isCompleted) {
                          _playback.initPlayer(
                            widget.videoUrl,
                            initialTime: 0,
                            autoPlay: true,
                          );
                        } else {
                          _playback.togglePlay();
                        }
                      }
                    },
                    onToggleFull: _toggleFullscreen,
                    onToggleMute: () {
                      _playback.toggleMute();
                      if (_castCtrl.isCasting) {
                        _castCtrl.pushCastVolume(
                          _playback.muted ? 0.0 : _playback.volume,
                        );
                      }
                    },
                    onSpeed: () => PlayerSpeedSheet.show(
                      context,
                      _playback.currentSpeed,
                      _playback.setSpeed,
                    ),
                    onScale: _playback.cycleScale,
                    onRetry: () {
                      if (!_castCtrl.isCasting) {
                        _playback.initPlayer(widget.videoUrl);
                      }
                    },
                    onPrev: widget.onPrev,
                    onNext: widget.onNext,
                    onSeekBack10: () {
                      final target = Duration(
                        seconds: (currentPosition - 10)
                            .clamp(0, totalDuration)
                            .toInt(),
                      );
                      _playback.seekTo(target);
                    },
                    onSeekFwd10: () {
                      final target = Duration(
                        seconds: (currentPosition + 10)
                            .clamp(0, totalDuration)
                            .toInt(),
                      );
                      _playback.seekTo(target);
                    },
                    onSeekStart: _playback.setDragPreview,
                    onSeekProgress: _playback.setDragPreview,
                    onSeekTo: _playback.seekTo,
                    onCast: () => _castCtrl.openCastDialog(context),
                    onStopCast: () => _castCtrl.endCastByUser(),
                    onPip: null,
                    onOpenEpisodes: widget.onOpenEpisodes,
                    danmakuEnabled: _danmaku.enabled,
                    onToggleDanmaku: () => _danmaku.toggle(),
                    onOpenDanmakuSettings: () =>
                        DanmakuSheet.show(context, controller: _danmaku),
                  ),
                ),
                if (_danmakuNotice != null)
                  Positioned(
                    top: widget.topInset + (_playback.showHud ? 48 : 10),
                    left: 12,
                    right: 12,
                    child: IgnorePointer(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.62),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _danmakuNotice!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
