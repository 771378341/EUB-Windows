import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:video_player/video_player.dart';
import 'package:window_manager/window_manager.dart';
import 'package:ecohub_android/main.dart' as app;
import 'package:ecohub_android/desktop/app_window.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Windows launches, toggles fullscreen and decodes H264', (
    tester,
  ) async {
    expect(
      Platform.isWindows,
      isTrue,
      reason: 'Run this integration test on Windows.',
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await app.main();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(app.EcoHubApp), findsOneWidget);
    await AppWindow.setFullscreen(true);
    expect(await windowManager.isFullScreen(), isTrue);
    await AppWindow.setFullscreen(false);
    expect(await windowManager.isFullScreen(), isFalse);
    const path = String.fromEnvironment('EUB_TEST_MEDIA_PATH');
    expect(path, isNotEmpty);
    final c = VideoPlayerController.file(File(path));
    try {
      await c.initialize();
      expect(c.value.duration, greaterThan(Duration.zero));
      expect(c.value.size.width, 320);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: VideoPlayer(c))),
      );
      await c.play();
      await tester.pump(const Duration(milliseconds: 900));
      expect(c.value.position, greaterThan(Duration.zero));
      await c.pause();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await c.dispose();
    }
  });
}
