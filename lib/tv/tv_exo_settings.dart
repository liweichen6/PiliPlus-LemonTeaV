// The settings' descriptions on TV, where ExoPlayer plays every video and
// live room (docs/tv/PLAN.md, M17.9; M17.6, decisions 10 and 13). Upstream's
// describe mpv's options, which don't apply there. Each getter is `null`
// (or empty) off TV, so upstream's text stands.
import 'package:PiliPlus/tv/tv_exo_player.dart';
import 'package:PiliPlus/tv/tv_platform.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class TvExoSettings {
  /// This device's Java heap limit in bytes (`Runtime.maxMemory()`), read
  /// once from the bridge at start-up; `null` until then or if it can't be.
  static int? heapLimit;

  /// Reads [heapLimit] from the bridge. Called once on TV at start-up.
  static Future<void> load() async {
    try {
      heapLimit = await TvExoPlayer.channel.invokeMethod<int>('heapLimit');
    } on PlatformException catch (e) {
      debugPrint('[TvExoSettings] heapLimit failed: ${e.message}');
    } on MissingPluginException {
      // No bridge (tests).
    }
  }

  @visibleForTesting
  static String heapNote(int? heapLimit) {
    final mb = heapLimit == null ? null : heapLimit ~/ 0x100000;
    return mb == null
        ? 'ExoPlayer 的缓冲占用 Java 堆，设得过大会内存不足'
        : 'ExoPlayer 的缓冲占用 Java 堆，本机上限 $mb MB，设得过大会内存不足';
  }

  static String _mb(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

  /// 缓冲大小 on TV.
  static String? get bufferSize => TvPlatform.isTv
      ? '当前：${_mb(Pref.bufferSize)}MB。点播视频的前向缓冲上限，不保留后向缓冲；'
            '实际缓冲为大小与时长二者的最小值。${heapNote(heapLimit)}。'
            '直播流请设置下方的直播缓冲大小'
      : null;

  /// 缓冲时长 on TV.
  static String? get bufferSec => TvPlatform.isTv
      ? '当前：${_mb(Pref.bufferSec)}s。点播视频的前向缓冲时长上限，'
            '实际缓冲为大小与时长二者的最小值。${heapNote(heapLimit)}。'
            '直播流请设置下方的直播缓冲时长'
      : null;

  /// 直播缓冲大小 on TV.
  static String? get liveBufferSize {
    if (!TvPlatform.isTv) return null;
    final size = Pref.liveBufferSize;
    final current = size > 0
        ? '${_mb(size)}MB'
        : '跟随缓冲大小（${_mb(Pref.bufferSize * 2)}MB）';
    return '当前：$current。仅对直播流生效，小于等于0时使用缓冲大小的2倍。'
        '${heapNote(heapLimit)}';
  }

  /// 直播缓冲时长 on TV.
  static String? get liveBufferSec {
    if (!TvPlatform.isTv) return null;
    final sec = Pref.liveBufferSec;
    final current = sec > 0 ? '${_mb(sec)}s' : '不限制';
    return '当前：$current。仅对直播流生效，大于0时限制直播缓冲时长以降低延迟。'
        '${heapNote(heapLimit)}';
  }

  /// Appended to 音量均衡's description on TV; empty elsewhere.
  static String get normalizationNote => TvPlatform.isTv
      ? '\nExoPlayer 上「自定义参数」不生效，按关闭处理；'
            '杜比全景声和 E-AC-3 直通到电视的音频输出，不做均衡'
      : '';
}
