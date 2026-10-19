import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'danmaku_clock.dart';
import 'danmaku_controller.dart';
import 'danmaku_item.dart';

/// Repaints only the isolated overlay; no per-frame widget rebuild/layout.
class DanmakuLayer extends StatefulWidget {
  final DanmakuController controller;
  final double Function() positionSec;
  final double Function() speed;
  final bool Function() isPlaying;
  final int Function()? seekRevision;
  final Listenable? playback;

  const DanmakuLayer({
    super.key,
    required this.controller,
    required this.positionSec,
    required this.speed,
    required this.isPlaying,
    this.seekRevision,
    this.playback,
  });

  @override
  State<DanmakuLayer> createState() => _DanmakuLayerState();
}

class _ActiveItem {
  final DanmakuItem item;
  final TextPainter painter;
  final double startMs;
  final int row;
  double x;
  _ActiveItem(this.item, this.painter, this.startMs, this.row, this.x);
}

class _DanmakuLayerState extends State<DanmakuLayer>
    with SingleTickerProviderStateMixin {
  final _clock = DanmakuClock();
  final _repaint = ValueNotifier<int>(0);
  final List<_ActiveItem> _active = [];
  late final Ticker _ticker;
  Size _viewSize = Size.zero;
  int _cursor = 0;
  int _seekRevision = 0;
  Duration _frame = Duration.zero;
  List<DanmakuItem>? _lastItems;
  double _fontSize = 0;
  double _area = 0;
  bool _enabled = true;

  bool get _visible =>
      widget.controller.enabled &&
      (widget.controller.status == DanmakuStatus.ready ||
          widget.controller.status == DanmakuStatus.empty);
  int get _rows =>
      ((_viewSize.height * widget.controller.area) /
              (widget.controller.fontSize * 1.6))
          .floor()
          .clamp(1, 16);

  @override
  void initState() {
    super.initState();
    _lastItems = widget.controller.items;
    _fontSize = widget.controller.fontSize;
    _area = widget.controller.area;
    _enabled = widget.controller.enabled;
    _seekRevision = widget.seekRevision?.call() ?? 0;
    widget.controller.addListener(_onController);
    _ticker = createTicker(_tick);
    widget.playback?.addListener(_onPlayback);
    _updateTicker();
  }

  @override
  void didUpdateWidget(covariant DanmakuLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playback != widget.playback) {
      oldWidget.playback?.removeListener(_onPlayback);
      widget.playback?.addListener(_onPlayback);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onController);
      widget.controller.addListener(_onController);
      _lastItems = null;
      _onController();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    widget.playback?.removeListener(_onPlayback);
    widget.controller.removeListener(_onController);
    _clear();
    _repaint.dispose();
    super.dispose();
  }

  void _clear() {
    for (final a in _active) {
      a.painter.dispose();
    }
    _active.clear();
  }

  int _lowerBound(double ms) {
    final items = widget.controller.items;
    var lo = 0, hi = items.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (items[mid].timeMs < ms) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  void _resetStage() {
    _clear();
    // Never replay a whole episode's backlog after loading/seeking.
    _cursor = _lowerBound(_clock.positionMs - 250);
  }

  void _onController() {
    final c = widget.controller;
    if (!identical(_lastItems, c.items) ||
        _fontSize != c.fontSize ||
        _area != c.area ||
        _enabled != c.enabled) {
      _clock.reset(widget.positionSec() * 1000, _frame);
      _resetStage();
    }
    _lastItems = c.items;
    _fontSize = c.fontSize;
    _area = c.area;
    _enabled = c.enabled;
    _updateTicker();
    if (mounted) setState(() {}); // Settings/loading only, never each frame.
  }

  void _updateTicker() {
    final shouldRun =
        _visible && (widget.playback == null || widget.isPlaying());
    if (shouldRun && !_ticker.isActive) {
      _frame = Duration.zero;
      _clock.reset(widget.positionSec() * 1000, Duration.zero);
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onPlayback() {
    final revision = widget.seekRevision?.call() ?? 0;
    if (revision != _seekRevision) {
      _seekRevision = revision;
      _clock.reset(widget.positionSec() * 1000, _frame);
      _resetStage();
      _repaint.value++;
    }
    _updateTicker();
  }

  void _tick(Duration elapsed) {
    _frame = elapsed;
    final revision = widget.seekRevision?.call() ?? 0;
    final hadActive = _active.isNotEmpty;
    final before = _clock.positionMs;
    final reset = _clock.update(
      rawMs: widget.positionSec() * 1000,
      frame: elapsed,
      playing: widget.isPlaying(),
      speed: widget.speed().clamp(0.25, 4.0),
      seek: revision != _seekRevision,
    );
    _seekRevision = revision;
    if (reset) _resetStage();
    if (!_visible || _viewSize.isEmpty) return;
    final delta = reset ? 0.0 : (_clock.positionMs - before).clamp(0.0, 1500.0);
    // A common velocity prevents wide comments catching narrow comments.
    final velocity =
        (_viewSize.width + 200) / 9000 * widget.controller.danmakuSpeed;
    for (final a in _active) {
      if (a.item.type == DanmakuType.scroll) a.x -= delta * velocity;
    }
    _active.removeWhere((a) {
      final done = a.item.type == DanmakuType.scroll
          ? a.x + a.painter.width < 0
          : _clock.positionMs - a.startMs >= 4000;
      if (done) a.painter.dispose();
      return done;
    });
    if (widget.isPlaying()) _spawnDue();
    if (hadActive || _active.isNotEmpty) _repaint.value++;
  }

  void _spawnDue() {
    final items = widget.controller.items;
    final now = _clock.positionMs;
    if (_cursor < items.length && items[_cursor].timeMs < now - 1000) {
      _cursor = _lowerBound(now - 250);
    }
    var budget = 24;
    while (_cursor < items.length && items[_cursor].timeMs <= now) {
      if (_active.length >= 48 || budget-- <= 0) {
        _cursor = _lowerBound(now + 0.001); // Drop excess, never build a queue.
        break;
      }
      final item = items[_cursor++];
      var row = -1;
      for (var r = 0; r < _rows; r++) {
        final occupied = _active.any(
          (a) =>
              a.item.type == item.type &&
              a.row == r &&
              (item.type != DanmakuType.scroll ||
                  a.x + a.painter.width + 24 > _viewSize.width),
        );
        if (!occupied) {
          row = r;
          break;
        }
      }
      if (row < 0) continue;
      final painter = TextPainter(
        text: TextSpan(
          text: item.text,
          style: TextStyle(
            fontSize: widget.controller.fontSize,
            color: Color(item.color),
            shadows: const [
              Shadow(
                color: Colors.black87,
                blurRadius: 1,
                offset: Offset(1, 1),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      if (painter.width <= 0) {
        painter.dispose();
        continue;
      }
      _active.add(_ActiveItem(item, painter, now, row, _viewSize.width));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size != _viewSize) {
          _viewSize = size;
          _resetStage();
        }
        return Opacity(
          opacity: widget.controller.opacity,
          child: RepaintBoundary(
            child: ClipRect(
              child: CustomPaint(
                painter: _DanmakuPainter(this, _repaint),
                size: Size.infinite,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DanmakuPainter extends CustomPainter {
  final _DanmakuLayerState layer;
  _DanmakuPainter(this.layer, Listenable repaint) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final rowH = layer.widget.controller.fontSize * 1.6;
    for (final a in layer._active) {
      final x = a.item.type == DanmakuType.scroll
          ? a.x
          : (size.width - a.painter.width) / 2;
      final y = a.item.type == DanmakuType.bottom
          ? size.height - (a.row + 1) * rowH
          : a.row * rowH + (rowH - a.painter.height) / 2;
      a.painter.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(covariant _DanmakuPainter oldDelegate) => true;
}
