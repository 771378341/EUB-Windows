import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Native Windows window integration. Other platforms keep their existing UI.
class AppWindow {
  static const normalMinimum = Size(640, 400);
  static const miniMinimum = Size(320, 180);
  static const miniSize = Size(480, 270);
  static final pinned = ValueNotifier<bool>(false);
  static final isMini = ValueNotifier<bool>(false);
  static final busy = ValueNotifier<bool>(false);
  static final changes = Listenable.merge([pinned, isMini, busy]);
  static Rect? _normalBounds;
  static bool _restoreMaximized = false;
  static bool _restorePinned = false;
  static Future<void> _transition = Future<void>.value();

  static bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static Future<void> initialize() async {
    if (!isWindows) return;
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1280, 800),
        minimumSize: normalMinimum,
        center: true,
        title: 'EUB弹幕',
        backgroundColor: Color(0xFF0B0F12),
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
    pinned.value = await windowManager.isAlwaysOnTop();
  }

  // Serialize changes so a quick second click, navigation or disposal cannot
  // leave a borderless Mini window behind after its player has closed.
  static Future<void> _run(Future<void> Function() action) {
    if (!isWindows) return Future<void>.value();
    final next = _transition.catchError((Object error) {
      debugPrint('Previous window operation failed: $error');
    }).then((_) async {
      busy.value = true;
      try {
        await action();
      } finally {
        busy.value = false;
      }
    });
    _transition = next;
    return next;
  }

  static Future<void> setPinned(bool value) => _run(() async {
    await windowManager.setAlwaysOnTop(value);
    pinned.value = value;
    if (isMini.value) _restorePinned = value;
  });

  static Future<void> togglePin() => _run(() async {
    final value = !await windowManager.isAlwaysOnTop();
    await windowManager.setAlwaysOnTop(value);
    pinned.value = value;
    if (isMini.value) _restorePinned = value;
  });

  static Future<void> _enterMini() async {
    if (isMini.value) return;
    if (await windowManager.isFullScreen()) {
      await windowManager.setFullScreen(false);
    }
    _restoreMaximized = await windowManager.isMaximized();
    if (_restoreMaximized) await windowManager.unmaximize();
    _normalBounds = await windowManager.getBounds();
    _restorePinned = await windowManager.isAlwaysOnTop();
    await windowManager.setMinimumSize(miniMinimum);
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden, windowButtonVisibility: false,
    );
    await windowManager.setResizable(true);
    await windowManager.setBounds(Rect.fromCenter(
      center: _normalBounds!.center,
      width: miniSize.width,
      height: miniSize.height,
    ));
    await windowManager.setAlwaysOnTop(true);
    pinned.value = true;
    isMini.value = true;
  }

  static Future<void> _leaveMini() async {
    if (!isMini.value) return;
    await windowManager.setTitleBarStyle(
      TitleBarStyle.normal, windowButtonVisibility: true,
    );
    await windowManager.setMinimumSize(normalMinimum);
    if (_normalBounds != null) {
      await windowManager.setBounds(_normalBounds!);
    }
    if (_restoreMaximized) await windowManager.maximize();
    await windowManager.setAlwaysOnTop(_restorePinned);
    pinned.value = _restorePinned;
    isMini.value = false;
  }

  static Future<void> enterMini() => _run(_enterMini);
  static Future<void> exitMini() => _run(_leaveMini);
  static Future<void> toggleMini() => _run(
    () => isMini.value ? _leaveMini() : _enterMini(),
  );

  static Future<void> setFullscreen(bool full) => _run(() async {
    if (full) await _leaveMini();
    await windowManager.setFullScreen(full);
  });

  static Future<void> toggleFullscreen() => _run(() async {
    if (isMini.value) await _leaveMini();
    await windowManager.setFullScreen(!await windowManager.isFullScreen());
  });
}
