import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ecohub_android/components/player/danmaku/danmaku_api.dart';
import 'package:ecohub_android/pages/danmaku_api_settings_page.dart';

void main() {
  testWidgets('validates, saves persistently and restores the API address', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: DanmakuApiSettingsPage()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'not a url');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.textContaining('请输入完整'), findsOneWidget);
    expect(await DanmakuApi.loadBaseUrl(), DanmakuApi.defaultBaseUrl);
    await tester.enterText(
      find.byType(TextFormField),
      'https://example.com/danmaku/',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(await DanmakuApi.loadBaseUrl(), 'https://example.com/danmaku');
    await tester.tap(find.text('恢复默认'));
    await tester.pumpAndSettle();
    expect(await DanmakuApi.loadBaseUrl(), DanmakuApi.defaultBaseUrl);
    expect(find.text(DanmakuApi.defaultBaseUrl), findsOneWidget);
  });
}
