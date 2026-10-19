import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'app_window.dart';

/// Playback window actions; the native title bar remains in normal mode.
class DesktopWindowButtons extends StatelessWidget {
  const DesktopWindowButtons({super.key});

  Future<void> _act(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('窗口操作未完成，请重试')),
        );
      }
      debugPrint('Window action failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: AppWindow.changes,
    builder: (context, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const ValueKey('desktop-pin'),
          tooltip: AppWindow.pinned.value ? '取消置顶' : '置顶',
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          padding: EdgeInsets.zero,
          onPressed: AppWindow.busy.value
              ? null : () => _act(context, AppWindow.togglePin),
          icon: Icon(
            AppWindow.pinned.value ? Icons.push_pin : Icons.push_pin_outlined,
            size: 18,
            color: AppWindow.pinned.value ? const Color(0xFFFF9818) : Colors.white,
          ),
        ),
        IconButton(
          key: const ValueKey('desktop-mini'),
          tooltip: AppWindow.isMini.value ? '恢复窗口' : 'Mini 小窗',
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          padding: EdgeInsets.zero,
          onPressed: AppWindow.busy.value
              ? null : () => _act(context, AppWindow.toggleMini),
          icon: Icon(
            AppWindow.isMini.value
                ? Icons.open_in_full_rounded : Icons.picture_in_picture_alt,
            size: 19, color: Colors.white,
          ),
        ),
        if (AppWindow.isMini.value)
          IconButton(
            tooltip: '最小化',
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            padding: EdgeInsets.zero,
            onPressed: () => _act(context, windowManager.minimize),
            icon: const Icon(Icons.minimize, size: 18, color: Colors.white),
          ),
      ],
    ),
  );
}
