// The settings' descriptions on TV, where ExoPlayer plays every video and
// live room (docs/tv/PLAN.md, M17.9; M17.6, decisions 10 and 13). Upstream's
// describe mpv's options, which don't apply there. Each getter is `null`
// (or empty) off TV, so upstream's text stands.
import 'package:PiliPlus/models/common/audio_normalization.dart';
import 'package:PiliPlus/pages/setting/widgets/select_dialog.dart';
import 'package:PiliPlus/tv/tv_exo_player.dart';
import 'package:PiliPlus/tv/tv_platform.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:material_ui/material_ui.dart';
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

  // ---- 音量均衡 on TV (the user, 2026-11-16) ----
  //
  // 关闭 / 标准 (-14 LUFS) / 高动态 (-24 LUFS) / 动态压缩 / 自定义, after
  // Bilibili's web player's 关闭 / 标准 / 高动态, with upstream's dynaudnorm
  // preset as 动态压缩 and upstream's 自定义参数 as 自定义. 关闭 and 动态压缩
  // keep upstream's stored values ('0', '1'); 标准, 高动态 and 自定义 are
  // stored as filter strings, which mpv reads as 自定义参数 the same way.
  // `TvExoNormalization.resolve` maps them.

  static const String off = '0';
  static const String compress = '1';

  /// The 自定义 row's value in the dialog, as upstream's dialog uses it; what
  /// is stored is the filter typed after it.
  static const String customRow = '3';

  /// The four options, stored value and title, in the dialog's order.
  static const List<(String, String)> normalizationOptions = [
    (off, '关闭'),
    (TvExoNormalization.standard, '标准 (-14 LUFS)'),
    (TvExoNormalization.highDynamic, '高动态 (-24 LUFS)'),
    (compress, '动态压缩'),
    (customRow, '自定义'),
  ];

  /// Whether a stored value is a filter typed for 自定义 (or one upstream
  /// stored as 自定义参数), not one of the other rows.
  static bool isCustom(String value) =>
      value != '2' &&
      value != customRow &&
      !normalizationOptions.any((o) => o.$1 == value);

  static String normalizationHelp(String value) => switch (value) {
    off => '不调整音量',
    TvExoNormalization.standard => '按 B 站测得的响度，把整段视频调到 -14 LUFS，带限幅',
    TvExoNormalization.highDynamic => '调到 -24 LUFS：整体更安静，需调高电视音量；很少触发限幅，保留更多动态',
    compress => '随播放持续调整，小声处放大、大声处压低；不需要响度数据',
    customRow => 'loudnorm 的 I、TP，或 dynaudnorm 的 f、g、r、p、m',
    _ => '',
  };

  /// The title of a stored value on TV: one of the four, or upstream's for a
  /// value stored before M17.9 (预设 loudnorm, 自定义参数).
  static String normalizationTitle(String value) {
    for (final (v, title) in normalizationOptions) {
      if (v == value) return title;
    }
    if (isCustom(value)) return '自定义';
    return AudioNormalization.getTitleFromConfig(value);
  }

  /// 音量均衡's description on TV; `null` elsewhere, so upstream's stands.
  static String? get normalizationSubtitle {
    if (!TvPlatform.isTv) return null;
    return normalizationSubtitleFor(Pref.audioNormalization);
  }

  @visibleForTesting
  static String normalizationSubtitleFor(String value) {
    final title = normalizationTitle(value);
    final help = switch (value) {
      off => '',
      TvExoNormalization.standard || TvExoNormalization.highDynamic =>
        '\n${normalizationHelp(value)}。视频没有响度数据，或响度低于 -28 LUFS 时不调整',
      compress => '\n${normalizationHelp(value)}',
      // 预设 loudnorm, stored before M17.9: still plays as before.
      '2' => '\n旧设置，仍按 -16 LUFS 调整；可在此改选',
      _ when isCustom(value) => '：$value\n${_customHelp(value)}',
      _ => '',
    };
    final passthrough = value == off
        ? ''
        : '\n杜比全景声和 E-AC-3 直通到电视的音频输出，不做均衡；直播不做均衡';
    return '当前:「$title」$help$passthrough';
  }

  static String _customHelp(String value) {
    final n = TvExoNormalization.custom(value, '');
    if (RegExp('(?:^|[^a-z])loudnorm(?:[^a-z]|\$)').hasMatch(value)) {
      return '按 B 站测得的响度调到 I，TP 为限幅（缺省 -24、-2）；'
          '视频没有响度数据，或响度低于 -28 LUFS 时不调整。其他参数不生效';
    }
    if (n.mode == 'dynamic') return '按 f、g、r、p、m 动态调整，其他参数不生效';
    return '此播放器只支持 loudnorm 和 dynaudnorm，按关闭处理';
  }

  /// 音量均衡's dialog on TV: the four options, each with what it does, and
  /// no fallback to choose (标准 and 高动态 do nothing without data, as on
  /// Bilibili's web player). `null` off TV, or for upstream's fallback dialog.
  static Future<void>? normalizationDialog(
    BuildContext context,
    VoidCallback setState, {
    bool fallback = false,
  }) {
    if (!TvPlatform.isTv || fallback) return null;
    return _normalizationDialog(context, setState);
  }

  static Future<void> _normalizationDialog(
    BuildContext context,
    VoidCallback setState,
  ) async {
    final stored = Pref.audioNormalization;
    final res = await showDialog<String>(
      context: context,
      builder: (context) => SelectDialog<String>(
        title: '音量均衡',
        value: isCustom(stored) ? customRow : stored,
        values: normalizationOptions,
        subtitleBuilder: (context, index, value) =>
            Text(normalizationHelp(value)),
      ),
    );
    if (res == null || !context.mounted) return;
    var value = res;
    if (res == customRow) {
      final typed = await customDialog(
        context,
        isCustom(stored) ? stored : TvExoNormalization.standard,
      );
      if (typed == null || typed.isEmpty) return;
      value = typed;
    }
    await GStorage.setting.put(SettingBoxKey.audioNormalization, value);
    setState();
  }

  /// 自定义's text box: a filter string, starting from [initial].
  static Future<String?> customDialog(BuildContext context, String initial) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自定义'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            const Text(
              '例如 loudnorm=I=-18:TP=-1 或 dynaudnorm=f=250:g=5:p=0.5\n'
              '此播放器只读取 loudnorm 的 I、TP 和 dynaudnorm 的 f、g、r、p、m',
            ),
            TextField(controller: controller),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }
}
