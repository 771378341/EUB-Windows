# EUB弹幕 Windows 0.1.1 测试版

发布日期：2026-10-19。适用 Windows 10/11 x64。

## 本次更新

- 播放页顶部增加置顶与 Mini 小窗按钮。
- 普通窗口最小尺寸由 960×600 改为 640×400。
- Mini 默认 480×270，最小 320×180，隐藏系统标题栏；拖动片名区域可移动窗口。
- Mini 默认置顶，可手动取消。退出时恢复原来的窗口大小、最大化状态和置顶偏好。
- 小窗底部采用紧凑控制栏；更多菜单提供速度、比例、弹幕设置、选集和全屏。
- Esc 或恢复窗口按钮退出 Mini；F/F11 可从 Mini 进入全屏。搜索、历史和退出播放页时恢复普通窗口。

## 下载与安装

下载：https://github.com/771378341/EUB-Windows/actions/runs/39218460920/artifacts/12171250938

GitHub 下载包名为 EUB-Windows-build-output，解压后运行 EUBDanmaku-0.1.1-Windows-x64-setup.exe。安装前关闭旧版本。便携用户请完整解压内含的 EUBDanmaku-0.1.1-Windows-x64-portable.zip，保留 data 文件夹及所有 DLL。

程序未签名。安装升级、不同显示缩放比例和远程视频源仍需用户电脑验证。

## 验证与构建溯源

静态检查通过；268 项单元/组件测试及 1 项 Windows 原生集成测试通过。原生测试包含窗口启动、全屏切换、置顶、Mini 尺寸和窗口状态恢复、本地 H.264 播放及切换 Mini 后继续播放。

Release 程序、便携 ZIP、Inno Setup 安装包、SHA256SUMS.txt 和构建日志均已生成。

二进制对应提交：68228f1db08e5c396cecec380ae7366c45334e25
构建记录：https://github.com/771378341/EUB-Windows/actions/runs/39218460920
源码仓库：https://github.com/771378341/EUB-Windows
Actions 下载包 SHA-256：f962f3fbd02d1994607a18c3856133fff8bebf9e1f3beb571a284063d06a90aa

本版本继续使用软件解码和软件视频渲染；高分辨率播放可能增加 CPU 占用。原项目 PolyForm Noncommercial 许可证及 Windows 播放桥接的 MIT 许可均保留。后续构建与合并上游流程见 WINDOWS-README.md。

此版本已保存到 GitHub，尚未同步 Google Drive；原 0.1.0 归档保留。
