import 'package:PiliPlus/pages/login/controller.dart';
import 'package:PiliPlus/tv/adapters/tv_focus_adapter.dart';
import 'package:PiliPlus/tv/tv_platform.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// The login page: a remote is no use for typing a password, so `/loginPage`
/// opens on `扫码登录` on TV, via `Get.find<LoginPageController>()` without
/// touching `lib/pages/login/`.
final class TvLoginAdapter extends TvFocusAdapter {
  const TvLoginAdapter();

  /// Index of the `扫码` tab in [LoginPageController.tabController]
  /// (`密码` / `短信` / `扫码` / `Cookie`). The controller's own QR polling keys
  /// on the same index; a test reads both upstream files and fails if the tab
  /// order or that index moves.
  static const int qrTabIndex = 2;

  static void _switchToQrTab({int remainingRetries = 2}) {
    if (!TvPlatform.isTv) return;
    if (Get.isRegistered<LoginPageController>()) {
      final LoginPageController ctr = Get.find<LoginPageController>();
      if (ctr.tabController.index != qrTabIndex) {
        ctr.tabController.animateTo(qrTabIndex);
      }
      return;
    }
    if (remainingRetries > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _switchToQrTab(remainingRetries: remainingRetries - 1);
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  @override
  void didPushRoute(Route<dynamic> route) {
    if (route.settings.name == '/loginPage') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _switchToQrTab();
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }
}
