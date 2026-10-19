import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_window.dart';

class DesktopShortcuts extends StatelessWidget {
  final Widget child;
  final VoidCallback onSearch, onHistory;
  const DesktopShortcuts({
    super.key,
    required this.child,
    required this.onSearch,
    required this.onHistory,
  });
  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.keyK, control: true): () async {
        await AppWindow.exitMini();
        onSearch();
      },
      const SingleActivator(LogicalKeyboardKey.keyH, control: true): () async {
        await AppWindow.exitMini();
        onHistory();
      },
      const SingleActivator(LogicalKeyboardKey.f11): AppWindow.toggleFullscreen,
    },
    child: child,
  );
}
