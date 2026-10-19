import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ecohub_android/utils/app_version_util.dart';

void main() {
  test('custom build never offers incompatible upstream APKs', () async {
    PackageInfo.setMockInitialValues(
      appName: 'EUB弹幕',
      packageName: 'com.eub.danmaku',
      version: '1.0.0',
      buildNumber: '7',
      buildSignature: 'test',
    );
    var requests = 0;
    await http.runWithClient(
      () async {
        final info = await AppVersionUtil.checkUpdate(force: true);
        expect(info.hasUpdate, isFalse);
        expect(AppVersionUtil.hasUpdate.value, isFalse);
        expect(info.downloadUrl, isEmpty);
        expect(requests, 0);
      },
      () => MockClient((_) async {
        requests++;
        return http.Response('[]', 200);
      }),
    );
    expect(AppVersionUtil.supportsOfficialUpdates('1.0.0'), isFalse);
    expect(
      AppVersionUtil.supportsOfficialUpdates(
        '1.0.2',
        packageName: 'com.ecohub.ecohub',
      ),
      isTrue,
    );
    expect(
      AppVersionUtil.supportsOfficialUpdates(
        '1.0.2-beta',
        packageName: 'com.ecohub.ecohub',
      ),
      isTrue,
    );
  });
}
