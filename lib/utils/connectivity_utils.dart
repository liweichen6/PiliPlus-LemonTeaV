import 'dart:io' show Platform;

import 'package:PiliPlus/tv/tv_platform.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:nm/nm.dart';

abstract final class ConnectivityUtils {
  static Future<bool> get isWiFi async {
    try {
      if (Platform.isLinux) {
        final client = NetworkManagerClient();
        try {
          await client.connect();
          return switch (client.metered) {
            NetworkManagerMetered.yes ||
            NetworkManagerMetered.guessYes => false,
            _ => true,
          };
        } finally {
          await client.close();
        }
      }
      if (!PlatformUtils.isMobile && !TvPlatform.isTv) return false;
      final results = await Connectivity().checkConnectivity();
      return results.contains(ConnectivityResult.wifi) ||
          (TvPlatform.isTv && results.contains(ConnectivityResult.ethernet));
    } catch (_) {
      return true;
    }
  }
}
