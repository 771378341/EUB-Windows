import 'package:flutter/material.dart';

import '../common/app_theme.dart';

import 'package:flutter/services.dart';

/// Visible remote focus, without changing layout or the size of a hit target.
class TvFocusRing extends StatefulWidget {
  final Widget child;
  const TvFocusRing({super.key, required this.child});
  @override
  State<TvFocusRing> createState() => _TvFocusRingState();
}

class _TvFocusRingState extends State<TvFocusRing> {
  bool focused = false;
  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onFocusChange: (value) {
      setState(() => focused = value);
      if (value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && focused) {
            Scrollable.ensureVisible(
              context,
              duration: const Duration(milliseconds: 140),
              alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
            );
          }
        });
      }
    },
    child: Container(
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: focused ? AppTheme.accent : Colors.transparent,
          width: 2.5,
        ),
      ),
      child: widget.child,
    ),
  );
}

/// Touch-only targets receive the same keyboard activation as Material buttons.
class TvTap extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget? child;
  final HitTestBehavior? behavior;
  const TvTap({super.key, this.onTap, this.child, this.behavior});
  @override
  Widget build(BuildContext context) => TvFocusRing(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: child,
    ),
  );
}

class TvInkWell extends InkWell {
  const TvInkWell({
    super.key,
    super.child,
    super.onTap,
    super.onLongPress,
    super.borderRadius,
    super.customBorder,
    super.autofocus,
    super.focusNode,
    super.onFocusChange,
  });
  @override
  Widget build(BuildContext context) =>
      TvFocusRing(child: super.build(context));
}

/// Key events are scoped to this player. A dialog or text field keeps its keys.
class TvRemotePlayer extends StatefulWidget {
  final Widget child;
  final VoidCallback onTogglePlay;
  final ValueChanged<int> onSeekSeconds;
  final VoidCallback onShowControls;
  final VoidCallback onSettings;
  final VoidCallback? onOpenEpisodes;
  final ValueChanged<bool>? onSetPlaying;
  final ValueChanged<bool>? onControlsFocusChanged;
  const TvRemotePlayer({
    super.key,
    required this.child,
    required this.onTogglePlay,
    required this.onSeekSeconds,
    required this.onShowControls,
    required this.onSettings,
    this.onOpenEpisodes,
    this.onSetPlaying,
    this.onControlsFocusChanged,
  });
  @override
  State<TvRemotePlayer> createState() => _TvRemotePlayerState();
}

class _TvRemotePlayerState extends State<TvRemotePlayer> {
  final node = FocusNode(debugLabel: 'TV video surface');
  bool _holding = false;
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_focusChanged);
  }

  void _focusChanged() {
    final held = node.hasFocus && !node.hasPrimaryFocus;
    if (held != _holding) {
      _holding = held;
      widget.onControlsFocusChanged?.call(held);
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
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.mediaPlayPause) {
      if (event is KeyDownEvent) widget.onTogglePlay();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPlay ||
        key == LogicalKeyboardKey.mediaPause) {
      if (event is KeyDownEvent) {
        widget.onSetPlaying?.call(key == LogicalKeyboardKey.mediaPlay);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.contextMenu) {
      if (event is KeyDownEvent) widget.onSettings();
      return KeyEventResult.handled;
    }
    if (!node.hasPrimaryFocus) {
      // Let sliders and buttons receive directional keys normally.
      widget.onShowControls();
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) widget.onTogglePlay();
      widget.onShowControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.mediaRewind ||
        key == LogicalKeyboardKey.mediaFastForward) {
      widget.onSeekSeconds(
        key == LogicalKeyboardKey.arrowLeft ||
                key == LogicalKeyboardKey.mediaRewind
            ? -10
            : 10,
      );
      widget.onShowControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown && widget.onOpenEpisodes != null) {
      if (event is KeyDownEvent) widget.onOpenEpisodes!();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      widget.onShowControls();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && node.hasPrimaryFocus) node.nextFocus();
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: node,
    autofocus: true,
    onKeyEvent: _onKey,
    child: widget.child,
  );
}
