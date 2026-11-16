// Why a stream can't play on ExoPlayer, in words (docs/tv/PLAN.md, M17.10:
// "Why a quality can't play"). The bridge's `supports` answers each stream
// with a reason from what the decoders declare (`TvExoPlayer.kt`, `refusal`),
// and the display's HDR types add one here. The quality row, its detail
// line, 解码格式, the fallback toast at open and the failure screen all use
// these words.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Names for a stream's `codecs` string, as Bilibili sends it
/// (`avc1.640033`, `hev1.2.4.L156.90`, `av01.0.13M.10`, `dvhe.05.07`).
abstract final class TvExoCodec {
  /// `AVC`, `HEVC`, `AV1`, `杜比视界`, or the string's first part.
  static String name(String? codecs) {
    final head = (codecs ?? '').split('.').first.toLowerCase();
    return switch (head) {
      'avc1' || 'avc3' => 'AVC',
      'hev1' || 'hvc1' => 'HEVC',
      'av01' => 'AV1',
      'dvhe' || 'dvh1' || 'dav1' || 'dva1' || 'dvav' => '杜比视界',
      '' => '未知编码',
      _ => head,
    };
  }

  /// The profile and level from the string alone: `High 5.1`, `Main 10 5.2`,
  /// `Main 10 5.1` (AV1), `Profile 5` (Dolby Vision). Empty when unknown.
  static String profileLevel(String? codecs) {
    final (profile, level) = _parse(codecs);
    return [profile, level].where((s) => s.isNotEmpty).join(' ');
  }

  /// The stream's level alone, for "HEVC 5.2 超出…"; empty when unknown.
  static String level(String? codecs) => _parse(codecs).$2;

  /// The stream's profile alone; empty when unknown.
  static String profile(String? codecs) => _parse(codecs).$1;

  static (String, String) _parse(String? codecs) {
    final parts = (codecs ?? '').split('.');
    if (parts.length < 2) return ('', '');
    switch (name(codecs)) {
      case 'AVC':
        final p = parts[1];
        if (p.length < 6) return ('', '');
        final profile = switch (p.substring(0, 2).toUpperCase()) {
          '42' => 'Baseline',
          '4D' => 'Main',
          '58' => 'Extended',
          '64' => 'High',
          '6E' => 'High 10',
          '7A' => 'High 4:2:2',
          'F4' => 'High 4:4:4',
          _ => '',
        };
        final level = int.tryParse(p.substring(4, 6), radix: 16);
        return (profile, level == null ? '' : _level(level ~/ 10, level % 10));
      case 'HEVC':
        final profile = switch (parts[1]) {
          '1' => 'Main',
          '2' => 'Main 10',
          _ => '',
        };
        final l = parts
            .skip(2)
            .firstWhere(
              (s) => s.startsWith('L') || s.startsWith('H'),
              orElse: () => '',
            );
        final n = l.length > 1 ? int.tryParse(l.substring(1)) : null;
        // `L153` is level 5.1: the level times 30.
        return (profile, n == null ? '' : _level(n ~/ 30, (n % 30) ~/ 3));
      case 'AV1':
        if (parts.length < 3) return ('', '');
        final depth = parts.length > 3 ? int.tryParse(parts[3]) : null;
        final profile = switch (parts[1]) {
          '0' => depth == 10 ? 'Main 10' : 'Main',
          '1' => 'High',
          '2' => 'Professional',
          _ => '',
        };
        final idx = int.tryParse(parts[2].replaceAll(RegExp('[A-Za-z]'), ''));
        return (profile, idx == null ? '' : _level(2 + idx ~/ 4, idx % 4));
      case '杜比视界':
        final p = int.tryParse(parts[1]);
        return (p == null ? '' : 'Profile $p', '');
    }
    return ('', '');
  }

  /// `5.1`, or `5` for 5.0, as Android's level names write it.
  static String _level(int whole, int tenth) =>
      tenth == 0 ? '$whole' : '$whole.$tenth';

  /// `HEVC Main 10 5.2`.
  static String describe(String? codecs) =>
      [name(codecs), profileLevel(codecs)].where((s) => s.isNotEmpty).join(' ');

  /// A decoder's name without `.decoder`: `c2.mtk.hevc`.
  static String decoder(String name) =>
      name.endsWith('.decoder') ? name.substring(0, name.length - 8) : name;

  // ---- Android's `MediaCodecInfo.CodecProfileLevel` numbers ----

  static const _avcLevels = [
    '1', '1b', '1.1', '1.2', '1.3', '2', '2.1', '2.2', '3', '3.1', '3.2', //
    '4', '4.1', '4.2', '5', '5.1', '5.2', '6', '6.1', '6.2',
  ];
  static const _hevcLevels = [
    '1', '2', '2.1', '3', '3.1', '4', '4.1', '5', '5.1', '5.2', '6', //
    '6.1', '6.2',
  ];
  static const _av1Levels = [
    '2', '2.1', '2.2', '2.3', '3', '3.1', '3.2', '3.3', '4', '4.1', '4.2', //
    '4.3', '5', '5.1', '5.2', '5.3', '6', '6.1', '6.2', '6.3', '7', '7.1',
    '7.2', '7.3',
  ];

  /// An Android level constant as a number, for the codec of [codecs]; each
  /// constant is one bit, in order (HEVC's alternate main and high tier).
  @visibleForTesting
  static String? androidLevel(String? codecs, int? level) {
    if (level == null || level <= 0) return null;
    final bit = (math.log(level) / math.ln2).round();
    if (1 << bit != level) return null;
    return switch (name(codecs)) {
      'AVC' => _avcLevels.elementAtOrNull(bit),
      'HEVC' => switch (_hevcLevels.elementAtOrNull(bit ~/ 2)) {
        final l? => bit.isOdd ? '$l High' : l,
        null => null,
      },
      'AV1' => _av1Levels.elementAtOrNull(bit),
      _ => null,
    };
  }

  /// An Android profile constant as a name, for the codec of [codecs].
  @visibleForTesting
  static String? androidProfile(String? codecs, int? profile) =>
      switch (name(codecs)) {
        'AVC' => const {
          1: 'Baseline',
          2: 'Main',
          4: 'Extended',
          8: 'High',
          0x10: 'High 10',
          0x20: 'High 4:2:2',
          0x40: 'High 4:4:4',
          0x10000: 'Constrained Baseline',
          0x80000: 'Constrained High',
        }[profile],
        'HEVC' => const {
          1: 'Main',
          2: 'Main 10',
          4: 'Main Still',
          0x1000: 'Main 10',
          0x2000: 'Main 10',
        }[profile],
        'AV1' => const {
          1: 'Main',
          2: 'Main 10',
          0x1000: 'Main 10',
          0x2000: 'Main 10',
        }[profile],
        _ => null,
      };
}

/// One stream: its `codecs`, size and frame rate, as the play-URL API sends
/// them.
@immutable
class TvExoStream {
  const TvExoStream({
    required this.codecs,
    this.width,
    this.height,
    this.frameRate,
  });

  final String? codecs;
  final int? width;
  final int? height;
  final double? frameRate;

  /// `3996×2160@24`, or less of it when unknown.
  String get size {
    final w = width, h = height;
    if (w == null || h == null || w <= 0 || h <= 0) return '';
    final fps = frameRate;
    return fps == null || fps <= 0 ? '$w×$h' : '$w×$h@${fps.round()}';
  }
}

/// Why a stream can't play here.
@immutable
class TvExoRefusal {
  const TvExoRefusal({
    required this.kind,
    required this.stream,
    this.decoder,
    this.maxLevel,
    this.maxWidth,
    this.maxHeight,
    this.maxFps,
    this.profile,
    this.dvProfile,
    this.dvDecoders,
    this.display,
    this.tryable = false,
  });

  /// From the bridge's `reason` map for [stream].
  factory TvExoRefusal.fromBridge(Map reason, TvExoStream stream) =>
      TvExoRefusal(
        kind: reason['kind']?.toString() ?? 'unknown',
        stream: stream,
        decoder: reason['decoder'] as String?,
        maxLevel: _int(reason['maxLevel']),
        maxWidth: _int(reason['maxWidth']),
        maxHeight: _int(reason['maxHeight']),
        maxFps: _int(reason['maxFps']),
        profile: _int(reason['profile']),
        dvProfile: _int(reason['dvProfile']),
        dvDecoders: _int(reason['dvDecoders']),
        tryable: reason['tryable'] == true,
      );

  /// The display doesn't report the HDR type [display] (`HDR10`, `HLG`,
  /// `杜比视界`).
  const TvExoRefusal.display(this.stream, String this.display)
    : kind = 'display',
      decoder = null,
      maxLevel = null,
      maxWidth = null,
      maxHeight = null,
      maxFps = null,
      profile = null,
      dvProfile = null,
      dvDecoders = null,
      tryable = false;

  static int? _int(Object? v) => v is num ? v.toInt() : null;

  /// `limit`, `noDecoder`, `dvProfile`, `profile`, `level`, `size`, `rate`,
  /// `display` or `unknown`.
  final String kind;
  final TvExoStream stream;
  final String? decoder;

  /// The decoder's highest level for the stream's profile, as Android's
  /// constant.
  final int? maxLevel;
  final int? maxWidth;
  final int? maxHeight;
  final int? maxFps;

  /// The stream's profile, as Android's constant (for `profile`).
  final int? profile;
  final int? dvProfile;
  final int? dvDecoders;
  final String? display;

  /// Whether 仍要尝试 may try it once: a decoder for the codec exists and
  /// only finds the stream past what it declares.
  final bool tryable;

  String get _codec => TvExoCodec.name(stream.codecs);

  /// ` HDR10`, ` HLG`, or `杜比视界` with no space before Chinese.
  String get _displayName {
    final d = display ?? '';
    return RegExp('^[A-Za-z]').hasMatch(d) ? ' $d' : d;
  }

  String get _streamLevel => TvExoCodec.level(stream.codecs);

  String? get _decoderLevel => TvExoCodec.androidLevel(stream.codecs, maxLevel);

  /// Without the tier, for the short reason; the detail line keeps it.
  String? get _decoderLevelShort => _decoderLevel?.replaceAll(' High', '');

  String get _profileName =>
      TvExoCodec.androidProfile(stream.codecs, profile) ??
      TvExoCodec.profile(stream.codecs);

  /// The reason, short, for a row's name and a toast:
  /// `HEVC 5.2 超出解码器 5.1`, `解码器最高 4096×2304`, `无 AV1 解码器`.
  String get short => switch (kind) {
    'limit' => '超出播放上限',
    'noDecoder' => '无 $_codec 解码器',
    'dvProfile' when (dvDecoders ?? 0) == 0 => '无杜比视界解码器',
    'dvProfile' => '无 Profile ${dvProfile ?? '?'} 解码器',
    'profile' => '解码器不支持 $_codec $_profileName'.trimRight(),
    'level' =>
      '$_codec ${_streamLevel.isEmpty ? '级别' : _streamLevel} '
          '超出解码器 ${_decoderLevelShort ?? '上限'}',
    'size' when maxWidth != null && maxHeight != null =>
      '解码器最高 $maxWidth×$maxHeight',
    'size' => '超出解码器分辨率',
    'rate' when maxFps != null => '解码器在此分辨率最高 $maxFps 帧',
    'rate' => '超出解码器帧率',
    'display' => '显示器未报告$_displayName',
    _ => '$_codec 解码器不支持',
  };

  /// The detail line under a greyed row, as 播放信息 words it:
  /// `3996×2160 · HEVC Main 5.2 · c2.mtk.hevc 最高 5.1`.
  String get detail {
    final decoder = this.decoder == null
        ? null
        : TvExoCodec.decoder(this.decoder!);
    final declared = switch (kind) {
      'noDecoder' => '无解码器',
      'dvProfile' when (dvDecoders ?? 0) == 0 => '无杜比视界解码器',
      'dvProfile' => '杜比视界解码器不声明 Profile ${dvProfile ?? '?'}',
      'profile' => '$decoder 不声明 $_profileName',
      'level' => '$decoder 最高 ${_decoderLevel ?? '?'}',
      'size' when maxWidth != null && maxHeight != null =>
        '$decoder 最高 $maxWidth×$maxHeight',
      'rate' when maxFps != null => '$decoder 此分辨率最高 $maxFps 帧',
      'display' => '显示器未报告$_displayName',
      'limit' => '超出播放上限',
      _ when decoder != null => '$decoder 不支持',
      _ => '不支持',
    };
    return [
      stream.size,
      TvExoCodec.describe(stream.codecs),
      declared,
    ].where((s) => s.isNotEmpty).join(' · ');
  }

  @override
  String toString() => 'TvExoRefusal($kind: $short)';
}

/// The bridge's answer for one stream.
@immutable
class TvExoSupport {
  const TvExoSupport(this.support, {this.decoder, this.refusal});

  /// From one entry of `supports`: a map (`support`, `decoder`, `reason`),
  /// or a bare `yes` / `no` / … string.
  factory TvExoSupport.parse(Object? answer, TvExoStream stream) {
    if (answer is Map) {
      final support = answer['support']?.toString() ?? 'no';
      final reason = answer['reason'];
      return TvExoSupport(
        support,
        decoder: answer['decoder'] as String?,
        refusal: support == 'no'
            ? TvExoRefusal.fromBridge(reason is Map ? reason : const {}, stream)
            : null,
      );
    }
    final support = answer?.toString() ?? 'no';
    return TvExoSupport(
      support,
      refusal: support == 'no'
          ? TvExoRefusal(kind: 'unknown', stream: stream)
          : null,
    );
  }

  /// `yes`, `dolbyVision`, `baseLayer` or `no`.
  final String support;
  final String? decoder;
  final TvExoRefusal? refusal;
}
