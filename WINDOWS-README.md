# EUB弹幕 Windows 开发预览版 0.1.0

状态：2026-10-19 已在 GitHub Windows 环境完成 Release 编译和安装包生成。265 项单元/组件测试及 1 项 Windows 原生窗口、全屏、本地 H.264 播放测试通过。版本仍为 0.1.0 测试版，安装/卸载和远程视频源仍需在用户电脑上验证。

本测试版使用软件解码和软件视频渲染，兼容没有可用硬件解码设备的 Windows 环境；高分辨率播放会增加 CPU 占用。构建记录：https://github.com/771378341/EUB-Windows/actions/runs/39212589047 。

## 适配内容

以 EUBTV v1.1.3 业务源码为基础，增加 Windows 原生窗口及 media_kit 播放后端。保留现有搜索、弹幕、播放源、选集、历史记录等业务代码；这些功能在 Windows 的实际表现仍待原生验证。桌面默认窗口 1280×800，最小 960×600，采用紧凑字号。

鼠标悬停显示控制栏，双击视频切换全屏。空格暂停/播放，左右方向键前后跳转 10 秒，上下方向键调整应用内音量，M 静音，F/F11 全屏，Esc 退出视频全屏，Ctrl+K 搜索，Ctrl+H 历史。编辑文本、操作按钮或打开弹窗时，播放器快捷键会避让。

Windows 不提供 Android 自动画中画设置；“清理图片内存”仅清理 Flutter 图片内存，不删除磁盘缓存、历史或配置。原有远程播放源配置未更换。窗口标题为 EUB弹幕，程序名 EUBDanmaku.exe。

## 本地生成安装包

需要 Windows 10/11 x64、Git for Windows、Visual Studio 2022 的“使用 C++ 的桌面开发”工作负载和 Windows SDK。生成安装程序另需 Inno Setup 6.3 或更新版本。

解压源码，在项目根目录打开 PowerShell：

```powershell
powershell -ExecutionPolicy Bypass -File .\toolsuild-windows.ps1 -Installer
```

脚本会下载并校验固定版本 Flutter 3.47.3 SDK（首次下载较大），使用 pubspec.lock，运行静态检查、全部单元/组件测试以及 Windows 原生冒烟测试，再编译 Release。SDK 保存到本机 LOCALAPPDATA 下 EUBBuild 目录。

原生冒烟测试会启动应用窗口、切换全屏，并解码随源码提供的本地 H.264 测试视频。它必须在 Windows 上通过。产物在 dist：便携 ZIP、setup.exe、SHA256SUMS.txt 和构建日志。便携版必须完整解压，保留 data 目录及所有 DLL，不能只复制 EXE。

安装程序使用当前用户安装，无需管理员权限；安装标识 EUB.Danmaku.Windows。未配置代码签名证书；分发前还需检查 Windows 实机安装、卸载和网络播放。

## GitHub 云端构建

连接 GitHub 后，将本项目完整内容提交到自己的仓库根目录，包含 .github/workflows/build-windows.yml。Actions 中手动运行 Build EUB Windows。工作流支持手动触发及主分支相关代码和测试文件变更触发，使用 windows-2022，不会自动发布公开下载或创建 Release。

构建成功后，从对应运行的 Artifacts 下载 EUB-Windows-build-output，内含 dist 文件。若运行失败，只能将日志作为失败记录，不能将其视为已完成安装包。源码仓库：https://github.com/771378341/EUB-Windows 。本测试版二进制对应提交 2675c0fe912339816e3feb2b9ba8a27fe247aeb7。

## 版本与维护

本开发分支版本为 0.1.0+1，与 Android 手机端和 TV 端各自独立递增，不覆盖现有 APK。Dart 包名 ecohub_android 为兼容现有导入而保留。

Windows 直接新增依赖：video_player_media_kit 2.0.0、media_kit_libs_windows_video 1.0.11、window_manager 0.5.2。所有解析版本以 pubspec.lock 为准。

后续 EcoHub 或 EUBTV 更新：先保留此版本归档，再以独立分支合并上游业务修复；保留 lib/desktop、Windows 播放初始化、平台判断、音量/全屏适配、鼠标键盘处理、Windows runner、打包脚本及工作流。不要直接覆盖整个 lib 或 pubspec.yaml。审查依赖与迁移后，重新执行脚本中的检查，并在 Windows 上验证弹幕同步、搜索、选源、千集跳转、播放历史、全屏返回、安装升级及卸载。依赖更新应单独修改锁文件并验证，不能绕过锁定失败。

源码许可证保持原项目 PolyForm Noncommercial 1.0.0（见 LICENSE）；上游说明保存在 docs/UPSTREAM-README.md。打包脚本收集播放组件许可文件，分发前仍需审核完整第三方许可。此工程不包含 Android 私密签名文件或服务器凭据。
