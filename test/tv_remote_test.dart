import 'package:ecohub_android/common/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecohub_android/tv/tv_controls.dart';
import 'package:ecohub_android/components/player/danmaku/danmaku_controller.dart';
import 'package:ecohub_android/components/player/danmaku/danmaku_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.select]) {
    testWidgets('remote $key activates a poster without touching', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvTap(
              onTap: () => taps++,
              child: const SizedBox(
                width: 160,
                height: 90,
                child: Text('poster'),
              ),
            ),
          ),
        ),
      );
      final focus = tester.widget<InkWell>(find.byType(InkWell));
      // The directional system must be able to focus this previously touch-only target.
      expect(focus.canRequestFocus, isTrue);
      FocusScope.of(tester.element(find.byType(TvTap))).nextFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
      expect(taps, 1);
      final decorated = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(TvFocusRing),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (decorated.foregroundDecoration as BoxDecoration).border!.top.color,
        AppTheme.accent,
      );
    });
  }

  testWidgets(
    'video surface supports pause, seek, menu and gives buttons their arrows',
    (tester) async {
      var toggles = 0, settings = 0, shown = 0, buttons = 0;
      final seeks = <int>[];
      final holds = <bool>[];
      final playCommands = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvRemotePlayer(
              onTogglePlay: () => toggles++,
              onControlsFocusChanged: holds.add,
              onSetPlaying: playCommands.add,
              onSeekSeconds: seeks.add,
              onShowControls: () => shown++,
              onSettings: () => settings++,
              child: Column(
                children: [
                  const Text('video'),
                  TextButton(
                    onPressed: () => buttons++,
                    child: const Text('control'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      expect(toggles, 1);
      expect(seeks, [10, -10]);
      expect(settings, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.mediaPause);
      await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlay);
      expect(playCommands, [false, true]);
      expect(toggles, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(buttons, 1);
      expect(holds, contains(true));
      expect(toggles, 1);
      expect(shown, greaterThan(0));
    },
  );

  testWidgets('remote focus scrolls an offscreen item into view', (
    tester,
  ) async {
    final target = FocusNode();
    addTearDown(target.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 140,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 600),
                  TvInkWell(
                    focusNode: target,
                    onTap: () {},
                    child: const SizedBox(height: 60, child: Text('last')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    target.requestFocus();
    await tester.pumpAndSettle();
    final y = tester.getTopLeft(find.text('last')).dy;
    expect(y, lessThan(140));
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV settings receives focus and remote opens manual search', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = DanmakuController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => DanmakuSheet.show(context, controller: c),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('danmaku-search-query')), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Back closes the route without passing a playback seek to the video.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
