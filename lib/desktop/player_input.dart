import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tv/tv_controls.dart';
import 'app_window.dart';

/// Keeps TV navigation intact while using familiar desktop playback keys.
class PlayerInput extends StatelessWidget {
  final Widget child;
  final VoidCallback onTogglePlay, onShowControls, onSettings;
  final ValueChanged<int> onSeekSeconds;
  final ValueChanged<bool>? onSetPlaying, onControlsFocusChanged;
  final VoidCallback? onOpenEpisodes;
  final VoidCallback onToggleFullscreen, onExitFullscreen, onToggleMute;
  final ValueChanged<double> onAdjustVolume;
  final bool isFullscreen;
  const PlayerInput({
    super.key,
    required this.child,
    required this.onTogglePlay,
    required this.onShowControls,
    required this.onSettings,
    required this.onSeekSeconds,
    this.onSetPlaying,
    this.onControlsFocusChanged,
    this.onOpenEpisodes,
    required this.onToggleFullscreen,
    required this.onExitFullscreen,
    required this.onToggleMute,
    required this.onAdjustVolume,
    required this.isFullscreen,
  });
  @override
  Widget build(BuildContext context) => AppWindow.isWindows
      ? DesktopPlayerInput(
          onTogglePlay: onTogglePlay,
          onShowControls: onShowControls,
          onSeekSeconds: onSeekSeconds,
          onToggleFullscreen: onToggleFullscreen,
          onExitFullscreen: onExitFullscreen,
          onToggleMute: onToggleMute,
          onAdjustVolume: onAdjustVolume,
          isFullscreen: isFullscreen,
          onControlsFocusChanged: onControlsFocusChanged,
          child: child,
        )
      : TvRemotePlayer(
          onTogglePlay: onTogglePlay,
          onShowControls: onShowControls,
          onSeekSeconds: onSeekSeconds,
          onSettings: onSettings,
          onSetPlaying: onSetPlaying,
          onControlsFocusChanged: onControlsFocusChanged,
          onOpenEpisodes: onOpenEpisodes,
          child: child,
        );
}

class DesktopPlayerInput extends StatefulWidget {
  static void focusVideoSurface(BuildContext context) {
    context
        .findAncestorStateOfType<_DesktopPlayerInputState>()
        ?.node
        .requestFocus();
  }

  final Widget child;
  final VoidCallback onTogglePlay,
      onShowControls,
      onToggleFullscreen,
      onExitFullscreen,
      onToggleMute;
  final ValueChanged<int> onSeekSeconds;
  final ValueChanged<double> onAdjustVolume;
  final ValueChanged<bool>? onControlsFocusChanged;
  final bool isFullscreen;
  const DesktopPlayerInput({
    super.key,
    required this.child,
    required this.onTogglePlay,
    required this.onShowControls,
    required this.onToggleFullscreen,
    required this.onExitFullscreen,
    required this.onToggleMute,
    required this.onSeekSeconds,
    required this.onAdjustVolume,
    required this.isFullscreen,
    this.onControlsFocusChanged,
  });
  @override
  State<DesktopPlayerInput> createState() => _DesktopPlayerInputState();
}

class _DesktopPlayerInputState extends State<DesktopPlayerInput> {
  final node = FocusNode(debugLabel: 'Desktop video');
  bool held = false;
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_focusChanged);
  }

  void _focusChanged() {
    final next = node.hasFocus && !node.hasPrimaryFocus;
    if (held != next) {
      held = next;
      widget.onControlsFocusChanged?.call(next);
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_focusChanged);
    node.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is KeyUpEvent || ModalRoute.of(context)?.isCurrent == false) {
      return KeyEventResult.ignored;
    }
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext?.widget is EditableText ||
        focusContext?.findAncestorWidgetOfExactType<EditableText>() != null) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.f11 || key == LogicalKeyboardKey.keyF) {
      if (event is KeyDownEvent) widget.onToggleFullscreen();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && widget.isFullscreen) {
      if (event is KeyDownEvent) widget.onExitFullscreen();
      return KeyEventResult.handled;
    }
    if (!node.hasPrimaryFocus) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      if (event is KeyDownEvent) widget.onTogglePlay();
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      widget.onSeekSeconds(key == LogicalKeyboardKey.arrowLeft ? -10 : 10);
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      widget.onAdjustVolume(key == LogicalKeyboardKey.arrowUp ? 0.05 : -0.05);
    } else if (key == LogicalKeyboardKey.keyM) {
      if (event is KeyDownEvent) widget.onToggleMute();
    } else {
      return KeyEventResult.ignored;
    }
    widget.onShowControls();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: node,
    autofocus: true,
    onKeyEvent: _onKey,
    child: MouseRegion(
      onHover: (_) => widget.onShowControls(),
      child: widget.child,
    ),
  );
}
