# EUB弹幕 Windows 0.1.0 测试版

发布日期：2026-10-19。适用 Windows 10/11 x64。

## 安装与运行

- 安装版：运行 EUBDanmaku-0.1.0-Windows-x64-setup.exe，按提示安装。默认安装到当前用户目录。
- 便携版：将 EUBDanmaku-0.1.0-Windows-x64-portable.zip 完整解压，再运行 EUBDanmaku.exe。必须保留 data 文件夹和所有 DLL，不能单独复制 EXE。
- 安装与卸载界面尚未做人工实机检查。本测试版未签名。

## 键鼠操作

空格暂停/播放；左右方向键前后跳转 10 秒；上下方向键调整应用内音量；M 静音；双击视频或按 F/F11 切换全屏；Esc 退出视频全屏；Ctrl+K 搜索；Ctrl+H 打开历史。输入文字或操作按钮时，播放器快捷键会避让。

## 已验证与限制

GitHub Windows 构建成功，265 项单元/组件测试通过，修改文件静态检查通过。Windows 原生测试完成窗口启动、进入和退出全屏、本地 H.264 视频初始化、播放进度前进和解码器释放。Release 程序、便携 ZIP 和 Inno Setup 安装程序均已生成。

本测试版采用软件解码及软件视频渲染，避免硬件解码设备不可用导致视频无法打开；高分辨率视频 CPU 占用可能偏高。远程视频源、弹幕同步、长时间连续播放、安装升级与卸载仍待用户电脑验证。

源代码和许可证包含在源码压缩包内。原项目 PolyForm Noncommercial 许可证保持不变；Windows 播放桥接部分保留 media-kit 的 MIT 许可。手机端和 TV 端各自版本不受影响。

## 构建溯源

二进制对应提交：2675c0fe912339816e3feb2b9ba8a27fe247aeb7。
构建记录：https://github.com/771378341/EUB-Windows/actions/runs/39212589047
源码仓库：https://github.com/771378341/EUB-Windows

SHA256SUMS.txt 是 CI 生成的安装包和便携版校验值，下载后可用 PowerShell Get-FileHash -Algorithm SHA256 核对。

重新构建和后续合并上游的流程见 WINDOWS-README.md。此归档保留测试代码、打包脚本、工作流、许可证及构建日志。
