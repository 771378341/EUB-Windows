import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ecohub_android/utils/server_config_manager.dart';
import 'package:ecohub_android/components/player/danmaku/danmaku_api.dart';

void main() {
  test(
    'first launch presets both requested sources and keeps cleared/custom settings',
    () async {
      SharedPreferences.setMockInitialValues({});
      final manager = ServerConfigManager.instance;
      await manager.init();
      await manager.ensureDefaultServer();
      expect(
        await manager.getServerUrl(),
        'https://eco.fe-spark.cn/api/provide/app',
      );
      expect(await DanmakuApi.loadBaseUrl(), 'https://danmu.cynn.top/cynnsq');
      await manager.setServerUrl('https://custom.example/api');
      await manager.ensureDefaultServer();
      expect(await manager.getServerUrl(), 'https://custom.example/api');
      await manager.clearServerUrl();
      await manager.ensureDefaultServer();
      expect(await manager.getServerUrl(), isEmpty);
    },
  );
  test('existing user source is preserved on upgrade', () async {
    SharedPreferences.setMockInitialValues({
      'server_base_url': 'https://custom.example/api',
    });
    final manager = ServerConfigManager.instance;
    await manager.init();
    await manager.ensureDefaultServer();
    expect(await manager.getServerUrl(), 'https://custom.example/api');
  });
}
