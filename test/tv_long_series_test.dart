import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecohub_android/common/app_theme.dart';
import 'package:ecohub_android/models/film_models.dart';
import 'package:ecohub_android/tv/tv_episode_sheet.dart';

PlaySource series(int count) => PlaySource(
  id: 'A',
  sourceId: 'A',
  name: '默认',
  linkList: List.generate(
    count,
    (i) =>
        MovieUrlInfo(episode: '第${i + 1}集', link: 'https://example.com/$i.mp4'),
  ),
);
Future<void> open(
  WidgetTester tester,
  void Function(String, int) selected, {
  int index = 0,
  Size size = const Size(960, 540),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => TvEpisodeSheet.show(
              context,
              title: '千集动漫',
              sources: [series(1503)],
              playingSourceId: 'A',
              episodeIndex: index,
              onSelect: selected,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'latest locates the final partial page and waits for confirmation',
    (tester) async {
      int? selected;
      await open(tester, (_, i) => selected = i);
      await tester.tap(find.text('最新一集'));
      await tester.pumpAndSettle();
      expect(find.text('1501–1503 / 共1503集 ▾'), findsOneWidget);
      expect(selected, isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, 1502);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('jump accepts four digit episode and focuses the exact item', (
    tester,
  ) async {
    int? selected;
    await open(tester, (_, i) => selected = i);
    await tester.tap(find.text('跳转集数'));
    await tester.pumpAndSettle();
    for (final key in [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit7,
    ]) {
      await tester.sendKeyEvent(key);
    }
    await tester.pumpAndSettle();
    expect(find.text('第1287集'), findsOneWidget);
    await tester.tap(find.text('定位'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(find.text('1281–1300 / 共1503集 ▾'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, 1286);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'range grid reaches episode 1001 with fourteen directional moves',
    (tester) async {
      int? selected;
      await open(tester, (_, i) => selected = i);
      await tester.tap(find.text('1–20 / 共1503集 ▾'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 12; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      for (var i = 0; i < 2; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('1001–1020 / 共1503集 ▾'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, 1000);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'numeric keypad supports remote input and invalid range stays open on small TV',
    (tester) async {
      await open(tester, (_, _) {}, size: const Size(640, 360));
      await tester.tap(find.text('跳转集数'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter); // focused 1
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter); // 2
      await tester.pumpAndSettle();
      expect(find.text('第12集'), findsOneWidget);
      await tester.tap(find.text('清空'));
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.digit9);
      }
      await tester.pumpAndSettle();
      expect(find.text('请输入1–1503之间的集数'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '定位'))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
