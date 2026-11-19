// Words the HUD shows on ExoPlayer (docs/tv/PLAN.md, M17.10), apart from
// the HUD so tests can read them: the quality label, 音质's rows, 播放信息
// and 切换路线's rows and headings.
import 'package:PiliPlus/tv/tv_exo_live_source.dart';
import 'package:PiliPlus/tv/tv_exo_player.dart';
import 'package:PiliPlus/tv/tv_exo_support.dart';

abstract final class TvExoHudText {
  /// "原画 · 1080P60": the server's quality name, then the decoded size and
  /// frame rate once the first frame is out (M17.7, decided).
  static String qualityLabel(String name, TvExoFacts? facts) {
    if (facts == null || facts.firstFrameMs == null) return name;
    final h = facts.height;
    if (h == null || h <= 0) return name;
    final fps = facts.measuredFps ?? facts.frameRate;
    final rate = fps == null || fps <= 0 ? '' : '${fps.round()}';
    final decoded = '${h}P$rate';
    // A video's short name is often the same ("1080P60"): say it once.
    return decoded == name ? name : '$name · $decoded';
  }

  /// What happens to an audio stream: the bridge's [support], or by its
  /// codec when the bridge didn't answer.
  static String audioPlays(String? codecs, String? support) {
    final encoded = const {
      'ec-3',
      'ac-3',
      'ac-4',
    }.contains(codecs?.split('.').first.toLowerCase());
    return switch (support ?? (encoded ? 'passthrough' : 'decode')) {
      'passthrough' => '直通电视音频输出，不解码，不做音量均衡',
      'decode' => '电视解码，做音量均衡',
      _ => '此设备无法播放',
    };
  }

  /// The rows of 播放信息 from [facts]; [origin] is the CDN host behind the
  /// thread ripper's loopback proxy, when known.
  static List<(String, String)> infoRows(
    TvExoFacts facts, {
    required String normalization,
    String? origin,
  }) {
    String or(String? v) => v == null || v.isEmpty ? '—' : v;
    final String size = facts.width != null && facts.height != null
        ? '${facts.width}×${facts.height}'
        : '—';
    final String rate = [
      if (facts.frameRate case final f?) '标称 ${f.toStringAsFixed(2)}',
      if (facts.measuredFps case final m?) '实测 ${m.toStringAsFixed(1)}',
    ].join(' · ');
    final String hdr = switch (facts.hdr) {
      'dolbyVision' =>
        '杜比视界${facts.dolbyVisionProfile == null ? '' : ' Profile ${facts.dolbyVisionProfile}'}',
      'hdr10' => 'HDR10 (PQ)',
      'hlg' => facts.videoMime == 'video/dolby-vision' ? 'HLG（杜比视界基础层）' : 'HLG',
      'sdr' => 'SDR',
      _ => '—',
    };
    final String audio = [
      or(facts.audioCodecs ?? facts.audioMime),
      if (facts.sampleRate case final r?) '$r Hz',
      if (facts.channels case final c?) '$c 声道',
    ].join(' · ');
    final String container = facts.live
        ? (facts.hls ? '直播 HLS' : '直播 FLV')
        : 'DASH（视频与音频分轨）';
    return [
      ('视频编码', or(TvExoCodec.describe(facts.videoCodecs ?? facts.videoMime))),
      ('分辨率', size),
      ('帧率', or(rate)),
      ('HDR', hdr),
      ('视频解码器', or(facts.videoDecoder)),
      ('丢帧', '${facts.dropped}'),
      (
        '音频',
        audio,
      ),
      (
        '音频解码',
        facts.audioPassthrough ? '直通电视音频输出（不解码）' : or(facts.audioDecoder),
      ),
      ('音量均衡', facts.live ? '直播不做均衡' : normalization),
      ('首帧', facts.firstFrameMs == null ? '—' : '${facts.firstFrameMs} ms'),
      ('封装', container),
      (
        '服务器',
        // The thread ripper's loopback proxy: name the CDN behind it.
        facts.host == '127.0.0.1' && origin != null && origin.isNotEmpty
            ? '$origin（经多线程加速）'
            : or(facts.host),
      ),
    ];
  }

  /// A route's label on ExoPlayer: the codec first, FLV with HEVC as the
  /// HLS fMP4 it plays as (M17.7), then the quality and host.
  static String routeLabel({
    required String? formatName,
    required String? codecName,
    required String quality,
    required String host,
  }) {
    final String codec = switch (codecName) {
      'avc' => 'AVC',
      'hevc' => 'HEVC',
      'av1' => 'AV1',
      final c? => c,
      null => '?',
    };
    final String plays = TvExoLiveSource.unreadable(formatName, codecName)
        ? '$codec (fMP4)'
        : codec;
    return '$plays · $quality · $host';
  }

  /// A section's heading: protocol and container, readable.
  static String routeHeader(String? protocol, String? format) {
    final String container = switch (format) {
      'flv' => 'FLV',
      'ts' => 'HLS TS',
      'fmp4' => 'HLS fMP4',
      final f? => f,
      null => '?',
    };
    return '$container（${protocol ?? '?'} · ${format ?? '?'}）';
  }
}
