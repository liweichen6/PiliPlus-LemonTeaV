import 'dart:async';

import 'package:PiliPlus/common/widgets/flutter/list_tile.dart';
import 'package:PiliPlus/tv/tv_platform.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart' hide ListTile;

/// Leaving and restarting the app on a TV.
///
/// Upstream's Back on the home tab only shows the launcher, so the process
/// keeps running, and Android TV has no recents screen to close it from. On a
/// TV that Back asks `返回桌面` / `退出应用` instead, and 关于 gets `重启应用`
/// for the settings that say `重启生效`.
abstract final class TvAppExit {
  static const MethodChannel _channel = MethodChannel(
    'com.example.piliplus/tv',
  );

  // Widget keys, for tests.
  static const Key exitDialogKey = ValueKey<String>('tvExit:dialog');
  static const Key desktopKey = ValueKey<String>('tvExit:desktop');
  static const Key exitKey = ValueKey<String>('tvExit:exit');
  static const Key restartTileKey = ValueKey<String>('tvExit:restartTile');
  static const Key restartDialogKey = ValueKey<String>('tvExit:restartDialog');
  static const Key restartConfirmKey = ValueKey<String>('tvExit:restart');
  static const Key restartCancelKey = ValueKey<String>('tvExit:cancel');

  static bool _dialogOpen = false;

  /// The hook in upstream's home-tab Back (`_onBack` in
  /// `lib/pages/main/view.dart`). Returns `false` off a TV, so upstream's own
  /// Back runs; on a TV it opens the exit dialog and returns `true`.
  static bool handleHomeBack() {
    if (!TvPlatform.isTv) return false;
    final BuildContext? context = Get.context;
    if (context == null) return false;
    if (_dialogOpen) return true;
    _dialogOpen = true;
    showDialog<void>(
      context: context,
      builder: (_) => const _TvExitDialog(),
    ).whenComplete(() => _dialogOpen = false);
    return true;
  }

  /// `重启应用`, the last row of 关于 on a TV.
  static Widget restartTile(BuildContext context) => ListTile(
    key: restartTileKey,
    title: const Text('重启应用'),
    leading: const Icon(Icons.restart_alt_rounded),
    onTap: () => showDialog<void>(
      context: context,
      builder: (_) => const _TvRestartDialog(),
    ),
  );

  static Future<bool> _invoke(String method) async {
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } catch (_) {
      return false;
    }
  }
}

class _TvExitDialog extends StatelessWidget {
  const _TvExitDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: TvAppExit.exitDialogKey,
      title: const Text('退出 PiliPlus？'),
      content: const Text('返回桌面时应用继续在后台运行'),
      actions: [
        TextButton(
          key: TvAppExit.desktopKey,
          autofocus: true,
          onPressed: () {
            Navigator.of(context).pop();
            TvAppExit._invoke('goHome');
          },
          child: const Text('返回桌面'),
        ),
        TextButton(
          key: TvAppExit.exitKey,
          onPressed: () async {
            if (!await TvAppExit._invoke('exitApp') && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('退出应用'),
        ),
      ],
    );
  }
}

class _TvRestartDialog extends StatelessWidget {
  const _TvRestartDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: TvAppExit.restartDialogKey,
      title: const Text('重启应用？'),
      content: const Text('重新启动后，需要重启生效的设置会生效'),
      actions: [
        TextButton(
          key: TvAppExit.restartCancelKey,
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          key: TvAppExit.restartConfirmKey,
          onPressed: () async {
            if (!await TvAppExit._invoke('restartApp') && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('重启'),
        ),
      ],
    );
  }
}
