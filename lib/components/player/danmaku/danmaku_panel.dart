import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'danmaku_controller.dart';

/// One consistent surface for playback settings, search and episode selection.
class DanmakuPanel extends StatelessWidget {
  final DanmakuController controller;
  final Widget child;
  const DanmakuPanel({
    super.key,
    required this.controller,
    required this.child,
  });

  static Future<T?> show<T>(BuildContext context, Widget child) =>
      showGeneralDialog<T>(
        context: context,
        barrierDismissible: true,
        barrierLabel: '关闭弹幕面板',
        barrierColor: const Color(0x10000000),
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, _, _) => child,
        transitionBuilder: (context, animation, secondary, child) =>
            FadeTransition(opacity: animation, child: child),
      );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final landscape = media.size.width > media.size.height;
    final available = math.max(
      0.0,
      media.size.height - media.viewInsets.bottom - media.padding.vertical,
    );
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SafeArea(
          child: Align(
            alignment: landscape
                ? Alignment.centerRight
                : Alignment.bottomCenter,
            child: SizedBox(
              key: const ValueKey('danmaku-panel'),
              width: landscape
                  ? math.min(400, media.size.width * 0.46)
                  : media.size.width,
              height: landscape ? available : math.min(540, available * 0.85),
              child: Material(
                color: const Color(
                  0xFF17191F,
                ).withValues(alpha: controller.panelOpacity),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: Radius.circular(landscape ? 0 : 16),
                  bottomLeft: Radius.circular(landscape ? 16 : 0),
                ),
                clipBehavior: Clip.antiAlias,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    textTheme: Theme.of(context).textTheme.apply(
                      bodyColor: Colors.white,
                      displayColor: Colors.white,
                    ),
                    iconTheme: const IconThemeData(
                      color: Colors.white70,
                      size: 20,
                    ),
                    listTileTheme: const ListTileThemeData(
                      dense: true,
                      minLeadingWidth: 20,
                      horizontalTitleGap: 10,
                    ),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
