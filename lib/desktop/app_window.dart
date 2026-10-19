import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Native Windows window integration. Other platforms keep their existing UI.
class AppWindow {
  static bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  static Future<void> initialize() async {
    if (!isWindows) return;
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1280, 800),
        minimumSize: Size(960, 600),
        center: true,
        title: 'EUB弹幕',
        backgroundColor: Color(0xFF0B0F12),
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  static Future<void> setFullscreen(bool full) async {
    if (!isWindows) return;
    try {
      await windowManager.setFullScreen(full);
    } catch (error) {
      debugPrint('Unable to change window fullscreen: $error');
    }
  }

  static Future<void> toggleFullscreen() async {
    if (!isWindows) return;
    await setFullscreen(!await windowManager.isFullScreen());
  }
}
