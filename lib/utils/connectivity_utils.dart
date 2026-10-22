import 'package:PiliPlus/tv/tv_platform.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

abstract final class ConnectivityUtils {
  static Future<bool> get isWiFi async {
    try {
      if (!PlatformUtils.isMobile && !TvPlatform.isTv) return false;
      final results = await Connectivity().checkConnectivity();
      return results.contains(ConnectivityResult.wifi) ||
          (TvPlatform.isTv && results.contains(ConnectivityResult.ethernet));
    } catch (_) {
      return true;
    }
  }
}
