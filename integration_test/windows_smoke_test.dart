import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:video_player/video_player.dart';
import 'package:window_manager/window_manager.dart';
import 'package:ecohub_android/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Windows launches, toggles fullscreen and decodes H264',
      (tester) async {
    expect(Platform.isWindows, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    // Native video setup schedules texture creation after a Flutter frame.
    // Keep pumping while plugin futures are pending; awaiting them without
    // frames deadlocks this integration test even though startup succeeds.
    Future<void> nativeStep(String label, Future<void> Function() action) async {
      debugPrint('WINDOWS_SMOKE START: $label');
      var complete = false;
      Object? failure;
      await tester.runAsync(() async {
        action().then<void>((_) {
          complete = true;
        }, onError: (Object error, StackTrace stack) {
          failure = error;
          complete = true;
        });
      });
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (!complete && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      if (!complete) {
        throw TimeoutException('Windows smoke: $label');
      }
      if (failure != null) {
        throw TestFailure('Windows smoke $label failed: $failure');
      }
      final error = tester.takeException();
      if (error != null) {
        throw TestFailure('Windows smoke $label failed: $error');
      }
      debugPrint('WINDOWS_SMOKE PASS: $label');
    }

    await nativeStep('application startup', app.main);
    await tester.pump();
    expect(find.byType(app.EcoHubApp), findsOneWidget);
    // Remove the network-dependent splash before testing local playback.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    await nativeStep('enter fullscreen', () async {
      await windowManager.setFullScreen(true);
      expect(await windowManager.isFullScreen(), isTrue);
    });
    await nativeStep('leave fullscreen', () async {
      await windowManager.setFullScreen(false);
      expect(await windowManager.isFullScreen(), isFalse);
    });

    const path = String.fromEnvironment('EUB_TEST_MEDIA_PATH');
    expect(path, isNotEmpty);
    expect(File(path).existsSync(), isTrue);
    final controller = VideoPlayerController.file(File(path));
    try {
      await nativeStep('initialize local H264', () async {
        await controller.initialize();
        expect(controller.value.duration, greaterThan(Duration.zero));
        expect(controller.value.size.width, 320);
      });
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: VideoPlayer(controller))),
      );
      await nativeStep('play local H264', () async {
        await controller.play();
        final deadline = DateTime.now().add(const Duration(seconds: 10));
        while (DateTime.now().isBefore(deadline)) {
          final position = await controller.position;
          if (position != null && position > Duration.zero) {
            await controller.pause();
            return;
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        throw TestFailure('Local H264 playback position did not advance.');
      });
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await nativeStep('dispose decoder', controller.dispose);
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
